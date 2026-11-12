
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

    @Test("Location unavailable updates retry until success")
    func locationUnavailableRetries() async throws {
        let clock = TestClock()
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let locationUpdate = MockLocationUpdate(location: expectedLocation)

        let client = LocationProvider.Client.test(
            [
                .update(MockLocationUpdate.locationNotAvailable()),
                .update(MockLocationUpdate.locationNotAvailable()),
                .update(locationUpdate),
            ],
            clock: clock,
            reverseGeocodeLocation: .success("KraigTown"))

        let locationProvider = LocationProvider(client: client, clock: clock)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(
            gPSLocation.location == expectedLocation,
            "Retries should surface the first valid CLLocation once availability recovers")
        #expect(
            gPSLocation.name == "KraigTown",
            "Reverse geocoding should still return the resolved placemark after retries")
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

    @Test("Location unavailable within the grace period, then a location, returns the location")
    func locationUnavailableRecovers() async throws {
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let clock = TestClock()
        let client = LocationProvider.Client.test(
            [
                .update(MockLocationUpdate.locationNotAvailable()),
                .advance(.seconds(4)),
                .update(MockLocationUpdate(location: expectedLocation)),
            ],
            clock: clock,
            reverseGeocodeLocation: .success("KraigTown"))
        let locationProvider = LocationProvider(client: client, clock: clock)

        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "KraigTown")
    }

    @Test("Location unavailable for the whole grace period throws locationUnavailable")
    func locationUnavailableExceedsGracePeriod() async throws {
        let clock = TestClock()
        let client = LocationProvider.Client.test(
            [
                .update(MockLocationUpdate.locationNotAvailable()),
                .advance(.seconds(5)),
                .update(MockLocationUpdate.locationNotAvailable()),
                // Only reached if the second update is wrongly tolerated
                .update(MockLocationUpdate(location: GPSLocation.statueOfLiberty.location)),
            ],
            clock: clock)
        let locationProvider = LocationProvider(client: client, clock: clock)

        await #expect(throws: GPSLocationError.locationUnavailable) {
            _ = try await locationProvider.gpsLocation()
        }
    }

    @Test("An update without the unavailable flag restarts the grace period")
    func neutralUpdateRestartsGracePeriod() async throws {
        // Given: unavailable at 0s and 8s, with a neutral update between them, in a 5s grace period
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let clock = TestClock()
        let client = LocationProvider.Client.test(
            [
                .update(MockLocationUpdate.locationNotAvailable()),
                .advance(.seconds(4)),
                .update(MockLocationUpdate()),
                .advance(.seconds(4)),
                .update(MockLocationUpdate.locationNotAvailable()),
                .update(MockLocationUpdate(location: expectedLocation)),
            ],
            clock: clock)
        let configuration = LocationProvider.Configuration(locationAcquisitionTimeout: .seconds(60))
        let locationProvider = LocationProvider(client: client, configuration: configuration, clock: clock)

        // When / Then: the second unavailable starts a new grace period instead of measuring 8s
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
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
    struct Accuracy {
        @Test("Reduced accuracy is returned when accepted")
        func reducedAccuracyReturnedWhenAccepted() async throws {
            let clock = TestClock()
            let expectedLocation = CLLocation(latitude: 1, longitude: 1)
            let limitedUpdate = MockLocationUpdate(
                location: expectedLocation,
                accuracyLimited: true)

            let client = LocationProvider.Client.test(
                [.update(limitedUpdate)],
                clock: clock,
                reverseGeocodeLocation: .success(nil))

            let locationProvider = LocationProvider(client: client, clock: clock)
            let gpsLocation = try await locationProvider.gpsLocation(accuracyRequirement: .any)

            #expect(gpsLocation.location == expectedLocation)
        }

        @Test("Reduced accuracy rejected when precise required")
        func reducedAccuracyRejectedWhenPreciseRequired() async throws {
            let clock = TestClock()
            let limitedUpdate = MockLocationUpdate(
                location: CLLocation(latitude: 1, longitude: 1),
                accuracyLimited: true)

            let updateStream = AsyncThrowingStream<LocationUpdate, Error> { continuation in
                continuation.yield(limitedUpdate)
                continuation.finish()
            }

            let client = LocationProvider.Client(
                updates: { _ in updateStream },
                reverseGeocodeLocation: { _ in nil })

            let locationProvider = LocationProvider(client: client, clock: clock)

            await #expect(throws: GPSLocationError.preciseLocationRequired) {
                _ = try await locationProvider.gpsLocation(accuracyRequirement: .precise)
            }
        }

        @Test("Prompt declined for precise location surfaces preciseLocationRequired")
        func promptDeclinedForPreciseLocationSurfacesPreciseLocationRequired() async throws {
            let clock = TestClock()
            // Given: A location stream that throws CLError.promptDeclined, simulating the scenario
            // where the user dismisses the iOS "Precise Location" permission prompt without granting
            // precise accuracy. This occurs when an app with approximate location permission requests
            // precise location and the user declines the system prompt.
            let updateStream = AsyncThrowingStream<LocationUpdate, Error> { continuation in
                continuation.finish(throwing: CLError(.promptDeclined))
            }

            let client = LocationProvider.Client(
                updates: { _ in updateStream },
                reverseGeocodeLocation: { _ in nil })

            let locationProvider = LocationProvider(client: client, clock: clock)

            // When: The app calls gpsLocation() with precise accuracy requirement
            // Then: The CLError.promptDeclined should be correctly mapped to GPSLocationError.preciseLocationRequired,
            // providing actionable guidance to users on how to enable precise location in Settings rather than
            // surfacing a generic system error that doesn't explain what went wrong or how to fix it.
            await #expect(
                throws: GPSLocationError.preciseLocationRequired,
                "CLError.promptDeclined must map to GPSLocationError.preciseLocationRequired to provide users with actionable guidance on enabling precise location in Settings, distinguishing this user choice from other authorization failures")
            {
                _ = try await locationProvider.gpsLocation(accuracyRequirement: .precise)
            }
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
        @Test("Custom acquisition timeout fails fast")
        func customTimeoutFailsFast() async throws {
            let clock = TestClock()
            let client = LocationProvider.Client.test(
                [
                    .update(MockLocationUpdate.locationNotAvailable()),
                    .advance(.milliseconds(200)),
                    .stall,
                ],
                clock: clock)

            let configuration = LocationProvider.Configuration(
                locationAcquisitionTimeout: .milliseconds(200),
                locationUnavailableGracePeriod: .seconds(0))

            let provider = LocationProvider(client: client, configuration: configuration, clock: clock)

            await #expect(throws: GPSLocationError.locationUnavailable) {
                _ = try await provider.gpsLocation()
            }
        }

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

        @Test("Location services restricted, Error thrown")
        func restrictedAccess() async throws {
            let clock = TestClock()
            let locationUpdate = MockLocationUpdate.restricted()
            let client = LocationProvider.Client.test(
                [.update(locationUpdate)],
                clock: clock,
                reverseGeocodeLocation: .success("KraigTown"))
            let locationProvider = LocationProvider(client: client, clock: clock)

            await #expect(throws: GPSLocationError.authorizationRestricted) {
                _ = try await locationProvider.gpsLocation()
            }
        }

        @Test("Location services denied globally maps to authorizationDenied")
        func globallyDenied() async throws {
            let clock = TestClock()
            let locationUpdate = MockLocationUpdate(authorizationDeniedGlobally: true, locationUnavailable: true)
            let client = LocationProvider.Client.test(
                [.update(locationUpdate)],
                clock: clock,
                reverseGeocodeLocation: .success("KraigTown"))
            let locationProvider = LocationProvider(client: client, clock: clock)

            await #expect(throws: GPSLocationError.authorizationDenied) {
                _ = try await locationProvider.gpsLocation()
            }
        }

        @Test("Insufficient location usage permissions, Error thrown")
        func insufficientPermissions() async throws {
            let clock = TestClock()
            let locationUpdate = MockLocationUpdate.insufficientlyInUse()
            let client = LocationProvider.Client.test(
                [.update(locationUpdate)],
                clock: clock,
                reverseGeocodeLocation: .success("KraigTown"))
            let locationProvider = LocationProvider(client: client, clock: clock)

            await #expect(throws: GPSLocationError.insufficientlyInUse) {
                _ = try await locationProvider.gpsLocation()
            }
        }

        @Test("Service session required, Error thrown")
        func serviceSessionNeeded() async throws {
            let clock = TestClock()
            let locationUpdate = MockLocationUpdate.serviceSessionRequired()
            let client = LocationProvider.Client.test(
                [.update(locationUpdate)],
                clock: clock,
                reverseGeocodeLocation: .success("KraigTown"))
            let locationProvider = LocationProvider(client: client, clock: clock)

            await #expect(throws: GPSLocationError.serviceSessionRequired) {
                _ = try await locationProvider.gpsLocation()
            }
        }
    }
}
