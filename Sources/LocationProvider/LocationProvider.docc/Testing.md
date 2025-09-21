# Testing

Write comprehensive tests for location features using mock clients and predefined scenarios.

## Overview

LocationProvider is designed with testing in mind. The framework provides mock clients, test utilities, and predefined location data to help you write thorough tests for all location scenarios. With the recent improvements to error handling and the shift to `AsyncThrowingStream`, you can now test sophisticated error scenarios that closely mirror real-world Core Location behavior. This guide shows you how to test location features, permission handling, error cases, and SwiftUI integration.

## Testing the New Error Handling

LocationProvider now uses `AsyncThrowingStream<LocationUpdate, Error>` instead of `AsyncStream`, enabling proper error propagation from Core Location. This allows for more realistic testing of error scenarios.

## Basic Testing Setup

LocationProvider includes test utilities that make it easy to simulate different location scenarios:

```swift
import Testing
import LocationProvider
import CoreLocation

@MainActor
struct LocationProviderTests {
    @Test("Successfully retrieve location")
    func testLocationRetrieval() async throws {
        // Arrange: Create test client with successful location
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let client = LocationProvider.Client.test(
            updates: [MockLocationUpdate.authorized(with: testLocation)],
            reverseGeocodeLocation: .success("San Francisco")
        )
        let provider = LocationProvider(client: client)

        // Act: Request location
        let result = try await provider.gpsLocation()

        // Assert: Verify results
        #expect(result.location == testLocation)
        #expect(result.name == "San Francisco")
    }
}
```

## Testing Permission Scenarios

Test all possible permission states using the provided mock updates. The improved error handling means permission failures now surface immediately with specific error messages:

### Permission Granted

```swift
@Test("Location permission granted")
func testPermissionGranted() async throws {
    let testLocation = CLLocation.appleHQ
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.authorized(with: testLocation)],
        reverseGeocodeLocation: .success("Cupertino")
    )
    let provider = LocationProvider(client: client)

    let location = try await provider.gpsLocation()
    #expect(location.name == "Cupertino")
    #expect(location.location == testLocation)
}
```

### Permission Request Flow

```swift
@Test("Permission request then location received")
func testPermissionRequestFlow() async throws {
    let testLocation = CLLocation.googleHQ
    let client = LocationProvider.Client.test(
        updates: [
            MockLocationUpdate.requestInProgress(),  // Permission dialog shown
            MockLocationUpdate.authorized(with: testLocation)  // Permission granted
        ],
        reverseGeocodeLocation: .success("Mountain View")
    )
    let provider = LocationProvider(client: client)

    let location = try await provider.gpsLocation()
    #expect(location.name == "Mountain View")
}
```

### Permission Denied

```swift
@Test("Permission denied throws appropriate error with specific message")
func testPermissionDenied() async {
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.denied()],
        reverseGeocodeLocation: .success("Test")
    )
    let provider = LocationProvider(client: client)

    do {
        _ = try await provider.gpsLocation()
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as GPSLocationError {
        #expect(error == .authorizationDenied)
        // Verify the error message is actionable
        #expect(error.localizedDescription.contains("Location access is disabled"))
        #expect(error.localizedDescription.contains("Settings"))
    }
}
```

### Globally Denied Permissions

```swift
@Test("Location services globally disabled with specific guidance")
func testGloballyDeniedPermissions() async {
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.deniedGlobally()],
        reverseGeocodeLocation: .success("Test")
    )
    let provider = LocationProvider(client: client)

    do {
        _ = try await provider.gpsLocation()
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as GPSLocationError {
        #expect(error == .authorizationDeniedGlobally)
        // Verify the error distinguishes between app-level and system-level issues
        #expect(error.localizedDescription.contains("Location Services are turned off"))
        #expect(error.localizedDescription.contains("Settings > Privacy"))
    }
}
```

### Restricted Access

```swift
@Test("Location access restricted")
func testRestrictedAccess() async {
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.restricted()],
        reverseGeocodeLocation: .success("Test")
    )
    let provider = LocationProvider(client: client)

    await #expect(throws: GPSLocationError.authorizationRestricted) {
        _ = try await provider.gpsLocation()
    }
}
```

## Testing Error Scenarios

### Location Unavailable

