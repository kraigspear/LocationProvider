
import CoreLocation
@testable import LocationProvider
import Testing

/// Time limit turns a stuck clock or lost cancellation into a failure instead of a hang.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LocationProviderTest {
    @Test("Initially ask for permissions, then receive a location")
    func askedForPermissionReceived() async throws {
        let clock = TestClock()
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let askForPermissions = MockLocationUpdate.requestInProgress()
        let locationUpdate = MockLocationUpdate(location: expectedLocation)
        let client = LocationProvider.Client.test(
            [.update(askForPermissions), .update(locationUpdate)],
            clock: clock,
            reverseGeocodeLocation: .success("KraigTown"))
        let locationProvider = LocationProvider(client: client, clock: clock)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "KraigTown")
    }

    @Test("Success finding location")
    func locationReceived() async throws {
        let clock = TestClock()
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let locationUpdate = MockLocationUpdate(location: expectedLocation)
        let client = LocationProvider.Client.test(
            [.update(locationUpdate)],
            clock: clock,
            reverseGeocodeLocation: .success("KraigTown"))
        let locationProvider = LocationProvider(client: client, clock: clock)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "KraigTown")
    }

    @Test("When 2 locations are provided, use the first")
    func usesFirstProvidedLocation() async throws {
        let clock = TestClock()
        let firstLocation = GPSLocation.statueOfLiberty.location
        let secondLocation = CLLocation(latitude: 0, longitude: 0)

        let firstUpdate = MockLocationUpdate(location: firstLocation)
        let secondUpdate = MockLocationUpdate(location: secondLocation)

        let client = LocationProvider.Client.test(
            [.update(firstUpdate), .update(secondUpdate)],
            clock: clock,
            reverseGeocodeLocation: .success("KraigTown"))

        let locationProvider = LocationProvider(client: client, clock: clock)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == firstLocation, "First location should be used")
        #expect(gPSLocation.name == "KraigTown")
    }

    @Test("Reverse geocoding fails, name is given default GPS")
    func reverseGeocodingError() async throws {
        let clock = TestClock()
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let locationUpdate = MockLocationUpdate(location: expectedLocation)
        let client = LocationProvider.Client.test(
            [.update(locationUpdate)],
            clock: clock,
            reverseGeocodeLocation: .failure(NSError(domain: "Geocoding", code: -1)))
        let locationProvider = LocationProvider(client: client, clock: clock)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "GPS")
    }

    @Test("Stream failure surfaces authorization denied")
    func streamFailureSurfacesAuthorizationDenied() async throws {
        let clock = TestClock()
        let updateStream = AsyncThrowingStream<LocationUpdate, Error> { continuation in
            continuation.finish(throwing: CLError(.denied))
        }

        let client = LocationProvider.Client(
            updates: { _ in updateStream },
            reverseGeocodeLocation: { _ in nil })

        let locationProvider = LocationProvider(client: client, clock: clock)

        await #expect(throws: GPSLocationError.authorizationDenied) {
            _ = try await locationProvider.gpsLocation()
        }
    }

    @Test("Stream ending in CancellationError surfaces the last transient error")
    func streamCancellationSurfacesLastTransientError() async {
        // Live updates throw CancellationError straight through, so the provider must not surface it
        let updateStream = AsyncThrowingStream<LocationUpdate, Error> { continuation in
            continuation.yield(MockLocationUpdate.locationNotAvailable())
            continuation.finish(throwing: CancellationError())
        }
        let client = LocationProvider.Client(
            updates: { _ in updateStream },
            reverseGeocodeLocation: { _ in nil })
        let locationProvider = LocationProvider(client: client, clock: TestClock())

        await #expect(throws: GPSLocationError.locationUnavailable) {
            _ = try await locationProvider.gpsLocation()
        }
    }

    @MainActor
    struct Settings {
        @Test("Live configuration forwarded to client updates")
        func liveConfigurationForwarded() async throws {
            let clock = TestClock()
            let expectedLocation = CLLocation(latitude: 1, longitude: 1)
            let expectedConfigurationDescription = String(describing: CLLocationUpdate.LiveConfiguration.fitness)

            let updateStream = AsyncThrowingStream<LocationUpdate, Error> { continuation in
                continuation.yield(MockLocationUpdate(location: expectedLocation))
                continuation.finish()
            }

            let client = LocationProvider.Client(
                updates: { liveConfiguration in
                    #expect(String(describing: liveConfiguration) == expectedConfigurationDescription)
                    return updateStream
                },
                reverseGeocodeLocation: { _ in nil })

            let providerConfiguration = LocationProvider.Configuration(
                liveConfiguration: .fitness)

            let provider = LocationProvider(client: client, configuration: providerConfiguration, clock: clock)

            _ = try await provider.gpsLocation()
        }
    }

    @MainActor
    struct Timeouts {
        @Test("Stream stall times out even without updates")
        func streamStallTimesOutWithoutUpdates() async throws {
            let clock = TestClock()
            let client = LocationProvider.Client.test([.advance(.milliseconds(200)), .stall], clock: clock)

            let configuration = LocationProvider.Configuration(
                locationAcquisitionTimeout: .milliseconds(200),
                locationUnavailableGracePeriod: .seconds(0))

            let provider = LocationProvider(client: client, configuration: configuration, clock: clock)

            await #expect(throws: GPSLocationError.notFound) {
                _ = try await provider.gpsLocation()
            }
        }

        @Test("Permission prompt restarts the acquisition timeout")
        func permissionPromptRestartsTimeout() async {
            // Given: the prompt arrives 8s into a 10s timeout, and the stream then stalls at 16s
            let clock = TestClock()
            let client = LocationProvider.Client.test(
                [
                    .advance(.seconds(8)),
                    .update(MockLocationUpdate.requestInProgress()),
                    .advance(.seconds(8)),
                    .stall,
                ],
                clock: clock)
            let configuration = LocationProvider.Configuration(locationAcquisitionTimeout: .seconds(10))
            let provider = LocationProvider(client: client, configuration: configuration, clock: clock)

            let request = Task { try await provider.gpsLocation() }

            // The time limit cancels only the test's task, so pass it on to the unstructured request
            await withTaskCancellationHandler {
                // When: past the original 10s deadline, the timeout re-sleeps beside the stalled stream
                await clock.waitForSleepers(2)
                clock.advance(by: .seconds(2))

                // Then: it fires at 18s, 10s after the prompt
                await #expect(throws: GPSLocationError.notFound) {
                    _ = try await request.value
                }
            } onCancel: {
                request.cancel()
            }
        }
    }

    @MainActor
    struct Cancellation {
        @Test(
            "A cancelled request fails as a timeout would",
            arguments: [
                ([UpdateStep.stall], GPSLocationError.notFound),
                ([.update(MockLocationUpdate.locationNotAvailable()), .stall], .locationUnavailable),
            ])
        func cancelledRequestFailsAsTimeout(steps: [UpdateStep], expectedError: GPSLocationError) async {
            let clock = TestClock()
            let provider = LocationProvider(client: .test(steps, clock: clock), clock: clock)

            // Catching into a typed Result compiles only while gpsLocation() throws GPSLocationError alone
            let request = Task { () async -> Result<GPSLocation, GPSLocationError> in
                do throws(GPSLocationError) {
                    return try await .success(provider.gpsLocation())
                } catch {
                    return .failure(error)
                }
            }

            // The time limit cancels only the test's task, so pass it on to the unstructured request
            await withTaskCancellationHandler {
                // The stalled stream and the timeout are both asleep, so the request is mid-acquisition
                await clock.waitForSleepers(2)
                request.cancel()

                let result = await request.value
                #expect(throws: expectedError) { try result.get() }
            } onCancel: {
                request.cancel()
            }
        }
    }

    @MainActor
    struct Permissions {
        @Test("Permissions denied, Error thrown")
        func permissionsDenied() async throws {
            let clock = TestClock()
            let locationUpdate = MockLocationUpdate.denied()
            let client = LocationProvider.Client.test(
                [.update(locationUpdate)],
                clock: clock,
                reverseGeocodeLocation: .success("KraigTown"))
            let locationProvider = LocationProvider(client: client, clock: clock)

            await #expect(throws: GPSLocationError.authorizationDenied) {
                _ = try await locationProvider.gpsLocation()
            }
        }
    }
}
