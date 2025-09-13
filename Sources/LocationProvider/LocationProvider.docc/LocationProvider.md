# ``LocationProvider``

A modern Swift framework for handling GPS location services with async/await support.

## Overview

LocationProvider is a SwiftUI-ready framework that provides a clean, modern API for GPS location services. Built with Swift 6 strict concurrency, it offers async/await location retrieval, comprehensive error handling, and seamless SwiftUI integration.

### Key Features

- **Modern Swift API**: Built with async/await and Swift 6 strict concurrency
- **High-precision GPS**: Accurate location tracking with CoreLocation
- **Reverse Geocoding**: Automatic conversion of coordinates to readable location names
- **Permission Management**: Built-in handling of location authorization states
- **SwiftUI Integration**: @MainActor safety for seamless UI updates
- **Comprehensive Testing**: Mock clients and test utilities included
- **Debug Support**: Predefined locations for development and testing

### Requirements

- iOS 18.0+ / macOS 15.0+
- Swift 6.2+
- Xcode 16.0+
- Strict Concurrency enabled

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:HandlingPermissions>

### Advanced Usage

- <doc:ErrorHandling>
- <doc:SwiftUIIntegration>
- <doc:Testing>
- <doc:BestPractices>

### API Reference

- ``LocationProvider/LocationProvider``
- ``GPSLocation``
- ``GPSLocationError``