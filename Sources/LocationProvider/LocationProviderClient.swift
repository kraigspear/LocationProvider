//
//  LocationProviderClient.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/26/25.
//

@preconcurrency import CoreLocation
@preconcurrency import MapKit

extension LocationProvider {
    /// A client interface for location services that handles location updates and reverse geocoding.
    ///
    /// This structure provides a clean interface for:
    /// 1. Receiving asynchronous location updates
    /// 2. Converting coordinates to human-readable location names
    ///
    /// The client can be replaced with test doubles for unit testing.
    @MainActor
    struct Client {
        /// Provides an asynchronous sequence of location updates.
        ///
        /// - Parameter liveConfiguration: The CoreLocation live update configuration preset.
        /// - Returns: A sequence of `LocationUpdate` instances representing changes in location
        ///   or authorization status. Cancelling the task that iterates it stops the updates.
        ///
        /// - Throws: The stream may throw the following errors:
        ///   - `CLError`: Core Location errors including:
        ///     - `.denied`: User denied location permissions (mapped to `GPSLocationError.authorizationDenied`)
        ///     - `.locationUnknown`: Unable to determine location (mapped to `GPSLocationError.locationUnavailable`)
        ///     - `.network`: Network-related failure (mapped to `GPSLocationError.locationUnavailable`)
        ///   - `CancellationError`: When the iterating task is cancelled (not surfaced to users)
        ///   - Other system errors from CLLocationUpdate.liveUpdates()
        ///
        /// - Important: This sequence MUST propagate errors from CLLocationUpdate.liveUpdates() rather than
        ///   swallowing them. Authorization and hardware errors need to surface with specific, actionable
        ///   messages so users can understand and resolve permission/hardware issues (e.g., "Location access
        ///   denied" with Settings instructions vs generic "location not found").
        var updates: @Sendable (CLLocationUpdate.LiveConfiguration) -> any AsyncSequence<any LocationUpdate, any Error>
        /// Converts a physical location to a human-readable place name.
        ///
        /// - Parameter location: The `CLLocation` to reverse geocode
        /// - Returns: A string representing the location name, or nil if geocoding fails
        /// - Throws: An error if the geocoding request fails
        var reverseGeocodeLocation: (CLLocation) async throws -> String?

        /// Live implementation using CoreLocation and MapKit services.
        ///
        /// This implementation:
        /// - Uses `CLLocationUpdate.liveUpdates()` for real-time location data
        /// - Employs `MKReverseGeocodingRequest` for reverse geocoding
        static func live() -> Self {
            Self(
                updates: { liveConfiguration in
                    CLLocationUpdate.liveUpdates(liveConfiguration).map { $0 as any LocationUpdate }
                },
                reverseGeocodeLocation: { location in
                    guard let request = MKReverseGeocodingRequest(location: location) else {
                        return nil
                    }
                    let mapItems = try await request.mapItems
                    return mapItems.first?.addressRepresentations?.cityName
                })
        }
    }
}
