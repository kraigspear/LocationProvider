//
//  LocationProviderClient.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/26/25.
//

@preconcurrency import CoreLocation
@preconcurrency import MapKit
import os.log

private let logger = Logger(subsystem: "com.spearware.locationprovider", category: "Client")

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
        /// - Parameter liveConfiguration: The CoreLocation live update configuration preset.
        /// - Returns: An `AsyncThrowingStream` of `LocationUpdate` instances representing changes in location or authorization status.
        ///
        /// - Throws: The stream may throw the following errors:
        ///   - `CLError`: Core Location errors including:
        ///     - `.denied`: User denied location permissions (mapped to `GPSLocationError.authorizationDenied` or `.authorizationDeniedGlobally`)
        ///     - `.locationUnknown`: Unable to determine location (mapped to `GPSLocationError.locationUnavailable`)
        ///     - `.network`: Network-related failure (mapped to `GPSLocationError.locationUnavailable`)
        ///   - `CancellationError`: When the stream is cancelled (filtered out, not surfaced to users)
        ///   - Other system errors from CLLocationUpdate.liveUpdates()
        ///
        /// - Important: This stream MUST propagate errors from CLLocationUpdate.liveUpdates() rather than swallowing them.
        ///   Authorization and hardware errors need to surface with specific, actionable messages so users can
        ///   understand and resolve permission/hardware issues (e.g., "Location access denied" with Settings instructions
        ///   vs generic "location not found").
        var updates: @Sendable (CLLocationUpdate.LiveConfiguration) -> AsyncThrowingStream<LocationUpdate, Error>
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
                    logger.debug("updates called")
                    return AsyncThrowingStream { continuation in
                        let task = Task {
                            do {
                                for try await update in CLLocationUpdate.liveUpdates(liveConfiguration) {
                                    if Task.isCancelled {
                                        logger.debug("Task was cancelled, aborting location stream")
                                        break
                                    }
                                    continuation.yield(update)
                                }
                                continuation.finish()
                            } catch {
                                if error is CancellationError {
                                    logger.debug("Location stream cancelled")
                                    continuation.finish()
                                } else {
                                    logger.error("Location stream error: \(error)")
                                    continuation.finish(throwing: error)
                                }
                            }
                        }
                        continuation.onTermination = { @Sendable termination in
                            switch termination {
                            case .finished:
                                logger.debug("Task was terminated due to being finished, cancelling location stream")
                            case .cancelled:
                                logger.debug("Task was terminated due to being cancelled, cancelling location stream")
                            @unknown default:
                                logger.warning("Task was cancelled with an unknown termination reason")
                            }
                            task.cancel()
                        }
                    }
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
            reverseGeocodeLocation: Result<String?, Error>) -> Self
        {
            Self(
                updates: { _ in
                    AsyncThrowingStream { continuation in
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
                    case let .success(value):
                        return value
                    case let .failure(error):
                        throw error
                    }
                })
        }
    }

#endif
