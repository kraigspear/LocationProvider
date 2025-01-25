//
//  LocationProviderClient.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/26/25.
//

import CoreLocation

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
        /// Provides an asynchronous stream of location updates.
        ///
        /// - Returns: An `AsyncStream` of `LocationUpdate` instances representing changes in location or authorization status.
        var updates: () -> AsyncStream<LocationUpdate>
        /// Converts a physical location to a human-readable place name.
        ///
        /// - Parameter location: The `CLLocation` to reverse geocode
        /// - Returns: A string representing the location name, or nil if geocoding fails
        /// - Throws: An error if the geocoding request fails
        var reverseGeocodeLocation: (CLLocation) async throws -> String?
        
        /// Live implementation using CoreLocation services.
        ///
        /// This implementation:
        /// - Uses `CLLocationUpdate.liveUpdates()` for real-time location data
        /// - Employs `CLGeocoder` for reverse geocoding
        static let live = Self(
            updates: {
                AsyncStream { continuation in
                    Task {
                        do {
                            for try await update in CLLocationUpdate.liveUpdates() {
                                continuation.yield(update)
                            }
                        } catch {
                            continuation.finish()
                        }
                    }
                }
            },
            reverseGeocodeLocation: { firstLiveUpdate in
                try await CLGeocoder()
                    .reverseGeocodeLocation(firstLiveUpdate)
                    .first(where: { $0.placemarkName != nil })?.placemarkName
            }
        )
    }
}

#if DEBUG

extension LocationProvider.Client {
    /// Creates a test client with predefined location updates and geocoding responses.
    ///
    /// - Parameters:
    ///   - updates: Array of `LocationUpdate` instances to be yielded by the stream
    ///   - reverseGeocodeLocation: Expected result of reverse geocoding attempts
    /// - Returns: A configured test client
    static func test(
        updates: [LocationUpdate],
        reverseGeocodeLocation: Result<String?, Error>
    ) -> Self {
        Self(
            updates: {
                AsyncStream { continuation in
                    Task {
                        for update in updates {
                            continuation.yield(update)
                            try? await Task.sleep(for: .seconds(1))
                        }
                        continuation.finish()
                    }
                }
            },
            reverseGeocodeLocation: { _ in
                switch reverseGeocodeLocation {
                case .success(let value):
                    return value
                case .failure(let error):
                    throw error
                }
            }
        )
    }
}

#endif
