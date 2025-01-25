//
//  GPSLocationError.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/25/25.
//

import CoreLocation
import Foundation

/// Represents possible errors that can occur during GPS location operations.
enum GPSLocationError: LocalizedError {
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
    
    var errorDescription: String? {
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
        }
    }
}
