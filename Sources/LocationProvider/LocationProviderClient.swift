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
        /// - Throws: `CLError` from `CLLocationUpdate.liveUpdates()`, or `CancellationError` when the iterating
        ///   task is cancelled. `LocationAcquisition` classifies each into a `GPSLocationError`.
        ///
        /// - Important: Propagate errors from `CLLocationUpdate.liveUpdates()` rather than swallowing them, so
        ///   authorization failures reach the caller as their own `GPSLocationError` instead of a timeout.
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
