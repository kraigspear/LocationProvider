

import CoreLocation
import Foundation
import os

// MARK: - Logger

/// Logger instance for debugging and tracking location-related operations.
private let logger = Logger(subsystem: "com.spearware.location", category: "📍LocationProvider")

// MARK: - LocationProvider

/// A class responsible for monitoring and retrieving device location information.
///
/// This class provides functionality to obtain the current GPS location and reverse geocode it
/// to get a human-readable location name. It uses Core Location's live updates feature
/// to get real-time location data.
///
/// - Important: Ensure your app has the appropriate location usage description keys in Info.plist
///   and handles permission requests appropriately.
///
/// - Note: This class is designed to work with Core Location's modern async/await API
///   and is marked as @MainActor to ensure proper thread safety.
///
/// Example usage:
/// ```swift
/// let provider = LocationProvider()
/// do {
///     let location = try await provider.gpsLocation()
///     print("Current location: \(location.name ?? "Unknown")")
/// } catch {
///     print("Failed to get location: \(error)")
/// }
/// ```
@MainActor
public final class LocationProvider {
    // MARK: - Properties

    /// The client responsible for handling location services
    private let client: Client
    private let configuration: Configuration

    // MARK: - Initialization

    /// Creates a new instance of LocationProvider with the live client
    /// - Parameter configuration: Timing parameters that control acquisition timeouts and grace periods.
    public init(configuration: Configuration = .default) {
        client = .live
        self.configuration = configuration
    }

    /// Creates a new instance of LocationProvider with a custom client
    /// - Parameters:
    ///   - client: The client to use for location services
    ///   - configuration: Timing parameters that control acquisition timeouts and grace periods.
    init(client: Client, configuration: Configuration = .default) {
        self.client = client
        self.configuration = configuration
    }

    // MARK: - Public Interface

    /// Retrieves the current GPS location with a human-readable name.
    ///
    /// This method performs the following steps:
    /// 1. Requests and waits for the first available live location update
    /// 2. Attempts to reverse geocode the location to get a readable name
    /// 3. Returns a `GPSLocation` combining both pieces of information
    ///
    /// - Parameter accuracyRequirement: Determines if reduced-accuracy locations are acceptable.
    ///   Use `.any` (default) for general location needs where approximate location (within ~1-20km) is sufficient,
    ///   such as weather updates, timezone detection, or regional content. Use `.precise` when exact location is critical,
    ///   such as navigation, fitness tracking, or location sharing. Note that `.precise` may increase
    ///   wait time and battery usage as it bypasses iOS's privacy-preserving reduced accuracy mode.
    /// - Returns: A `GPSLocation` object containing the location coordinates and optional name
    /// - Throws: `GPSLocationError.notFound` if unable to get a location, or other location-related errors
    public func gpsLocation(
        accuracyRequirement: AccuracyRequirement = .any
    ) async throws -> GPSLocation {
        logger.debug("Starting GPS location request")

        let firstLiveUpdate = try await firstLiveUpdate(accuracyRequirement: accuracyRequirement)
        logger.debug("Received live update, attempting reverse geocode")

        // Attempt to get location name but don't fail if reverse geocoding fails
        let name: String?
        do {
            name = try await client.reverseGeocodeLocation(firstLiveUpdate)
            logger.debug("Successfully reverse geocoded location: \(name ?? "nil")")
        } catch {
            logger.error("Failed to reverse geocode location: \(error.localizedDescription)")
            name = nil
        }

        return .init(
            name: name,
            location: firstLiveUpdate
        )
    }

    // MARK: - Private Methods

