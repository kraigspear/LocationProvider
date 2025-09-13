# Location Provider

A modern Swift framework for handling GPS location services with async/await support.

[Technical Overview](Technical.md)

## Features

- ✨ Modern Swift async/await API
- 🎯 High-precision GPS location tracking
- 📍 Reverse geocoding support
- 🔒 Built-in permission handling
- 📱 Main actor safety
- ⚡️ Live location updates
- 🧪 Testable architecture

## Requirements

- iOS 18.0+ / macOS 15.0+
- Swift 6.2+
- Xcode 16.0+
- Strict Concurrency enabled

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/LocationProvider.git", from: "1.0.0")
]
```

## Usage

### Basic Location Retrieval

```swift
let provider = LocationProvider()

do {
    let location = try await provider.gpsLocation()
    print("Current location: \(location.name ?? "Unknown")")
    print("Coordinates: \(location.location.coordinate)")
} catch {
    print("Failed to get location: \(error)")
}
```

### Handling Permissions

The framework automatically handles location permission requests and provides clear error messages for various authorization states. Make sure to add the required usage description keys to your Info.plist:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is used to provide relevant nearby information.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Your location is used to provide relevant nearby information even when the app is not active.</string>
```

### Error Handling

The framework provides detailed error cases through `GPSLocationError`:

- `authorizationDenied`: User denied location access for the app
- `authorizationDeniedGlobally`: Location services are disabled system-wide
- `authorizationRestricted`: Location access is restricted by parental controls
- `insufficientlyInUse`: Current authorization level is insufficient
- `notFound`: Unable to determine location
- `locationUnavailable`: Location services temporarily unavailable
- `serviceSessionRequired`: Required service session not active
- `reverseGeocoding`: Failed to convert coordinates to address

#### Advanced Error Handling Example

```swift
do {
    let location = try await provider.gpsLocation()
    print("Location: \(location.name) at \(location.location.coordinate)")
} catch GPSLocationError.authorizationDenied {
    // Guide user to Settings > Privacy & Security > Location Services
    showLocationPermissionAlert()
} catch GPSLocationError.authorizationDeniedGlobally {
    // Guide user to enable Location Services system-wide
    showSystemLocationServicesAlert()
} catch GPSLocationError.locationUnavailable {
    // Handle airplane mode, poor GPS signal, etc.
    showLocationUnavailableAlert()
} catch {
    print("Unexpected error: \(error)")
}
```

### Testing

The framework is designed with testability in mind. You can create a test client with predefined responses:

```swift
// Testing successful location retrieval
let testClient = LocationProvider.Client.test(
    updates: [MockLocationUpdate(location: CLLocation.appleHQ)],
    reverseGeocodeLocation: .success("Cupertino")
)
let provider = LocationProvider(client: testClient)

// Testing permission denied scenario
let deniedClient = LocationProvider.Client.test(
    updates: [MockLocationUpdate.denied()],
    reverseGeocodeLocation: .success("Test")
)
// This will throw GPSLocationError.authorizationDenied

// Testing network failures in reverse geocoding
let networkFailClient = LocationProvider.Client.test(
    updates: [MockLocationUpdate(location: validLocation)],
    reverseGeocodeLocation: .failure(URLError(.notConnectedToInternet))
)
// Will return location with default "GPS" name
```

### Debug Support

For debugging purposes, the framework includes several predefined locations:

```swift
#if DEBUG
// Tech company headquarters
let appleLocation = GPSLocation.appleHQ
let googleLocation = GPSLocation.googleHQ

// Famous landmarks
let eiffelTower = GPSLocation.eiffelTower
let statueOfLiberty = GPSLocation.statueOfLiberty

// Tourist destinations
let timesSquare = GPSLocation.timesSquare
let grandCanyon = GPSLocation.grandCanyon
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
        } catch let error as GPSLocationError {
            self.error = error
        } catch {
            // Handle unexpected errors
        }
    }
}
```

## Performance & Best Practices

### Battery Optimization
- The framework uses CoreLocation's live updates which are optimized for battery life
- Location requests are designed to return quickly and stop automatically
- No continuous background location tracking unless explicitly needed

### Thread Safety
- All LocationProvider methods are marked `@MainActor` for UI safety
- Use `async/await` patterns instead of completion handlers
- The framework handles all background threading internally

### Memory Management
- LocationProvider uses value types (structs) where possible
- No retain cycles - safe to store in view models
- Automatic cleanup of location services when provider is deallocated

## Architecture

The framework follows a clean architecture pattern optimizing for:
- 🧪 **Testability**: Dependency injection with test doubles
- 🔒 **Thread Safety**: @MainActor annotations and Sendable protocols
- ⚡️ **Performance**: Efficient location updates and memory management
- 🎯 **Error Handling**: Comprehensive error types with user guidance

For detailed technical documentation including class diagrams and sequence flows, see [Technical Documentation](Technical.md).

### Key Components

- `LocationProvider`: Main class for handling location services
- `GPSLocation`: Structure representing a geographical location with name
- `LocationUpdate`: Protocol defining location update requirements
- `GPSLocationError`: Comprehensive error handling

## Framework Integration

### MapKit Integration

```swift
import MapKit

extension GPSLocation {
    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: location.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        return mapItem
    }
}
```

### Core Data Integration

```swift
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

**"Location not found" errors:**
- Ensure Location Services are enabled in device settings
- Check that your app has location permissions
- Verify GPS signal availability (not in airplane mode)

**"Authorization denied" errors:**
- Add required Info.plist keys (see Configuration section)
- Guide users to Settings > Privacy & Security > Location Services > [Your App]

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

## License

This project is licensed under the MIT License - see the LICENSE file for details.
