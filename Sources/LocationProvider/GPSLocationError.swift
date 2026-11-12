//
//  GPSLocationError.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/25/25.
//

import Foundation

/// Represents possible errors that can occur during GPS location operations.
///
/// This enum abstracts Core Location's complex error model into actionable GPS-specific errors.
/// Each case maps to specific user guidance in errorDescription, enabling apps to show
/// contextual help without reimplementing Core Location error logic everywhere.
public enum GPSLocationError: LocalizedError, Sendable {
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

    /// User has denied location permissions or location services are disabled
    ///
    /// Why this exists: The most common authorization failure. Requires user to enable
    /// location services in Settings. When users open Settings, the UI immediately shows
    /// whether location is disabled system-wide or just for this app.
    case authorizationDenied

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

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "Location access is not available. Enable location in Settings > Privacy & Security > Location Services."
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
            // Settings lists location permissions under the host app, so use Bundle.main.
            "Precise location is required but only approximate location is available. Enable Precise Location in Settings > Privacy & Security > Location Services > \(Bundle.main.displayName) to share your exact location."
        }
    }
}

private extension Bundle {
    /// The app's user-facing name as Settings lists it, or "this app" when the bundle has none.
    var displayName: String {
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let name = object(forInfoDictionaryKey: key) as? String, !name.isEmpty {
                return name
            }
        }
        return "this app"
    }
}
