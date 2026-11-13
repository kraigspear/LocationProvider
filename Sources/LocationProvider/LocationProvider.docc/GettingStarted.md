# Getting Started

Learn how to quickly integrate LocationProvider into your iOS or macOS app.

## Overview

LocationProvider provides a simple, modern way to get the user's current location with just a few lines of code. This guide walks you through the basic integration steps and your first location request.

## Installation

### Swift Package Manager

Add LocationProvider to your project using Xcode's Package Manager:

1. In Xcode, go to **File > Add Package Dependencies...**
2. Enter the repository URL
3. Choose **Up to Next Minor Version** from `0.2.0`
4. Add the package to your target

Alternatively, add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/kraigspear/LocationProvider.git", .upToNextMinor(from: "0.2.0"))
]
```

## Configure Info.plist

Before using location services, add the usage description key to your app's `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to show your current position.</string>
```

> Important: The system shows this message to users when requesting location permissions. Make it descriptive and explain why your app needs location access.

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
    // localizedDescription is written for the user; recovery says what they can do
    print("Failed to get location: \(error.localizedDescription)")
}
```

## Understanding the Response

When you call `gpsLocation()`, LocationProvider returns a ``GPSLocation`` object that contains:

- **`name`**: A human-readable location name (e.g., "San Francisco") or `"GPS"` if reverse geocoding fails
- **`location`**: The raw `CLLocation` object with coordinates, accuracy, and timestamp

```swift
let gpsLocation = try await locationProvider.gpsLocation()

// Access the readable name (defaults to "GPS" if reverse geocoding failed)
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
2. **Gets Location**: Waits for the first accurate GPS reading from Core Location's live updates
3. **Error Handling**: Reports any failure as a ``GPSLocationError`` with a user-facing message and a recovery
4. **Reverse Geocodes**: Converts coordinates to a readable place name
5. **Returns Result**: Provides both coordinates and human-readable name

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
            print("Location error: \(error.localizedDescription)")
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
                // LocationProvider provides user-friendly error messages
                print("Location error: \(error.localizedDescription)")
                // Handle error appropriately (see Error Handling guide)
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