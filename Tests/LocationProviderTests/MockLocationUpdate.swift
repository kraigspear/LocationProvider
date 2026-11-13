//
//  MockLocationUpdate.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/26/25.
//

import CoreLocation
@testable import LocationProvider

/// A `LocationUpdate` with every flag set directly.
struct MockLocationUpdate: LocationUpdate {
    let location: CLLocation?
    let accuracyLimited: Bool
    let authorizationRequestInProgress: Bool
    let authorizationDenied: Bool
    let authorizationDeniedGlobally: Bool
    let authorizationRestricted: Bool
    let insufficientlyInUse: Bool
    let locationUnavailable: Bool
    let serviceSessionRequired: Bool
    let stationary: Bool

    init(
        location: CLLocation? = nil,
        accuracyLimited: Bool = false,
        authorizationRequestInProgress: Bool = false,
        authorizationDenied: Bool = false,
        authorizationDeniedGlobally: Bool = false,
        authorizationRestricted: Bool = false,
        insufficientlyInUse: Bool = false,
        locationUnavailable: Bool = false,
        serviceSessionRequired: Bool = false,
        stationary: Bool = false)
    {
        self.location = location
        self.accuracyLimited = accuracyLimited
        self.authorizationRequestInProgress = authorizationRequestInProgress
        self.authorizationDenied = authorizationDenied
        self.authorizationDeniedGlobally = authorizationDeniedGlobally
        self.authorizationRestricted = authorizationRestricted
        self.insufficientlyInUse = insufficientlyInUse
        self.locationUnavailable = locationUnavailable
        self.serviceSessionRequired = serviceSessionRequired
        self.stationary = stationary
    }
}

// MARK: - Factory Methods

/// Each factory names its source. "Recorded" updates were logged from TestApp on the iOS 27.2 simulator;
/// "Not observed" ones are flag combinations no simulator run can produce.
extension MockLocationUpdate {
    /// Recorded: after tapping Don't Allow on the permission prompt.
    static func denied() -> Self {
        Self(authorizationDenied: true)
    }

    /// Not observed: needs device management or Screen Time.
    static func restricted() -> Self {
        Self(
            authorizationRestricted: true,
            locationUnavailable: true)
    }

    /// Recorded: while the permission prompt is showing.
    static func requestInProgress() -> Self {
        Self(authorizationRequestInProgress: true)
    }

    /// Not observed: needs location requested while the app isn't in use, such as from the background.
    static func insufficientlyInUse() -> Self {
        Self(
            insufficientlyInUse: true,
            locationUnavailable: true)
    }

    /// Not observed: needs the app to opt into explicit service sessions.
    static func serviceSessionRequired() -> Self {
        Self(
            serviceSessionRequired: true)
    }

    /// Recorded: with permission granted and the simulated location cleared.
    static func locationNotAvailable() -> Self {
        Self(
            locationUnavailable: true)
    }
}
