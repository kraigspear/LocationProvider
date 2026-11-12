

@preconcurrency import CoreLocation
import Foundation
import os
import Synchronization

// MARK: - Logger

/// Logger instance for debugging and tracking location-related operations.
let logger = Logger(subsystem: "com.spearware.location", category: "📍LocationProvider")

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
    private let clock: any Clock<Duration>

    // MARK: - Initialization

    /// Creates a new instance of LocationProvider with the live client
    /// - Parameter configuration: Timing parameters that control acquisition timeouts and grace periods.
    public init(configuration: Configuration = .default) {
        client = .live()
        self.configuration = configuration
        clock = ContinuousClock()
    }

    /// Creates a new instance of LocationProvider with a custom client
    ///
    /// Internal so the client and clock stay free to change; apps test against a protocol of their own
    /// (see the Testing article).
    /// - Parameters:
    ///   - client: The client to use for location services
    ///   - configuration: Timing parameters that control acquisition timeouts and grace periods.
    ///   - clock: Measures the acquisition timeout and grace period. No default, so tests can't fall back to wall time.
    init(client: Client, configuration: Configuration = .default, clock: any Clock<Duration>) {
        self.client = client
        self.configuration = configuration
        self.clock = clock
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
    ///   such as weather updates, timezone detection, or regional content. Use `.precise` when exact location
    ///   is critical, such as navigation, fitness tracking, or location sharing. Note that `.precise` may increase
    ///   wait time and battery usage as it bypasses iOS's privacy-preserving reduced accuracy mode.
    /// - Returns: A `GPSLocation` object containing the location coordinates and optional name
    /// - Throws: `GPSLocationError.notFound` if unable to get a location, or other location-related errors
    public func gpsLocation(
        accuracyRequirement: AccuracyRequirement = .any) async throws -> GPSLocation
    {
        logger.debug("Starting GPS location request")

        // A local is required: Swift opens the `any Clock` existential only from a local value, not a stored property.
        let clock = clock
        let firstLiveUpdate = try await firstLiveUpdate(accuracyRequirement: accuracyRequirement, clock: clock)
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
            location: firstLiveUpdate)
    }

    // MARK: - Private Methods

    /// Races the update stream against the acquisition timeout until `LocationAcquisition` decides.
    ///
    /// - Returns: The first location the acquisition accepts
    /// - Throws: The `GPSLocationError` the acquisition fails with
    private func firstLiveUpdate<C: Clock<Duration>>(
        accuracyRequirement: AccuracyRequirement,
        clock: C) async throws -> CLLocation
    {
        logger.debug("Starting live update monitoring")

        let acquisition = SharedAcquisition(LocationAcquisition(
            start: clock.now,
            configuration: configuration,
            accuracyRequirement: accuracyRequirement))
        let liveConfiguration = configuration.liveConfiguration
        let updates = client.updates

        let decision = await withTaskGroup(of: LocationAcquisition<C.Instant>.Decision.self) { group in
            group.addTask {
                do {
                    for try await update in updates(liveConfiguration) {
                        logger.debug("Received location update: \(String(describing: update))")
                        let now = clock.now
                        let decision = acquisition.withLock { $0.receive(update, at: now) }
                        if decision != .continue {
                            return decision
                        }
                    }
                    return acquisition.withLock { $0.streamEnded() }
                } catch {
                    return acquisition.withLock { $0.streamFailed(error) }
                }
            }

            group.addTask {
                do {
                    while true {
                        let deadline = acquisition.withLock { $0.deadline }
                        try await clock.sleep(until: deadline, tolerance: .zero)
                        let now = clock.now
                        let decision = acquisition.withLock { $0.deadlineReached(at: now) }
                        if decision != .continue {
                            return decision
                        }
                    }
                } catch {
                    // Cancelled: the timeout has no decision to give; the update loop still returns one.
                    return .continue
                }
            }

            defer { group.cancelAll() }

            for await decision in group where decision != .continue {
                return decision
            }
            return .continue
        }

        switch decision {
        case let .succeed(location):
            return location
        case let .fail(error):
            throw error
        case .continue:
            // Unreachable: the update loop always returns a final decision.
            throw GPSLocationError.notFound
        }
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
        /// The live update configuration preset for CoreLocation.
        /// Use `.default` for general purposes, `.fitness` for workout tracking, etc.
        public var liveConfiguration: CLLocationUpdate.LiveConfiguration

        public init(
            locationAcquisitionTimeout: Duration = .seconds(10),
            locationUnavailableGracePeriod: Duration = .seconds(5),
            liveConfiguration: CLLocationUpdate.LiveConfiguration = .default)
        {
            self.locationAcquisitionTimeout = locationAcquisitionTimeout
            self.locationUnavailableGracePeriod = locationUnavailableGracePeriod
            self.liveConfiguration = liveConfiguration
        }

        public static let `default` = Configuration()
    }
}

/// One request's `LocationAcquisition`, shared by the update loop and the timeout task.
///
/// A lock rather than an actor: every access is a short synchronous call, so an actor's
/// suspension points would protect nothing more. Each decision is made inside one `withLock`.
private final class SharedAcquisition<Instant: InstantProtocol<Duration>>: Sendable {
    private let acquisition: Mutex<LocationAcquisition<Instant>>

    init(_ acquisition: LocationAcquisition<Instant>) {
        self.acquisition = Mutex(acquisition)
    }

    func withLock<Result: Sendable>(_ body: (inout LocationAcquisition<Instant>) -> Result) -> Result {
        acquisition.withLock { body(&$0) }
    }
}
