
@testable import LocationProvider

import CoreLocation
import Testing

@MainActor
struct LocationProviderTest {
    @Test("Initially ask for permissions, then receive a location")
    func askedForPermissionReceived() async throws {
        let expectedLocation = CLLocation.statueOfLiberty
        let askForPermissions = MockLocationUpdate.requestInProgress()
        let locationUpdate = MockLocationUpdate(location: expectedLocation)
        let client = LocationProvider.Client.test(
            updates: [askForPermissions, locationUpdate],
            reverseGeocodeLocation: .success("KraigTown")
        )
        let locationProvider = LocationProvider(client: client)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "KraigTown")
    }

    @Test("Success finding location")
    func locationReceived() async throws {
        let expectedLocation = CLLocation.statueOfLiberty
        let locationUpdate = MockLocationUpdate(location: expectedLocation)
        let client = LocationProvider.Client.test(
            updates: [locationUpdate],
            reverseGeocodeLocation: .success("KraigTown")
        )
        let locationProvider = LocationProvider(client: client)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "KraigTown")
    }

    @Test("When 2 locations are provided, use the first")
    func usesFirstProvidedLocation() async throws {
        let firstLocation = CLLocation.statueOfLiberty
        let secondLocation = CLLocation(latitude: 0, longitude: 0)

        let firstUpdate = MockLocationUpdate(location: firstLocation)
        let secondUpdate = MockLocationUpdate(location: secondLocation)

        let client = LocationProvider.Client.test(
            updates: [firstUpdate, secondUpdate],
            reverseGeocodeLocation: .success("KraigTown")
        )

        let locationProvider = LocationProvider(client: client)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == firstLocation, "First location should be used")
        #expect(gPSLocation.name == "KraigTown")
    }

    @Test("Reverse geocoding fails, name is given default GPS")
    func reverseGeocodingError() async throws {
        let expectedLocation = CLLocation.statueOfLiberty
        let locationUpdate = MockLocationUpdate(location: expectedLocation)
        let client = LocationProvider.Client.test(
            updates: [locationUpdate],
            reverseGeocodeLocation: .failure(NSError(domain: "Geocoding", code: -1))
        )
        let locationProvider = LocationProvider(client: client)
        let gPSLocation = try await locationProvider.gpsLocation()

        #expect(gPSLocation.location == expectedLocation)
        #expect(gPSLocation.name == "GPS")
    }

    @MainActor
    struct Permissions {
        @Test("Permissions denied, Error thrown")
        func permissionsDenied() async throws {
            let locationUpdate = MockLocationUpdate.denied()
            let client = LocationProvider.Client.test(
                updates: [locationUpdate],
                reverseGeocodeLocation: .success("KraigTown")
            )
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
                reverseGeocodeLocation: .success("KraigTown")
            )
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
                reverseGeocodeLocation: .success("KraigTown")
            )
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
                reverseGeocodeLocation: .success("KraigTown")
            )
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
                reverseGeocodeLocation: .success("KraigTown")
            )
            let locationProvider = LocationProvider(client: client)

            await #expect(throws: GPSLocationError.serviceSessionRequired) {
                _ = try await locationProvider.gpsLocation()
            }
        }

        @Test("Location not available, Error thrown")
        func locationUnavailable() async throws {
            let locationUpdate = MockLocationUpdate.locationNotAvailable()
            let client = LocationProvider.Client.test(
                updates: [locationUpdate],
                reverseGeocodeLocation: .success("KraigTown")
            )
            let locationProvider = LocationProvider(client: client)

            await #expect(throws: GPSLocationError.locationUnavailable) {
                _ = try await locationProvider.gpsLocation()
            }
        }
    }
}

extension CLLocation {
    // MARK: - US Landmarks

    static let statueOfLiberty = CLLocation(
        latitude: 40.689247,
        longitude: -74.044502
    )
}
