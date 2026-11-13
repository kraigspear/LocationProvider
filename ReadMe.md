# Location Provider

A modern Swift framework for handling GPS location services with async/await support.

## Features

- ✨ One async call returns the current location
- 🎯 Optional precise-accuracy requirement
- 📍 Reverse geocoding support
- 🔒 Built-in permission handling
- 📱 Main actor safety
- 🧭 Typed errors that say how the user can recover

## Requirements

- iOS 26.0+ / macOS 26.0+
- Swift 6.4+
- Xcode 27.0+
- Strict Concurrency enabled

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/kraigspear/LocationProvider.git", .upToNextMinor(from: "0.2.0"))
]
```

## Usage

### Basic Location Retrieval

```swift
let provider = LocationProvider()

do {
    let location = try await provider.gpsLocation()
    print("Current location: \(location.name)")
    print("Coordinates: \(location.location.coordinate)")
} catch {
    print("Failed to get location: \(error)")
}
```

### Requesting Precise Locations

By default the provider returns the first available fix, even if the system supplies reduced-accuracy coordinates. To require a precise reading, pass the accuracy requirement explicitly:

```swift
let preciseLocation = try await provider.gpsLocation(accuracyRequirement: .precise)
```

### Tuning Acquisition Timing

You can adjust how aggressively the provider waits for a fix by supplying a `LocationProvider.Configuration` when constructing the provider:

```swift
let configuration = LocationProvider.Configuration(
    locationAcquisitionTimeout: .seconds(45),
    locationUnavailableGracePeriod: .seconds(20)
)

let provider = LocationProvider(configuration: configuration)
```

The defaults (`10s` timeout, `5s` grace) work well for foreground usage. Increase the values if your app can tolerate longer waits for a high-quality fix; decrease them for faster failure modes (for example, a Weather app that can fall back to cached data).

### Handling Permissions

The framework automatically handles location permission requests and provides clear error messages for various authorization states. Make sure to add the usage description key to your Info.plist:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is used to provide relevant nearby information.</string>
```

### Error Handling

The framework provides detailed error cases through `GPSLocationError`:

- `authorizationDenied`: Location access is not available (app denied or system-wide disabled)
- `authorizationRestricted`: Location access is restricted by parental controls
- `insufficientlyInUse`: Updates were suspended because the app wasn't in use, such as a request from the background
- `notFound`: No location arrived before the timeout or the end of updates, and nothing reported why
- `locationUnavailable`: Core Location reported it couldn't determine a location
- `serviceSessionRequired`: The app requires a `CLServiceSession` but holds none
- `preciseLocationRequired`: User granted only approximate location but the feature needs precise access. This error also occurs when users dismiss the iOS system prompt to upgrade from approximate to precise location

#### Advanced Error Handling Example

Show the error's `localizedDescription`, and let its `recovery` pick the action:

```swift
do {
    let location = try await provider.gpsLocation()
    print("Location: \(location.name) at \(location.location.coordinate)")
} catch {
    switch error.recovery {
    case .retry: showRetryAlert(message: error.localizedDescription)
    case .openSettings: showSettingsAlert(message: error.localizedDescription)
    case .none: showMessage(error.localizedDescription)
    }
}
```

### Opening Location Settings

Each error's `recovery` says what the user can do: `.retry`, `.openSettings`, or `.none`. When it's `.openSettings`, help users fix the problem by opening the location settings:

```swift
import LocationProvider

do {
    let location = try await provider.gpsLocation()
} catch where error.recovery == .openSettings {
    // Drives an alert whose button calls openLocationSettings()
    settingsError = error
} catch {
    // Handle other errors
}
```

The `openLocationSettings()` function opens the appropriate settings screen:
- **iOS**: Opens your app's settings page where location permissions can be managed
- **macOS**: Opens Security & Privacy → Location Services in System Settings

#### SwiftUI Example

```swift
struct LocationView: View {
    @State private var error: GPSLocationError?

    var body: some View {
        VStack {
            if let error = error {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)

                if error.recovery == .openSettings {
                    Button("Open Location Settings") {
                        Task {
                            await openLocationSettings()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
```

### Testing

To test code that uses `LocationProvider`, put it behind a protocol your app owns and inject a mock:

```swift
@MainActor
protocol LocationProviding {
    func gpsLocation(accuracyRequirement: LocationProvider.AccuracyRequirement) async throws(GPSLocationError) -> GPSLocation
}

extension LocationProvider: LocationProviding {}
```

A mock returns a `GPSLocation` or throws a `GPSLocationError`. The DocC Testing article has a full example.

### Debug Support

Debug builds include two predefined locations for previews and tests:

```swift
#if DEBUG
let appleLocation = GPSLocation.appleHQ
let statueOfLiberty = GPSLocation.statueOfLiberty
#endif
```

## SwiftUI Integration

The framework is @MainActor-safe and works seamlessly with SwiftUI:

```swift
struct LocationView: View {
    @State private var location: GPSLocation?
    @State private var isLoading = false
    @State private var error: GPSLocationError?

    private let locationProvider = LocationProvider()

    var body: some View {
        VStack {
            if let location = location {
                Text("Current Location: \(location.name)")
                Text("Coordinates: \(location.location.coordinate)")
            } else if isLoading {
                ProgressView("Finding location...")
            } else if let error = error {
                Text(error.localizedDescription)
            }
        }
        .task {
            await findLocation()
        }
    }

    private func findLocation() async {
        isLoading = true
        defer { isLoading = false }

        do {
            location = try await locationProvider.gpsLocation()
        } catch {
            self.error = error
        }
    }
}
```

## Performance & Best Practices

### Battery
- Each `gpsLocation()` call listens to CoreLocation's live updates only until it has a location or an error, then stops
- The framework does no background location tracking

### Thread Safety
- `LocationProvider` is `@MainActor`, so call it from UI code directly
- Use `async/await` patterns instead of completion handlers

## Key Components

- `LocationProvider`: Fetches the current location; `Configuration` tunes its timing
- `GPSLocation`: A location with its reverse-geocoded name
- `GPSLocationError`: Why no location arrived, with a message and a `recovery`
- `openLocationSettings()`: Opens the settings screen where users grant location access

## Framework Integration

### MapKit Integration

```swift
import MapKit

extension GPSLocation {
    var mapItem: MKMapItem {
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = name
        return mapItem
    }
}
```

### SwiftData Integration

```swift
import SwiftData

@Model
class SavedLocation {
    var name: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date

    init(from gpsLocation: GPSLocation) {
        self.name = gpsLocation.name
        self.latitude = gpsLocation.location.coordinate.latitude
        self.longitude = gpsLocation.location.coordinate.longitude
        self.timestamp = Date()
    }
}
```

## Swift 6 Compatibility

This package is built with Swift 6's strict concurrency checking enabled. This ensures:
- No data races at compile time
- Safe concurrent access to location data
- Proper actor isolation for UI updates

### Migration from Delegate Patterns

If migrating from traditional CoreLocation patterns:

```swift
// Old pattern ❌
locationManager.requestLocation()
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // Handle in delegate
}

// New pattern ✅
let location = try await locationProvider.gpsLocation()
```

## Troubleshooting

### Common Issues

**`notFound` or `locationUnavailable` errors:**
- The device couldn't get a fix in time; move to a spot with a clearer view of the sky and try again
- Raise `locationAcquisitionTimeout` if your app can wait longer

**`authorizationDenied` errors:**
- Add the Info.plist key (see Handling Permissions)
- Location Services may be off for the whole device, or for your app
- Call `openLocationSettings()` to take users to the setting

**Reverse geocoding failures:**
- Network connectivity required for address lookup
- Some remote locations may not have address data
- Framework gracefully falls back to "GPS" name

**Testing on Simulator:**
- Use simulator's location simulation features
- Choose predefined locations or set custom coordinates
- Debug locations work great for testing UI

## Dependencies

This package has minimal dependencies:
- **CoreLocation**: iOS/macOS system framework (no external dependencies)
- **Foundation**: Standard library components
- **os.log**: For internal debugging and logging

No third-party dependencies are required.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

Run the unit tests with `./test.sh`, which passes its arguments to `swift test`. It fails a run that hangs, which Swift Testing's time limit cannot stop when a test waits on a continuation that never resumes.