    /// Retrieves the first available live location update.
    ///
    /// This private method continuously monitors location updates until a valid location
    /// is received or an error occurs. It handles various states including:
    /// - Permission requests in progress
    /// - Location availability
    /// - Authorization status changes
    ///
    /// - Returns: The first valid `CLLocation` object received
    /// - Throws: `GPSLocationError.notFound` if no valid location can be obtained,
    ///          or other relevant `GPSLocationError` cases based on the update state
    private func firstLiveUpdate(
        accuracyRequirement: AccuracyRequirement
    ) async throws -> CLLocation {
        logger.debug("Starting live update monitoring")

        let clock = ContinuousClock()
        var acquisitionWindowStart = clock.now
        var locationUnavailableStart: ContinuousClock.Instant?
        var lastTransientError: GPSLocationError?

        do {
            for try await update in client.updates() {
                let now = clock.now
                logger.debug("Received location update: \(String(describing: update))")

                if update.authorizationRequestInProgress {
                    logger.debug("Authorization request in progress; resetting timers")
                    acquisitionWindowStart = now
                    locationUnavailableStart = nil
                    lastTransientError = nil
                    continue
                }

                if let location = update.location {
                    if update.accuracyLimited && !accuracyRequirement.acceptsReducedAccuracy {
                        logger.debug("Limited accuracy location received but precise accuracy required; continuing")
                        lastTransientError = .preciseLocationRequired
                        continue
                    }
                    logger.debug("Valid location found: \(String(describing: location))")
                    return location
                }

                if let error = GPSLocationError(locationUpdate: update) {
                    switch error {
                    case .locationUnavailable:
                        lastTransientError = error

                        if locationUnavailableStart == nil {
                            locationUnavailableStart = now
                            logger.debug("Location unavailable reported; starting grace period")
                        } else if let start = locationUnavailableStart {
                            let elapsed = start.duration(to: now)

                            if elapsed >= configuration.locationUnavailableGracePeriod {
                                logger.error("Location unavailable exceeded grace period (\(String(describing: elapsed))); throwing")
                                throw error
                            }

                            logger.debug("Location unavailable within grace period (\(String(describing: elapsed))); awaiting recovery")
                        }

                    default:
                        logger.error("Non-transient location error encountered: \(String(describing: error))")
                        throw error
                    }
                } else {
                    locationUnavailableStart = nil
                }

                let acquisitionElapsed = acquisitionWindowStart.duration(to: now)
                if acquisitionElapsed >= configuration.locationAcquisitionTimeout {
                    let timeoutError = lastTransientError ?? .notFound
                    logger.error("Location acquisition timed out after \(String(describing: acquisitionElapsed)); throwing \(String(describing: timeoutError))")
                    throw timeoutError
                }
            }
        } catch {
            // Critical error handling: The stream threw an error (likely CLError from liveUpdates).
            // We MUST map these to specific GPSLocationError cases so users get actionable messages.
            // Example: CLError.denied → GPSLocationError.authorizationDenied → "Location access is disabled..."
            // Without this mapping, users would only see generic "Unable to determine location" errors
            // and wouldn't know they need to fix permissions in Settings.
            logger.error("Location updates stream failed with error: \(String(describing: error))")

            // Map CLError and other known errors to our domain-specific errors
            if let mappedError = GPSLocationError(locationStreamError: error) {
                throw mappedError
            }

            // Fall back to the last transient error we saw (if any) or generic .notFound
            // This preserves context when the stream ends unexpectedly
            throw lastTransientError ?? .notFound
        }

        logger.error("Location updates stream ended without valid location")
        throw lastTransientError ?? .notFound
    }
}

// MARK: - Helper Extensions

public extension LocationProvider {
    /// Represents the level of accuracy a caller is willing to accept for a location fix.
    ///
    /// In iOS 14+, users can grant "Approximate Location" permission to apps, which provides
    /// reduced accuracy (~1-20km precision) for privacy. This enum allows your code to decide
    /// whether such approximate locations meet your feature's requirements.
    enum AccuracyRequirement: Sendable {
        /// Any location fix is acceptable, including reduced-accuracy results.
        ///
        /// Choose this when approximate location is sufficient for your feature
        /// (e.g., weather updates, timezone detection, regional content, city-level features).
        /// This option provides the fastest location fix and best battery efficiency.
        case any

        /// Require precise location data; reduced-accuracy fixes will be ignored until a precise update arrives.
        ///
        /// Choose this when exact location is critical (e.g., turn-by-turn navigation,
        /// fitness tracking, proximity features, location sharing, or geofencing).
        /// May result in longer wait times if user has only granted approximate location permission.
        case precise
    }

    /// Configuration values that control how location acquisition behaves.
    struct Configuration: Sendable {
        /// The maximum duration to wait for a valid location before failing.
        public var locationAcquisitionTimeout: Duration
        /// The grace period to tolerate `.locationUnavailable` before treating it as an error.
        public var locationUnavailableGracePeriod: Duration

        public init(
            locationAcquisitionTimeout: Duration = .seconds(30),
            locationUnavailableGracePeriod: Duration = .seconds(25)
        ) {
            self.locationAcquisitionTimeout = locationAcquisitionTimeout
            self.locationUnavailableGracePeriod = locationUnavailableGracePeriod
        }

        public static let `default` = Configuration()
    }
}

private extension LocationProvider.AccuracyRequirement {
    /// Indicates whether the requirement accepts reduced accuracy locations for approximate mode.
    var acceptsReducedAccuracy: Bool {
        switch self {
        case .any:
            true
        case .precise:
            false
        }
    }
}

extension CLPlacemark {
    /// Returns the locality (city) name from the placemark if available.
    ///
    /// - Returns: A string containing the locality name, or nil if not available
    var placemarkName: String? {
        guard let locality else { return nil }
        return "\(locality)"
    }
}
