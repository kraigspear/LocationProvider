@preconcurrency import CoreLocation

/// The rules that turn one request's location updates into a single location or error.
///
/// Plain synchronous state with no clock and no tasks: callers say what happened and when, and act on
/// the returned decision. `LocationProvider` feeds it from the update stream and the timeout task.
struct LocationAcquisition<Instant: InstantProtocol<Duration>>: Sendable {
    enum Decision: Equatable, Sendable {
        /// Keep waiting for updates.
        case `continue`
        case succeed(CLLocation)
        case fail(GPSLocationError)
    }

    private let configuration: LocationProvider.Configuration
    private let accuracyRequirement: LocationProvider.AccuracyRequirement
    /// When the current acquisition window opened; the timeout counts from here.
    private var windowStart: Instant
    /// When the current run of unavailable updates began; the grace period counts from here.
    private var locationUnavailableStart: Instant?
    /// The transient error a timeout reports instead of `.notFound`.
    private var lastTransientError: GPSLocationError?

    init(
        start: Instant,
        configuration: LocationProvider.Configuration,
        accuracyRequirement: LocationProvider.AccuracyRequirement)
    {
        windowStart = start
        self.configuration = configuration
        self.accuracyRequirement = accuracyRequirement
    }

    /// When the acquisition times out, unless a permission prompt opens a new window first.
    var deadline: Instant {
        windowStart.advanced(by: configuration.locationAcquisitionTimeout)
    }

    mutating func receive(_ update: any LocationUpdate, at now: Instant) -> Decision {
        // Checked first, so a prompt wins over any other flag it carries.
        if update.authorizationRequestInProgress {
            logger.debug("Authorization request in progress; restarting the acquisition window")
            // Errors from before the prompt are stale, so they go too.
            windowStart = now
            locationUnavailableStart = nil
            lastTransientError = nil
            return .continue
        }

        if let location = update.location {
            if update.accuracyLimited, accuracyRequirement == .precise {
                logger.debug("Limited accuracy location received but precise accuracy required; continuing")
                lastTransientError = .preciseLocationRequired
                return .continue
            }
            return .succeed(location)
        }

        guard let error = Self.error(in: update) else {
            locationUnavailableStart = nil
            return .continue
        }

        guard error == .locationUnavailable else {
            logger.error("Non-transient location error encountered: \(String(describing: error))")
            return .fail(error)
        }

        lastTransientError = error
        guard let unavailableStart = locationUnavailableStart else {
            logger.debug("Location unavailable reported; starting grace period")
            locationUnavailableStart = now
            return .continue
        }

        let elapsed = unavailableStart.duration(to: now)
        if elapsed >= configuration.locationUnavailableGracePeriod {
            logger.error("Location unavailable exceeded grace period (\(String(describing: elapsed))); failing")
            return .fail(error)
        }
        logger.debug("Location unavailable within grace period (\(String(describing: elapsed))); awaiting recovery")
        return .continue
    }

    /// Continues when a permission prompt moved the deadline past `now`; otherwise times out.
    func deadlineReached(at now: Instant) -> Decision {
        guard now >= deadline else { return .continue }
        logger.error(
            "Location acquisition timed out after \(String(describing: windowStart.duration(to: now))); failing with \(String(describing: timeoutError))")
        return .fail(timeoutError)
    }

    /// A stream that throws has ended, so even a transient error fails at once: no update can follow.
    func streamFailed(_ error: any Error) -> Decision {
        logger.error("Location updates stream failed with error: \(String(describing: error))")
        return .fail(Self.error(thrownBy: error) ?? timeoutError)
    }

    func streamEnded() -> Decision {
        logger.error("Location updates stream ended without valid location")
        return .fail(timeoutError)
    }

    private var timeoutError: GPSLocationError {
        lastTransientError ?? .notFound
    }

    /// The error an update reports, checking flags that need user action before transient ones.
    private static func error(in update: any LocationUpdate) -> GPSLocationError? {
        if update.authorizationDeniedGlobally || update.authorizationDenied {
            .authorizationDenied
        } else if update.authorizationRestricted {
            .authorizationRestricted
        } else if update.insufficientlyInUse {
            .insufficientlyInUse
        } else if update.locationUnavailable {
            .locationUnavailable
        } else if update.serviceSessionRequired {
            .serviceSessionRequired
        } else {
            nil
        }
    }

    /// The error a thrown stream error reports, or nil when it has nothing to tell the user.
    private static func error(thrownBy error: any Error) -> GPSLocationError? {
        if let gpsError = error as? GPSLocationError {
            return gpsError
        }
        // Cancellation and non-location errors say nothing about why no location arrived.
        guard let clError = error as? CLError else { return nil }

        switch clError.code {
        case .denied:
            return .authorizationDenied
        case .promptDeclined:
            // The user declined the prompt to upgrade approximate location to precise.
            return .preciseLocationRequired
        case .locationUnknown, .network, .deferredAccuracyTooLow, .deferredDistanceFiltered, .deferredCanceled,
             .deferredFailed, .headingFailure:
            return .locationUnavailable
        default:
            // Errors such as ranging failures don't concern a GPS fix.
            return nil
        }
    }
}
