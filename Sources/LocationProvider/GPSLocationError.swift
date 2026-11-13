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

    /// No location arrived before the timeout or the end of updates, and nothing reported why.
    case notFound

    /// User has denied location permissions or location services are disabled
    ///
    /// Why this exists: The most common authorization failure. Requires user to enable
    /// location services in Settings. When users open Settings, the UI immediately shows
    /// whether location is disabled system-wide or just for this app.
    case authorizationDenied

    /// Core Location suspended updates because the app wasn't in use, such as a request made from the background.
    ///
    /// No setting fixes it: updates resume once the app is in use, so asking again from the foreground can succeed.
    case insufficientlyInUse

    /// Core Location reported it couldn't determine a location.
    case locationUnavailable

    /// The app requires an explicit `CLServiceSession` for location but holds none.
    ///
    /// Why this exists: an app that opts into explicit service sessions gets no location until it
    /// creates one. That is the app's fix, not the user's, so the message names no setting to change.
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
            "Location updates paused while this app wasn't in use. Try again."
        case .notFound:
            "Unable to determine location. Please check GPS signal and try again."
        case .locationUnavailable:
            "Location services are temporarily unavailable. This might be due to no GPS signal or airplane mode being enabled."
        case .serviceSessionRequired:
            "This app can't use your location right now."
        case .preciseLocationRequired:
            // Settings lists location permissions under the host app, so use Bundle.main.
            "Precise location is required but only approximate location is available. Enable Precise Location in Settings > Privacy & Security > Location Services > \(Bundle.main.displayName) to share your exact location."
        }
    }

    /// What the user can do about an error.
    public enum Recovery: Sendable {
        /// The cause may clear on its own, so asking again can succeed.
        case retry
        /// A setting the user controls blocks the location; ``openLocationSettings()`` takes them there.
        case openSettings
        /// Nothing the user can change: device management or the app itself blocks the location.
        case none
    }

    /// What the user can do about this error, so callers show the same remedy for the same cause.
    public var recovery: Recovery {
        switch self {
        case .notFound, .locationUnavailable, .insufficientlyInUse:
            .retry
        case .authorizationDenied, .preciseLocationRequired:
            .openSettings
        case .authorizationRestricted, .serviceSessionRequired:
            .none
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
