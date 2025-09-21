//
//  GPSLocation.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/25/25.
//

import CoreLocation

/// A structure that represents a geographical location with an associated name.
///
/// This structure combines a physical location (represented by `CLLocation`) with a human-readable name
/// for that location. If no specific name is provided, it defaults to "GPS".
public struct GPSLocation: CustomStringConvertible, Sendable, Equatable {
    // MARK: Properties

    /// The human-readable name of the location
    public let name: String

    /// The physical location coordinates and related information
    public let location: CLLocation

    // MARK: Initialization

    /// Creates a new GPS location with a name and coordinates.
    ///
    /// - Parameters:
    ///   - name: An optional string representing the location's name. Defaults to "GPS" if nil
    ///   - location: A `CLLocation` object containing the physical location data
    public init(name: String?, location: CLLocation) {
        self.name = name ?? "GPS"
        self.location = location
    }

    public var description: String {
        "name: \(name) location: \(location)"
    }
}

#if DEBUG

    public extension GPSLocation {
        // Major tech company headquarters
        static let appleHQ = GPSLocation(
            name: "Apple Park",
            location: CLLocation(latitude: 37.334922, longitude: -122.009033)
        )

        static let googleHQ = GPSLocation(
            name: "Googleplex",
            location: CLLocation(latitude: 37.422160, longitude: -122.084270)
        )

        // Famous landmarks
        static let eiffelTower = GPSLocation(
            name: "Eiffel Tower",
            location: CLLocation(latitude: 48.858370, longitude: 2.294481)
        )

        static let statueOfLiberty = GPSLocation(
            name: "Statue of Liberty",
            location: CLLocation(latitude: 40.689247, longitude: -74.044502)
        )

        // Popular tourist destinations
        static let timesSquare = GPSLocation(
            name: "Times Square",
            location: CLLocation(latitude: 40.758896, longitude: -73.985130)
        )

        static let grandCanyon = GPSLocation(
            name: "Grand Canyon Visitor Center",
            location: CLLocation(latitude: 36.054445, longitude: -112.134166)
        )
    }

#endif
