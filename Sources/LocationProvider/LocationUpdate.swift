//
//  LocationUpdate.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/26/25.
//

import CoreLocation

/// A protocol that defines the requirements for location update information.
protocol LocationUpdate: Sendable, CustomStringConvertible {
    /// The current location value, if available.
    var location: CLLocation? { get }

    /// A Boolean value indicating whether the location accuracy is limited.
    var accuracyLimited: Bool { get }

    /// A Boolean value indicating whether an authorization request is currently in progress.
    var authorizationRequestInProgress: Bool { get }

    /// A Boolean value indicating whether location authorization has been denied for this app.
    var authorizationDenied: Bool { get }

    /// A Boolean value indicating whether location services are denied globally on the device.
    var authorizationDeniedGlobally: Bool { get }

    /// A Boolean value indicating whether location services are restricted on this device.
    var authorizationRestricted: Bool { get }

    /// A Boolean value indicating whether the app's location usage is insufficient for the requested operation.
    var insufficientlyInUse: Bool { get }

    /// A Boolean value indicating whether location services are currently unavailable.
    var locationUnavailable: Bool { get }

    /// A Boolean value indicating whether a service session is required for location updates.
    var serviceSessionRequired: Bool { get }

    /// A Boolean value indicating whether the device is stationary.
    var stationary: Bool { get }
}

extension LocationUpdate {
    public var description: String {
        let locationString = location.map { "location: \($0)" }

        let status = [
            locationString,
            accuracyLimited ? "accuracyLimited" : nil,
            authorizationRequestInProgress ? "authorizationRequestInProgress" : nil,
            authorizationDenied ? "authorizationDenied" : nil,
            authorizationDeniedGlobally ? "authorizationDeniedGlobally" : nil,
            authorizationRestricted ? "authorizationRestricted" : nil,
            insufficientlyInUse ? "insufficientlyInUse" : nil,
            locationUnavailable ? "locationUnavailable" : nil,
            serviceSessionRequired ? "serviceSessionRequired" : nil,
            stationary ? "stationary" : nil,
        ].compactMap(\.self)

        return "<LocationUpdate: \(status.joined(separator: ", "))>"
    }
}

/// Conformance of CLLocationUpdate to LocationUpdate protocol
extension CLLocationUpdate: @retroactive CustomStringConvertible {}
extension CLLocationUpdate: LocationUpdate {}
