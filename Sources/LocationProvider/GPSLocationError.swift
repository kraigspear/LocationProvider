//
//  GPSLocationError.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/25/25.
//

import CoreLocation
import Foundation

/// Represents possible errors that can occur during GPS location operations.
public enum GPSLocationError: LocalizedError {
    /// Location access is restricted by parental controls or device management
    case authorizationRestricted
    /// Location services are temporarily unavailable or cannot determine position
    case notFound
    /// User has explicitly denied location permissions for this app
    case authorizationDenied
    /// Location services are disabled system-wide in device settings
    case authorizationDeniedGlobally
    /// Current authorization level is not sufficient for the required location features
    case insufficientlyInUse
    /// Location services are currently unavailable (e.g., no GPS signal, hardware issues)
    case locationUnavailable
    /// A service session (like Find My) is required but not active
    case serviceSessionRequired
    /// Attempt to get the name through reverse geocoding failed
    case reverseGeocoding

    /// User granted approximate location permission but the app requires precise location.
    ///
    /// In iOS 14+, users can choose to share only approximate location (~1-20km accuracy) with apps
    /// for privacy. This error occurs when the app requests precise location but the user has only
    /// granted approximate location access. Users can enable precise location in Settings > Privacy
    /// & Security > Location Services > [App Name] > Precise Location.
    case preciseLocationRequired

    init?(locationUpdate update: LocationUpdate) {
        switch true {
        case update.authorizationDenied:
            self = .authorizationDenied
        case update.authorizationDeniedGlobally:
            self = .authorizationDeniedGlobally
        case update.authorizationRestricted:
            self = .authorizationRestricted
        case update.insufficientlyInUse:
            self = .insufficientlyInUse
        case update.locationUnavailable:
            self = .locationUnavailable
        case update.serviceSessionRequired:
            self = .serviceSessionRequired
        default:
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
        case .reverseGeocoding:
            "Failed to convert location coordinates to an address. This may be due to network issues or the location being unmapped."
        case .preciseLocationRequired:
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
