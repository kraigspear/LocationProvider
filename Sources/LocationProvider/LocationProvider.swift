

import CoreLocation
import Foundation
import os

// MARK: - Constants & Logger Setup

private enum Constants {
    static let locationAcquisitionTimeout: Duration = .seconds(10)
    static let locationUnavailableGracePeriod: Duration = .seconds(3)
}

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

    // MARK: - Initialization

    /// Creates a new instance of LocationProvider with the live client
    public init() {
        client = .live
    }

    /// Creates a new instance of LocationProvider with a custom client
    /// - Parameter client: The client to use for location services
    init(client: Client) {
        self.client = client
    }

    // MARK: - Public Interface

    /// Retrieves the current GPS location with a human-readable name.
    ///
    /// This method performs the following steps:
    /// 1. Requests and waits for the first available live location update
    /// 2. Attempts to reverse geocode the location to get a readable name
    /// 3. Returns a `GPSLocation` combining both pieces of information
    ///
    /// - Returns: A `GPSLocation` object containing the location coordinates and optional name
    /// - Throws: `GPSLocationError.notFound` if unable to get a location, or other location-related errors
    public func gpsLocation() async throws -> GPSLocation {
        logger.debug("Starting GPS location request")

        let firstLiveUpdate = try await firstLiveUpdate()
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
    private func firstLiveUpdate() async throws -> CLLocation {
        logger.debug("Starting live update monitoring")

        let clock = ContinuousClock()
        var acquisitionWindowStart = clock.now
        var locationUnavailableStart: ContinuousClock.Instant?
        var lastTransientError: GPSLocationError?

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

                        if elapsed >= Constants.locationUnavailableGracePeriod {
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
            if acquisitionElapsed >= Constants.locationAcquisitionTimeout {
                let timeoutError = lastTransientError ?? .notFound
                logger.error("Location acquisition timed out after \(String(describing: acquisitionElapsed)); throwing \(String(describing: timeoutError))")
                throw timeoutError
            }
        }

        logger.error("Location updates stream ended without valid location")
        throw lastTransientError ?? .notFound
    }
}

// MARK: - Helper Extensions

extension CLPlacemark {
    /// Returns the locality (city) name from the placemark if available.
    ///
    /// - Returns: A string containing the locality name, or nil if not available
    var placemarkName: String? {
        guard let locality else { return nil }
        return "\(locality)"
    }
}
