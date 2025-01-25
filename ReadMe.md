# Location Provider

A modern Swift framework for handling GPS location services with async/await support.

## Features

- ✨ Modern Swift async/await API
- 🎯 High-precision GPS location tracking
- 📍 Reverse geocoding support
- 🔒 Built-in permission handling
- 📱 Main actor safety
- ⚡️ Live location updates
- 🧪 Testable architecture

## Requirements

- iOS 18.0+
- Swift 5.5+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/username/LocationProvider.git", from: "1.0.0")
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

### Testing

The framework is designed with testability in mind. You can create a test client with predefined responses:

```swift
let testClient = LocationProvider.Client.test(
    updates: [mockLocationUpdate],
    reverseGeocodeLocation: .success("New York")
)
let provider = LocationProvider(client: testClient)
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
let grandCanyon = GPSLocation.granndCanyon
#endif
```

## Architecture

The framework follows a clean architecture pattern with the following key components:

- `LocationProvider`: Main class for handling location services
- `GPSLocation`: Structure representing a geographical location with name
- `LocationUpdate`: Protocol defining location update requirements
- `GPSLocationError`: Comprehensive error handling

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.