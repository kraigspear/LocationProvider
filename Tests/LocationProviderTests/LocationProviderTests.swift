
@testable import LocationProvider

import CoreLocation
import Testing

@MainActor
struct LocationProviderTest {
    @Test("Initially ask for permissions, then receive a location")
    func askedForPermissionReceived() async throws {
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let askForPermissions = MockLocationUpdate.requestInProgress()
        let locationUpdate = MockLocationUpdate(location: expectedLocation)
        let client = LocationProvider.Client.test(
            updates: [askForPermissions, locationUpdate],
            reverseGeocodeLocation: .success("KraigTown"))
        let locationProvider = LocationProvider(client: client)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "KraigTown")
    }

    @Test("Success finding location")
    func locationReceived() async throws {
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let locationUpdate = MockLocationUpdate(location: expectedLocation)
        let client = LocationProvider.Client.test(
            updates: [locationUpdate],
            reverseGeocodeLocation: .success("KraigTown"))
        let locationProvider = LocationProvider(client: client)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "KraigTown")
    }

    @Test("When 2 locations are provided, use the first")
    func usesFirstProvidedLocation() async throws {
        let firstLocation = GPSLocation.statueOfLiberty.location
        let secondLocation = CLLocation(latitude: 0, longitude: 0)

        let firstUpdate = MockLocationUpdate(location: firstLocation)
        let secondUpdate = MockLocationUpdate(location: secondLocation)

        let client = LocationProvider.Client.test(
            updates: [firstUpdate, secondUpdate],
            reverseGeocodeLocation: .success("KraigTown"))

        let locationProvider = LocationProvider(client: client)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == firstLocation, "First location should be used")
        #expect(gPSLocation.name == "KraigTown")
    }

    @Test("Location unavailable updates retry until success")
    func locationUnavailableRetries() async throws {
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let locationUpdate = MockLocationUpdate(location: expectedLocation)

        let client = LocationProvider.Client.test(
            updates: [
                MockLocationUpdate.locationNotAvailable(),
                MockLocationUpdate.locationNotAvailable(),
                locationUpdate,
            ],
            reverseGeocodeLocation: .success("KraigTown"))

        let locationProvider = LocationProvider(client: client)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation, "Retries should surface the first valid CLLocation once availability recovers")
        #expect(gPSLocation.name == "KraigTown", "Reverse geocoding should still return the resolved placemark after retries")
    }

    @Test("Reverse geocoding fails, name is given default GPS")
    func reverseGeocodingError() async throws {
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let locationUpdate = MockLocationUpdate(location: expectedLocation)
        let client = LocationProvider.Client.test(
            updates: [locationUpdate],
            reverseGeocodeLocation: .failure(NSError(domain: "Geocoding", code: -1)))
        let locationProvider = LocationProvider(client: client)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "GPS")
    }

    @Test("Location unavailable update followed by success is tolerated")
    func locationUnavailableRecovers() async throws {
        let expectedLocation = GPSLocation.statueOfLiberty.location
        let updateStream = AsyncThrowingStream<LocationUpdate, Error> { continuation in
            Task {
                continuation.yield(MockLocationUpdate.locationNotAvailable())
                try? await Task.sleep(for: .seconds(1))
                continuation.yield(MockLocationUpdate(location: expectedLocation))
                continuation.finish()
            }
        }

        let client = LocationProvider.Client(
            updates: { updateStream },
            reverseGeocodeLocation: { _ in "KraigTown" })

        let locationProvider = LocationProvider(client: client)
        let clock = ContinuousClock()
        let start = clock.now

        let gPSLocation = try await locationProvider.gpsLocation()
        let elapsed = start.duration(to: clock.now)

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "KraigTown")
        #expect(elapsed >= .seconds(1))
    }

    @Test("Stream failure surfaces authorization denied")
    func streamFailureSurfacesAuthorizationDenied() async throws {
        let updateStream = AsyncThrowingStream<LocationUpdate, Error> { continuation in
            continuation.finish(throwing: CLError(.denied))
        }

        let client = LocationProvider.Client(
            updates: { updateStream },
            reverseGeocodeLocation: { _ in nil })

        let locationProvider = LocationProvider(client: client)

        await #expect(throws: GPSLocationError.authorizationDenied) {
            _ = try await locationProvider.gpsLocation()
        }
    }

    @MainActor
    struct Accuracy {
        @Test("Reduced accuracy is returned when accepted")
        func reducedAccuracyReturnedWhenAccepted() async throws {
            let expectedLocation = CLLocation(latitude: 1, longitude: 1)
            let limitedUpdate = MockLocationUpdate(
                location: expectedLocation,
                accuracyLimited: true)

            let client = LocationProvider.Client.test(
                updates: [limitedUpdate],
                reverseGeocodeLocation: .success(nil))

            let locationProvider = LocationProvider(client: client)
            let gpsLocation = try await locationProvider.gpsLocation(accuracyRequirement: .any)

            #expect(gpsLocation.location == expectedLocation)
        }

        @Test("Reduced accuracy rejected when precise required")
        func reducedAccuracyRejectedWhenPreciseRequired() async throws {
            let limitedUpdate = MockLocationUpdate(
                location: CLLocation(latitude: 1, longitude: 1),
                accuracyLimited: true)

            let updateStream = AsyncThrowingStream<LocationUpdate, Error> { continuation in
                continuation.yield(limitedUpdate)
                continuation.finish()
            }

            let client = LocationProvider.Client(
                updates: { updateStream },
                reverseGeocodeLocation: { _ in nil })

            let locationProvider = LocationProvider(client: client)

            await #expect(throws: GPSLocationError.preciseLocationRequired) {
                _ = try await locationProvider.gpsLocation(accuracyRequirement: .precise)
            }
        }

        @Test("Prompt declined for precise location surfaces preciseLocationRequired")
        func promptDeclinedForPreciseLocationSurfacesPreciseLocationRequired() async throws {
            // Given: A location stream that throws CLError.promptDeclined, simulating the scenario
            // where the user dismisses the iOS "Precise Location" permission prompt without granting
            // precise accuracy. This occurs when an app with approximate location permission requests
            // precise location and the user declines the system prompt.
            let updateStream = AsyncThrowingStream<LocationUpdate, Error> { continuation in
                continuation.finish(throwing: CLError(.promptDeclined))
            }

            let client = LocationProvider.Client(
                updates: { updateStream },
                reverseGeocodeLocation: { _ in nil })

            let locationProvider = LocationProvider(client: client)

            // When: The app calls gpsLocation() with precise accuracy requirement
            // Then: The CLError.promptDeclined should be correctly mapped to GPSLocationError.preciseLocationRequired,
            // providing actionable guidance to users on how to enable precise location in Settings rather than
            // surfacing a generic system error that doesn't explain what went wrong or how to fix it.
            await #expect(throws: GPSLocationError.preciseLocationRequired, "CLError.promptDeclined must map to GPSLocationError.preciseLocationRequired to provide users with actionable guidance on enabling precise location in Settings, distinguishing this user choice from other authorization failures") {
                _ = try await locationProvider.gpsLocation(accuracyRequirement: .precise)
            }
        }
    }

    @MainActor
    struct Settings {
        @Test("Custom acquisition timeout fails fast")
        func customTimeoutFailsFast() async throws {
            let updateStream = AsyncThrowingStream<LocationUpdate, Error> { continuation in
                Task {
                    continuation.yield(MockLocationUpdate.locationNotAvailable())
                    // keep stream alive without yielding additional updates
                    try? await Task.sleep(for: .seconds(3600))
                }
            }

            let client = LocationProvider.Client(
                updates: { updateStream },
                reverseGeocodeLocation: { _ in nil })

            let configuration = LocationProvider.Configuration(
                locationAcquisitionTimeout: .seconds(0),
                locationUnavailableGracePeriod: .seconds(0))

            let provider = LocationProvider(client: client, configuration: configuration)

            await #expect(throws: GPSLocationError.locationUnavailable) {
                _ = try await provider.gpsLocation()
            }
        }
    }

    @MainActor
    struct Permissions {
        @Test("Permissions denied, Error thrown")
        func permissionsDenied() async throws {
            let locationUpdate = MockLocationUpdate.denied()
            let client = LocationProvider.Client.test(
                updates: [locationUpdate],
                reverseGeocodeLocation: .success("KraigTown"))
            let locationProvider = LocationProvider(client: client)

            await #expect(throws: GPSLocationError.authorizationDenied) {
                _ = try await locationProvider.gpsLocation()
            }
        }

        @Test("Location services restricted, Error thrown")
        func restrictedAccess() async throws {
            let locationUpdate = MockLocationUpdate.restricted()
            let client = LocationProvider.Client.test(
                updates: [locationUpdate],
                reverseGeocodeLocation: .success("KraigTown"))
            let locationProvider = LocationProvider(client: client)

            await #expect(throws: GPSLocationError.authorizationRestricted) {
                _ = try await locationProvider.gpsLocation()
            }
        }

        @Test("Location services denied globally, Error thrown")
        func globallyDenied() async throws {
            let locationUpdate = MockLocationUpdate.deniedGlobally()
            let client = LocationProvider.Client.test(
                updates: [locationUpdate],
                reverseGeocodeLocation: .success("KraigTown"))
            let locationProvider = LocationProvider(client: client)

            await #expect(throws: GPSLocationError.authorizationDeniedGlobally) {
                _ = try await locationProvider.gpsLocation()
            }
        }

        @Test("Insufficient location usage permissions, Error thrown")
        func insufficientPermissions() async throws {
            let locationUpdate = MockLocationUpdate.insufficientlyInUse()
            let client = LocationProvider.Client.test(
                updates: [locationUpdate],
                reverseGeocodeLocation: .success("KraigTown"))
            let locationProvider = LocationProvider(client: client)

            await #expect(throws: GPSLocationError.insufficientlyInUse) {
                _ = try await locationProvider.gpsLocation()
            }
        }

        @Test("Service session required, Error thrown")
        func serviceSessionNeeded() async throws {
            let locationUpdate = MockLocationUpdate.serviceSessionRequired()
            let client = LocationProvider.Client.test(
                updates: [locationUpdate],
                reverseGeocodeLocation: .success("KraigTown"))
            let locationProvider = LocationProvider(client: client)

            await #expect(throws: GPSLocationError.serviceSessionRequired) {
                _ = try await locationProvider.gpsLocation()
            }
        }
    }
}