```swift
@Test("Location unavailable error with helpful message")
func testLocationUnavailable() async {
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.locationNotAvailable()],
        reverseGeocodeLocation: .success("Test")
    )
    let provider = LocationProvider(client: client)

    do {
        _ = try await provider.gpsLocation()
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as GPSLocationError {
        #expect(error == .locationUnavailable)
        // Verify the error message provides helpful guidance
        #expect(error.localizedDescription.contains("temporarily unavailable"))
        #expect(error.localizedDescription.contains("GPS signal") ||
               error.localizedDescription.contains("airplane mode"))
    }
}
```

### Testing Stream Error Propagation

Test that errors from the underlying Core Location stream are properly propagated:

```swift
@Test("Stream errors are properly mapped to GPSLocationError")
func testStreamErrorMapping() async {
    // Test that CancellationError is filtered out
    let cancellationClient = LocationProvider.Client.test(
        updates: [], // Empty updates will cause stream to end
        reverseGeocodeLocation: .success("Test")
    )
    let provider1 = LocationProvider(client: cancellationClient)

    // Should throw .notFound, not CancellationError
    do {
        _ = try await provider1.gpsLocation()
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as GPSLocationError {
        // CancellationError should be filtered and mapped to .notFound
        #expect(error == .notFound)
    }
}

@Test("CLError.denied is properly mapped based on system state")
func testCLErrorMapping() async {
    // This test would need to be integrated with the actual LocationProvider
    // to test CLError mapping, as the test client doesn't simulate CLErrors

    // In a real scenario, you'd test:
    // - CLError.denied → GPSLocationError.authorizationDenied when location services enabled
    // - CLError.denied → GPSLocationError.authorizationDeniedGlobally when location services disabled
    // - CLError.locationUnknown → GPSLocationError.locationUnavailable
    // - CLError.network → GPSLocationError.locationUnavailable

    // This demonstrates the error mapping logic without requiring real CLError injection
    let deniedError = GPSLocationError(locationStreamError: CLError(.denied))
    #expect(deniedError != nil)
    #expect(deniedError == .authorizationDenied || deniedError == .authorizationDeniedGlobally)
}
```

### Insufficient Permissions

```swift
@Test("Insufficient permission level")
func testInsufficientPermissions() async {
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.insufficientlyInUse()],
        reverseGeocodeLocation: .success("Test")
    )
    let provider = LocationProvider(client: client)

    await #expect(throws: GPSLocationError.insufficientlyInUse) {
        _ = try await provider.gpsLocation()
    }
}
```

### Service Session Required

```swift
@Test("Service session required error")
func testServiceSessionRequired() async {
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.serviceSessionRequired()],
        reverseGeocodeLocation: .success("Test")
    )
    let provider = LocationProvider(client: client)

    await #expect(throws: GPSLocationError.serviceSessionRequired) {
        _ = try await provider.gpsLocation()
    }
}
```

## Testing Reverse Geocoding

### Successful Reverse Geocoding

```swift
@Test("Reverse geocoding success")
func testReverseGeocodingSuccess() async throws {
    let testLocation = CLLocation.eiffelTower
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.authorized(with: testLocation)],
        reverseGeocodeLocation: .success("Paris")
    )
    let provider = LocationProvider(client: client)

    let location = try await provider.gpsLocation()
    #expect(location.name == "Paris")
}
```

### Reverse Geocoding Failure

```swift
@Test("Reverse geocoding failure falls back gracefully")
func testReverseGeocodingFailure() async throws {
    let testLocation = CLLocation.statueOfLiberty
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.authorized(with: testLocation)],
        reverseGeocodeLocation: .failure(URLError(.notConnectedToInternet))
    )
    let provider = LocationProvider(client: client)

    // Should still succeed but with nil name
    let location = try await provider.gpsLocation()
    #expect(location.name == nil)  // Name is nil when geocoding fails
    #expect(location.location == testLocation)

    // Verify coordinates are still available despite geocoding failure
    #expect(abs(location.location.coordinate.latitude - testLocation.coordinate.latitude) < 0.001)
    #expect(abs(location.location.coordinate.longitude - testLocation.coordinate.longitude) < 0.001)
}
```

## Testing Error Message Quality

Test that error messages are user-friendly and actionable:

