//
//  LocationInfoView.swift
//  TestApp
//
//  Created by Kraig Spear on 1/26/25.
//

import LocationProvider
import SwiftUI

struct LocationInfoView: View {
    let location: GPSLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Location Details", systemImage: "location.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                LineView(
                    title: "Name",
                    line: location.name,
                    identifier: "locationName")

                LineView(
                    title: "Latitude:",
                    line: String(format: "%.6f", location.location.coordinate.latitude),
                    identifier: "locationLatitude")

                LineView(
                    title: "Longitude:",
                    line: String(format: "%.6f", location.location.coordinate.longitude),
                    identifier: "locationLongitude")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }

    struct LineView: View {
        let title: String
        let line: String
        let identifier: String
        var body: some View {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Text(line)
                    .bold()
                    .accessibilityIdentifier(identifier)
            }
        }
    }
}

#Preview {
    LocationInfoView(location: .appleHQ)
}
