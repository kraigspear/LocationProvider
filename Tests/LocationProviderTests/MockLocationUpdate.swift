//
//  MockLocationUpdate.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/26/25.
//

@testable import LocationProvider

import CoreLocation

/// A mock implementation of `LocationUpdate` protocol for testing purposes.
struct MockLocationUpdate: LocationUpdate {
    // MARK: - Properties

    private let mockLocation: CLLocation?
    private let mockAccuracyLimited: Bool
    private let mockAuthRequestInProgress: Bool
    private let mockAuthDenied: Bool
    private let mockAuthDeniedGlobally: Bool
    private let mockAuthRestricted: Bool
    private let mockInsufficientlyInUse: Bool
    private let mockLocationUnavailable: Bool
    private let mockServiceSessionRequired: Bool
    private let mockStationary: Bool

    // MARK: - Protocol Requirements

    /// The current location value, if available.
    var location: CLLocation? {
        mockLocation
    }

    /// A Boolean value indicating whether the location accuracy is limited.
    var accuracyLimited: Bool {
        mockAccuracyLimited
    }

    /// A Boolean value indicating whether an authorization request is currently in progress.
    var authorizationRequestInProgress: Bool {
        mockAuthRequestInProgress
    }

    /// A Boolean value indicating whether location authorization has been denied for this app.
    var authorizationDenied: Bool {
        mockAuthDenied
    }

    /// A Boolean value indicating whether location services are denied globally on the device.
    var authorizationDeniedGlobally: Bool {
        mockAuthDeniedGlobally
    }

    /// A Boolean value indicating whether location services are restricted on this device.
    var authorizationRestricted: Bool {
        mockAuthRestricted
    }

    /// A Boolean value indicating whether the app's location usage is insufficient for the requested operation.
    var insufficientlyInUse: Bool {
        mockInsufficientlyInUse
    }

    /// A Boolean value indicating whether location services are currently unavailable.
    var locationUnavailable: Bool {
        mockLocationUnavailable
    }

    /// A Boolean value indicating whether a service session is required for location updates.
    var serviceSessionRequired: Bool {
        mockServiceSessionRequired
    }

    /// A Boolean value indicating whether the device is stationary.
    var stationary: Bool {
        mockStationary
    }

    // MARK: - Initialization

    /// Creates a mock location update with specified values.
    /// - Parameters:
    ///   - location: The mock location value.
    ///   - accuracyLimited: Whether location accuracy is limited.
    ///   - authorizationRequestInProgress: Whether an authorization request is in progress.
    ///   - authorizationDenied: Whether location authorization is denied.
    ///   - authorizationDeniedGlobally: Whether location services are denied globally.
    ///   - authorizationRestricted: Whether location services are restricted.
    ///   - insufficientlyInUse: Whether the app's location usage is insufficient.
    ///   - locationUnavailable: Whether location services are unavailable.
    ///   - serviceSessionRequired: Whether a service session is required.
    ///   - stationary: Whether the device is stationary.
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
        mockLocation = location
        mockAccuracyLimited = accuracyLimited
        mockAuthRequestInProgress = authorizationRequestInProgress
        mockAuthDenied = authorizationDenied
        mockAuthDeniedGlobally = authorizationDeniedGlobally
        mockAuthRestricted = authorizationRestricted
        mockInsufficientlyInUse = insufficientlyInUse
        mockLocationUnavailable = locationUnavailable
        mockServiceSessionRequired = serviceSessionRequired
        mockStationary = stationary
    }
}

// MARK: - Factory Methods

extension MockLocationUpdate {
    /// Creates a mock representing a denied authorization state.
    static func denied() -> Self {
        Self(
            authorizationDenied: true,
            locationUnavailable: true)
    }

    /// Creates a mock representing a restricted authorization state.
    static func restricted() -> Self {
        Self(
            authorizationRestricted: true,
            locationUnavailable: true)
    }

    /// Creates a mock representing an in-progress authorization request state.
    static func requestInProgress() -> Self {
        Self(
            authorizationRequestInProgress: true,
            locationUnavailable: true)
    }

    /// Creates a mock representing an insufficiently in-use state.
    static func insufficientlyInUse() -> Self {
        Self(
            insufficientlyInUse: true,
            locationUnavailable: true)
    }

    /// Creates a mock representing a state requiring service session.
    static func serviceSessionRequired() -> Self {
        Self(
            serviceSessionRequired: true)
    }

    /// Creates a mock representing a state where location is not available.
    static func locationNotAvailable() -> Self {
        Self(
            locationUnavailable: true)
    }
}