```swift
@Test("Error messages are user-friendly and actionable")
func testErrorMessageQuality() {
    let errors: [GPSLocationError] = [
        .authorizationDenied,
        .authorizationDeniedGlobally,
        .authorizationRestricted,
        .locationUnavailable,
        .notFound
    ]

    for error in errors {
        let message = error.localizedDescription

        // All error messages should be non-empty
        #expect(!message.isEmpty)

        // Messages should not contain technical jargon
        #expect(!message.contains("CLError"))
        #expect(!message.contains("Core Location"))

        // Authorization errors should mention Settings
        if case .authorizationDenied = error {
            #expect(message.contains("Settings"))
            #expect(message.contains("Privacy"))
            #expect(message.contains("Location Services"))
        }

        if case .authorizationDeniedGlobally = error {
            #expect(message.contains("Settings"))
            #expect(message.contains("Privacy"))
            #expect(message.contains("Location Services"))
        }

        // Technical errors should provide helpful guidance
        if case .locationUnavailable = error {
            #expect(message.contains("temporarily") || message.contains("GPS") || message.contains("signal"))
        }
    }
}
```

## Testing with Predefined Locations

LocationProvider includes debug locations for testing:

```swift
#if DEBUG
@Test("Using predefined debug locations")
func testDebugLocations() async throws {
    // Test with Apple HQ
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.authorized(with: CLLocation.appleHQ)],
        reverseGeocodeLocation: .success("Apple Park")
    )
    let provider = LocationProvider(client: client)

    let location = try await provider.gpsLocation()
    #expect(location.name == "Apple Park")

    // Verify coordinates match Apple HQ
    let coordinate = location.location.coordinate
    #expect(abs(coordinate.latitude - 37.334922) < 0.001)
    #expect(abs(coordinate.longitude - (-122.009033)) < 0.001)
}

extension CLLocation {
    static let appleHQ = CLLocation(latitude: 37.334922, longitude: -122.009033)
    static let googleHQ = CLLocation(latitude: 37.422160, longitude: -122.084270)
    static let eiffelTower = CLLocation(latitude: 48.858370, longitude: 2.294481)
    static let statueOfLiberty = CLLocation(latitude: 40.689247, longitude: -74.044502)
}
#endif
```

## Testing SwiftUI Components

Test SwiftUI views that use LocationProvider:

```swift
@MainActor
struct LocationViewTests {
    @Test("LocationView displays location correctly")
    func testLocationViewDisplay() async throws {
        // Create a test location manager
        let testLocation = GPSLocation(
            name: "Test Location",
            location: CLLocation(latitude: 40.7128, longitude: -74.0060)
        )

        let locationManager = TestLocationManager()
        locationManager.location = testLocation

        // Test that view displays the location
        #expect(locationManager.location?.name == "Test Location")
        #expect(locationManager.hasLocation == true)
    }

    @Test("LocationView handles loading state")
    func testLocationViewLoading() {
        let locationManager = TestLocationManager()
        locationManager.isLoading = true

        #expect(locationManager.isLoading == true)
        #expect(locationManager.hasLocation == false)
    }

    @Test("LocationView handles error state")
    func testLocationViewError() {
        let locationManager = TestLocationManager()
        locationManager.error = .authorizationDenied

        #expect(locationManager.error == .authorizationDenied)
        #expect(locationManager.canRetry == true)
    }
}

// Test double for LocationManager
@MainActor
@Observable
class TestLocationManager {
    var location: GPSLocation?
    var error: GPSLocationError?
    var isLoading = false

    var hasLocation: Bool {
        location != nil
    }

    var canRetry: Bool {
        error != nil && !isLoading
    }

    func requestLocation() async {
        // Mock implementation for testing
    }

    func reset() {
        location = nil
        error = nil
        isLoading = false
    }
}
```

## Testing Complex Error Scenarios

Test edge cases and complex error scenarios:

```swift
@Test("Handle mixed update scenarios")
func testMixedUpdateScenarios() async {
    // Test permission request → denied → eventual success
    let client = LocationProvider.Client.test(
        updates: [
            MockLocationUpdate.requestInProgress(),
            MockLocationUpdate.denied()
        ],
        reverseGeocodeLocation: .success("Test")
    )
    let provider = LocationProvider(client: client)

    do {
        _ = try await provider.gpsLocation()
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as GPSLocationError {
        #expect(error == .authorizationDenied)
        // Verify permission request didn't interfere with final error
        #expect(error.localizedDescription.contains("disabled for this app"))
    }
}

@Test("Handle transient errors during location acquisition")
func testTransientErrors() async throws {
    let testLocation = CLLocation.appleHQ
    let client = LocationProvider.Client.test(
        updates: [
            MockLocationUpdate.locationNotAvailable(),  // Initial failure
            MockLocationUpdate.authorized(with: testLocation)  // Eventually succeeds
        ],
        reverseGeocodeLocation: .success("Cupertino")
    )
    let provider = LocationProvider(client: client)

    // Should eventually succeed despite initial unavailability
    let location = try await provider.gpsLocation()
    #expect(location.location == testLocation)
    #expect(location.name == "Cupertino")
}
```

## Custom Mock Location Updates

Create custom mock updates for specific test scenarios:

```swift
@Test("Custom authorization flow")
func testCustomAuthorizationFlow() async throws {
    // Create custom mock that simulates permission request -> granted -> location
    let customMock = MockLocationUpdate(
        location: nil,
        authorizationRequestInProgress: true
    )

    let locationMock = MockLocationUpdate(
        location: CLLocation(latitude: 51.5074, longitude: -0.1278)  // London
    )

    let client = LocationProvider.Client.test(
        updates: [customMock, locationMock],
        reverseGeocodeLocation: .success("London")
    )
    let provider = LocationProvider(client: client)

    let location = try await provider.gpsLocation()
    #expect(location.name == "London")
}
```

## Testing Multiple Location Updates

Test scenarios where multiple location updates are provided:

```swift
@Test("Uses first valid location from multiple updates")
func testMultipleLocationUpdates() async throws {
    let firstLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)  // NYC
    let secondLocation = CLLocation(latitude: 34.0522, longitude: -118.2437)  // LA

    let client = LocationProvider.Client.test(
        updates: [
            MockLocationUpdate.authorized(with: firstLocation),
            MockLocationUpdate.authorized(with: secondLocation)
        ],
        reverseGeocodeLocation: .success("New York")
    )
    let provider = LocationProvider(client: client)

    let location = try await provider.gpsLocation()

    // Should use the first location
    #expect(location.location == firstLocation)
    #expect(location.name == "New York")
}
```

## Performance Testing

Test location request performance and timeout handling:

```swift
@Test("Location request performance")
func testLocationRequestPerformance() async throws {
    let testLocation = CLLocation.timesSquare
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.authorized(with: testLocation)],
        reverseGeocodeLocation: .success("Times Square")
    )
    let provider = LocationProvider(client: client)

    let startTime = Date()
    _ = try await provider.gpsLocation()
    let endTime = Date()

    // Location request should be fast in test environment
    let duration = endTime.timeIntervalSince(startTime)
    #expect(duration < 1.0)  // Should complete within 1 second
}
```

## Testing Migration Scenarios

Test scenarios relevant to migrating from older versions:

```swift
@Test("Error handling improvements over generic failures")
func testImprovedErrorHandling() async {
    // Before: All errors appeared as generic failures
    // After: Specific errors with actionable messages

    let scenarios: [(MockLocationUpdate, GPSLocationError, String)] = [
        (.denied(), .authorizationDenied, "Settings"),
        (.deniedGlobally(), .authorizationDeniedGlobally, "Location Services are turned off"),
        (.locationNotAvailable(), .locationUnavailable, "temporarily unavailable")
    ]

    for (mockUpdate, expectedError, expectedMessageContent) in scenarios {
        let client = LocationProvider.Client.test(
            updates: [mockUpdate],
            reverseGeocodeLocation: .success("Test")
        )
        let provider = LocationProvider(client: client)

        do {
            _ = try await provider.gpsLocation()
            #expect(Bool(false), "Should have thrown \(expectedError)")
        } catch let error as GPSLocationError {
            #expect(error == expectedError)
            #expect(error.localizedDescription.contains(expectedMessageContent))
            // Verify it's not a generic message
            #expect(!error.localizedDescription.contains("Unable to determine location"))
        }
    }
}
```

## Test Utilities and Extensions

Create reusable test utilities with improved error handling:

