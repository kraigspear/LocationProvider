//
//  GPSLocationError.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/25/25.
//

import CoreLocation
import Foundation

/// Represents possible errors that can occur during GPS location operations.
///
/// This enum abstracts Core Location's complex error model into actionable GPS-specific errors.
/// Each case maps to specific user guidance in errorDescription, enabling apps to show
/// contextual help without reimplementing Core Location error logic everywhere.
public enum GPSLocationError: LocalizedError {
    /// Location access is restricted by parental controls or device management
    ///
    /// Why this exists: Users with managed devices (MDM, Screen Time) may have location
    /// services restricted by policy. This case distinguishes policy restrictions from
    /// user choice (denied), enabling appropriate messaging that directs users to their
    /// administrator rather than Settings.
    case authorizationRestricted

    /// Location services are temporarily unavailable or cannot determine position
    ///
    /// Why this exists: Represents transient failures (no GPS signal, airplane mode, hardware
    /// issues) that may resolve without user action. Grouped separately from authorization
    /// errors to suggest "wait and retry" rather than "change settings."
    case notFound

    /// User has explicitly denied location permissions for this app
    ///
    /// Why this exists: The most common authorization failure. Requires user to explicitly
    /// enable location for this specific app in Settings. Distinguished from global denial
    /// to provide precise Settings navigation path in error message.
    case authorizationDenied

    /// Location services are disabled system-wide in device settings
    ///
    /// Why this exists: When Location Services are off for ALL apps, users need different
    /// guidance than app-specific denial. This case ensures error messages direct users to
    /// the correct Settings path (system-level toggle vs app-specific permissions).
    case authorizationDeniedGlobally

    /// Current authorization level is not sufficient for the required location features
    ///
    /// Why this exists: Apps may have "When In Use" but need "Always", or similar scenarios
    /// where partial authorization exists but isn't sufficient. This provides specific guidance
    /// about upgrading permissions rather than generic "denied" messaging.
    case insufficientlyInUse

    /// Location services are currently unavailable (e.g., no GPS signal, hardware issues)
    ///
    /// Why this exists: Consolidates multiple transient CLError cases (locationUnknown, network,
    /// deferred failures, etc.) into one user-facing error. Avoids exposing implementation
    /// details about deferred updates or network-assisted location to end users.
    case locationUnavailable

    /// A service session (like Find My) is required but not active
    ///
    /// Why this exists: Some location features require active service sessions. This provides
    /// specific guidance about enabling required services rather than generic "unavailable"
    /// messages that don't explain what action to take.
    case serviceSessionRequired

    /// User granted approximate location permission but the app requires precise location.
    ///
    /// In iOS 14+, users can choose to share only approximate location (~1-20km accuracy) with apps
    /// for privacy. This error occurs when the app requests precise location but the user has only
    /// granted approximate location access. Users can enable precise location in Settings > Privacy
    /// & Security > Location Services > [App Name] > Precise Location.
    ///
    /// Why this exists: iOS 14+ introduced approximate location as a privacy feature. Apps requiring
    /// precise coordinates (navigation, geo-fencing) need to detect and guide users through enabling
    /// Precise Location. Without this case, apps would receive location data but be silently degraded,
    /// leading to confusing failures.
    case preciseLocationRequired

