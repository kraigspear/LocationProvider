//
//  ContentView.swift
//  TestApp
//
//  Created by Kraig Spear on 1/26/25.
//

import SwiftUI

/// Manual checks the UI tests can't automate:
/// - Location Services off: the denied message and Open Location Settings.
/// - Airplane Mode: GPS stays on, so a location (named "GPS" if geocoding can't reach the network), or Try Again
///   if no fix arrives.
struct ContentView: View {
    var body: some View {
        FindLocationView()
    }
}

#Preview("ContentView") {
    ContentView()
}