```swift
extension LocationProvider {
    /// Creates a LocationProvider configured for successful location testing
    static func testSuccess(
        location: CLLocation = CLLocation.appleHQ,
        name: String = "Test Location"
    ) -> LocationProvider {
        let client = Client.test(
            updates: [MockLocationUpdate.authorized(with: location)],
            reverseGeocodeLocation: .success(name)
        )
        return LocationProvider(client: client)
    }

    /// Creates a LocationProvider configured to throw a specific error with proper message validation
    static func testError(_ error: GPSLocationError) -> LocationProvider {
        let mockUpdate: MockLocationUpdate
        switch error {
        case .authorizationDenied:
            mockUpdate = .denied()
        case .authorizationDeniedGlobally:
            mockUpdate = .deniedGlobally()
        case .authorizationRestricted:
            mockUpdate = .restricted()
        case .locationUnavailable:
            mockUpdate = .locationNotAvailable()
        case .insufficientlyInUse:
            mockUpdate = .insufficientlyInUse()
        case .serviceSessionRequired:
            mockUpdate = .serviceSessionRequired()
        default:
            mockUpdate = .locationNotAvailable()
        }

        let client = Client.test(
            updates: [mockUpdate],
            reverseGeocodeLocation: .success("Test")
        )
        return LocationProvider(client: client)
    }

    /// Validates that an error has appropriate user messaging
    static func validateErrorMessage(_ error: GPSLocationError) -> Bool {
        let message = error.localizedDescription

        // Basic validation
        guard !message.isEmpty else { return false }

        // Specific validation by error type
        switch error {
        case .authorizationDenied:
            return message.contains("Settings") && message.contains("Privacy")
        case .authorizationDeniedGlobally:
            return message.contains("Location Services are turned off")
        case .locationUnavailable:
            return message.contains("temporarily") || message.contains("GPS")
        default:
            return true // Other errors have valid messages
        }
    }
}

// Use the utilities in your tests
@Test("Test utility for success case")
func testSuccessUtility() async throws {
    let provider = LocationProvider.testSuccess(
        location: CLLocation.googleHQ,
        name: "Googleplex"
    )

    let location = try await provider.gpsLocation()
    #expect(location.name == "Googleplex")
}

@Test("Test utility for error case with message validation")
func testErrorUtility() async {
    let provider = LocationProvider.testError(.authorizationDenied)

    do {
        _ = try await provider.gpsLocation()
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as GPSLocationError {
        #expect(error == .authorizationDenied)
        // Validate the error message is user-friendly
        #expect(LocationProvider.validateErrorMessage(error))
    }
}
```

## Integration Testing

Test integration with real iOS location services in a controlled way:

```swift
#if DEBUG
@Test("Integration test with simulator location", .tags(.integration))
func testSimulatorLocation() async throws {
    // This test runs against the real LocationProvider
    // but uses simulator's simulated location
    let provider = LocationProvider()

    do {
        let location = try await provider.gpsLocation()
        print("Simulator location: \(location.name ?? "GPS")")
        #expect(location.name != nil)  // Should have reverse geocoded name
    } catch let error as GPSLocationError {
        // Expected in CI/testing environments - verify error messages are helpful
        print("Location error: \(error.localizedDescription)")
        #expect(LocationProvider.validateErrorMessage(error))

        // Common expected errors in test environments
        #expect(error == .authorizationDenied ||
               error == .authorizationDeniedGlobally ||
               error == .locationUnavailable)
    } catch {
        throw error
    }
}
#endif
```

## Test Organization

Organize your location tests effectively:

```swift
@MainActor
struct LocationProviderTestSuite {
    @Test("Successful location scenarios", .tags(.success))
    func successfulLocationScenarios() async throws {
        // Test various success cases
    }

    @Test("Permission error scenarios", .tags(.permissions))
    func permissionErrorScenarios() async {
        // Test all permission-related errors
    }

    @Test("Technical error scenarios", .tags(.errors))
    func technicalErrorScenarios() async {
        // Test technical failures
    }

    @Test("SwiftUI integration scenarios", .tags(.ui))
    func swiftUIIntegrationScenarios() async {
        // Test UI integration
    }
}
```

## Next Steps

- <doc:BestPractices> - Learn optimization techniques and UX patterns
- <doc:SwiftUIIntegration> - Build robust SwiftUI location features
- <doc:ErrorHandling> - Handle all error scenarios gracefully
- <doc:HandlingPermissions> - Master permission management