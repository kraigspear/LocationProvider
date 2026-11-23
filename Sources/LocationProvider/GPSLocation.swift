//
//  GPSLocation.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/25/25.
//

import CoreLocation

/// A structure that represents a geographical location and, when known, its name.
///
/// This structure combines a physical location (represented by `CLLocation`) with a human-readable name
/// for that location, when reverse geocoding finds one.
public struct GPSLocation: CustomStringConvertible, Sendable, Equatable {
    // MARK: Properties

    /// The human-readable name of the location, or `nil` when reverse geocoding failed or found no name
    public let name: String?

    /// The physical location coordinates and related information
    public let location: CLLocation

    // MARK: Initialization

    /// Creates a new GPS location from coordinates and an optional name.
    ///
    /// - Parameters:
    ///   - name: The location's name, or `nil` when it has none
    ///   - location: A `CLLocation` object containing the physical location data
    public init(name: String?, location: CLLocation) {
        self.name = name
        self.location = location
    }

    public var description: String {
        "name: \(name ?? "nil") location: \(location)"
    }
}

#if DEBUG

    public extension GPSLocation {
        /// Major tech company headquarters
        static let appleHQ = GPSLocation(
            name: "Apple Park",
            location: CLLocation(latitude: 37.334922, longitude: -122.009033))

        /// Famous landmarks
        static let statueOfLiberty = GPSLocation(
            name: "Statue of Liberty",
            location: CLLocation(latitude: 40.689247, longitude: -74.044502))
    }

#endif