    /// Creates a GPS error from a location update's state.
    ///
    /// This initializer examines the boolean flags in a LocationUpdate to determine if an error
    /// condition exists. We check flags in priority order to ensure users receive the most accurate
    /// guidance when multiple error conditions are true.
    ///
    /// Priority ordering rationale:
    /// 1. Global denial checked first because when Location Services are disabled system-wide,
    ///    Core Location reports authorizationStatus == .denied AND locationServicesEnabled() == false,
    ///    causing BOTH authorizationDenied and authorizationDeniedGlobally flags to be true.
    ///    Checking global first ensures we direct users to the correct Settings path (system toggle
    ///    vs app-specific permissions).
    /// 2. Other authorization issues (restricted, denied, insufficient) follow since they require
    ///    explicit user action.
    /// 3. Transient system issues (unavailable, session required) checked last since they may
    ///    resolve without user intervention.
    ///
    /// - Parameter update: The location update containing state information
    /// - Returns: A GPSLocationError if any error condition is detected, nil if the update is valid
    init?(locationUpdate update: LocationUpdate) {
        // Check global denial FIRST - when Location Services are off system-wide, both
        // authorizationDenied and authorizationDeniedGlobally are true. We must prioritize
        // the global case to direct users to the system-level toggle, not app settings.
        if update.authorizationDeniedGlobally {
            self = .authorizationDeniedGlobally
        } else if update.authorizationRestricted {
            self = .authorizationRestricted
        } else if update.authorizationDenied {
            self = .authorizationDenied
        } else if update.insufficientlyInUse {
            self = .insufficientlyInUse
        // Then check transient system issues
        } else if update.locationUnavailable {
            self = .locationUnavailable
        } else if update.serviceSessionRequired {
            self = .serviceSessionRequired
        } else {
            // No error condition detected - this is a valid update
            return nil
        }
    }

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "Location access is disabled for this app. You can enable it in Settings > Privacy > Location Services."
        case .authorizationDeniedGlobally:
            "Location Services are turned off. Please enable them in Settings > Privacy > Location Services."
        case .authorizationRestricted:
            "Location access is restricted by device management settings. Please contact your device administrator."
        case .insufficientlyInUse:
            "Additional location permissions are needed. Please update your location settings for this app."
        case .notFound:
            "Unable to determine location. Please check GPS signal and try again."
        case .locationUnavailable:
            "Location services are temporarily unavailable. This might be due to no GPS signal or airplane mode being enabled."
        case .serviceSessionRequired:
            "This feature requires an active service session. Please ensure necessary services like Find My are enabled."
        case .preciseLocationRequired:
            // Note: We use Bundle.main.displayName because location permissions are granted at the
            // app level, not the framework level. Even if this code runs in a framework context,
            // the relevant Settings path uses the main app's name. The BundleExtensions fallback
            // to "this app" handles edge cases where CFBundleDisplayName is unavailable.
            "Precise location is required but only approximate location is available. Enable Precise Location in Settings > Privacy & Security > Location Services > \(Bundle.main.displayName) to share your exact location."
        }
    }
}

extension GPSLocationError {
    /// Maps errors from the Core Location stream to domain-specific GPS errors.
    ///
    /// This initializer is critical for proper error propagation from CLLocationUpdate.liveUpdates().
    /// Without this mapping, users would receive generic "location not found" errors instead of
    /// actionable messages like "Location access denied" that tell them how to fix the problem.
    ///
    /// - Parameter error: The error thrown by CLLocationUpdate.liveUpdates() or the stream itself
    /// - Returns: A mapped GPSLocationError, or nil for errors that should not surface to users
    init?(locationStreamError error: Error) {
        // If already a GPSLocationError, preserve it as-is
        if let gpsError = error as? GPSLocationError {
            self = gpsError
            return
        }

        // CancellationError is expected when tasks are cancelled (e.g., view dismissal).
        // We return nil to avoid surfacing this as an error to users since it's normal behavior.
        if error is CancellationError {
            return nil
        }

        // Only handle CLError types - other errors aren't location-specific
        guard let clError = error as? CLError else {
            return nil
        }

        switch clError.code {
        case .denied:
            // Critical distinction: Check if location services are disabled system-wide
            // vs just for this app. This provides users with the correct Settings path.
            if !CLLocationManager.locationServicesEnabled() {
                self = .authorizationDeniedGlobally
            } else {
                self = .authorizationDenied
            }
        case .promptDeclined:
            // User dismissed the "Precise Location" prompt without granting precise accuracy.
            // This occurs when the app requests precise location but the user has approximate
            // location enabled and chooses not to upgrade to precise when prompted by iOS.
            // We map this to preciseLocationRequired to provide actionable guidance on how to
            // enable precise location in Settings.
            self = .preciseLocationRequired
        case .locationUnknown, .network, .deferredAccuracyTooLow, .deferredDistanceFiltered, .deferredCanceled, .deferredFailed, .headingFailure:
            // These are all transient errors where location hardware/service is temporarily
            // unable to determine position. We map them all to locationUnavailable since
            // the user action is the same: wait and retry.
            self = .locationUnavailable
        default:
            // Other CLError types (like .rangingDisabled) aren't relevant for GPS location
            return nil
        }
    }
}
