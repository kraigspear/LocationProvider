# Getting Started

Learn how to quickly integrate LocationProvider into your iOS or macOS app.

## Overview

LocationProvider provides a simple, modern way to get the user's current location with just a few lines of code. This guide walks you through the basic integration steps and your first location request.

## Installation

### Swift Package Manager

Add LocationProvider to your project using Xcode's Package Manager:

1. In Xcode, go to **File > Add Package Dependencies...**
2. Enter the repository URL
3. Select the version you want to use
4. Add the package to your target

Alternatively, add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/LocationProvider.git", from: "1.0.0")
]
```

## Configure Info.plist

Before using location services, add the required usage description keys to your app's `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to show your current position.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to provide location-based features.</string>
```

> Important: The system shows these messages to users when requesting location permissions. Make them descriptive and explain why your app needs location access.

## Your First Location Request

Here's the simplest way to get the user's current location:

```swift
import LocationProvider

// Create a LocationProvider instance
let locationProvider = LocationProvider()

// Request the current location
do {
    let location = try await locationProvider.gpsLocation()
    print("Current location: \(location.name)")
    print("Coordinates: \(location.location.coordinate.latitude), \(location.location.coordinate.longitude)")
} catch {
    print("Failed to get location: \(error.localizedDescription)")
}
```

## Understanding the Response

When you call `gpsLocation()`, LocationProvider returns a ``GPSLocation`` object that contains:

- **`name`**: A human-readable location name (e.g., "San Francisco")
- **`location`**: The raw `CLLocation` object with coordinates, accuracy, and timestamp

```swift
let gpsLocation = try await locationProvider.gpsLocation()

// Access the readable name
print("You are in: \(gpsLocation.name)")

// Access coordinate details
let coordinate = gpsLocation.location.coordinate
print("Latitude: \(coordinate.latitude)")
print("Longitude: \(coordinate.longitude)")

// Access additional location data
print("Accuracy: \(gpsLocation.location.horizontalAccuracy) meters")
print("Timestamp: \(gpsLocation.location.timestamp)")
```

## What Happens Behind the Scenes

When you call `gpsLocation()`, LocationProvider:

1. **Requests Permissions**: Automatically handles location authorization if needed
2. **Gets Location**: Waits for the first accurate GPS reading
3. **Reverse Geocodes**: Converts coordinates to a readable place name
4. **Returns Result**: Provides both coordinates and human-readable name

The entire process is designed to be quick and battery-efficient, stopping location services once a result is obtained.

## Handling the Async Nature

Since location requests are asynchronous, use them within async contexts:

### In View Models

```swift
import Observation

@MainActor
@Observable
class LocationViewModel {
    var currentLocation: GPSLocation?
    var isLoading = false

    private let locationProvider = LocationProvider()

    func getCurrentLocation() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentLocation = try await locationProvider.gpsLocation()
        } catch {
            // Handle error (see Error Handling guide)
            print("Location error: \(error)")
        }
    }
}
```

### In SwiftUI Views

```swift
struct ContentView: View {
    @State private var location: GPSLocation?
    private let locationProvider = LocationProvider()

    var body: some View {
        VStack {
            if let location = location {
                Text("Current Location: \(location.name)")
            } else {
                Text("Tap to get location")
            }
        }
        .task {
            do {
                location = try await locationProvider.gpsLocation()
            } catch {
                // Handle error appropriately
            }
        }
    }
}
```

## Next Steps

Now that you have basic location functionality working, explore these guides to build more robust location features:

- <doc:HandlingPermissions> - Manage different authorization states
- <doc:ErrorHandling> - Handle location errors gracefully
- <doc:SwiftUIIntegration> - Advanced SwiftUI patterns
- <doc:Testing> - Test your location features
- <doc:BestPractices> - Optimize performance and user experience