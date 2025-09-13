# Error Handling

Respond gracefully to location errors and provide excellent user experiences.

## Overview

LocationProvider provides comprehensive error handling through the ``GPSLocationError`` enum. Each error type represents a specific scenario with clear, user-friendly descriptions. This guide shows you how to handle these errors effectively and provide appropriate fallbacks.

## Error Types

LocationProvider defines specific error cases that cover all possible location service issues:

```swift
public enum GPSLocationError: LocalizedError {
    case authorizationRestricted    // Parental controls/device management
    case notFound                  // Cannot determine position
    case authorizationDenied       // User denied app permission
    case authorizationDeniedGlobally // Location Services disabled
    case insufficientlyInUse       // Need "Always" but have "When In Use"
    case locationUnavailable       // GPS temporarily unavailable
    case serviceSessionRequired    // Find My session needed
    case reverseGeocoding         // Address lookup failed
}
```

## Basic Error Handling Pattern

Use Swift's error handling to catch and respond to specific error types:

```swift
import LocationProvider

func getCurrentLocation() async {
    do {
        let location = try await LocationProvider().gpsLocation()
        handleLocationSuccess(location)
    } catch let error as GPSLocationError {
        handleLocationError(error)
    } catch {
        handleUnexpectedError(error)
    }
}

func handleLocationError(_ error: GPSLocationError) {
    switch error {
    case .authorizationDenied:
        showPermissionRequiredAlert()
    case .authorizationDeniedGlobally:
        showLocationServicesDisabledAlert()
    case .locationUnavailable:
        showLocationUnavailableMessage()
    case .notFound:
        showLocationNotFoundMessage()
    default:
        showGenericLocationError(error)
    }
}
```

## Permission-Related Errors

### Authorization Denied

User has specifically denied location access for your app:

```swift
func handleAuthorizationDenied() {
    // Show actionable guidance
    let alert = UIAlertController(
        title: "Location Permission Required",
        message: "To show your current location, enable location access in Settings > Privacy & Security > Location Services > YourApp.",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    })

    alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
    present(alert, animated: true)
}
```

### Authorization Denied Globally

Location Services are turned off system-wide:

```swift
func handleGlobalLocationServicesDisabled() {
    let alert = UIAlertController(
        title: "Location Services Disabled",
        message: "Location Services are turned off. Enable them in Settings > Privacy & Security > Location Services to use location features.",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
}
```

### Authorization Restricted

Location access is restricted by device management:

```swift
func handleRestrictedAccess() {
    let alert = UIAlertController(
        title: "Location Access Restricted",
        message: "Location access is restricted on this device. Contact your device administrator for assistance.",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
}
```

## Technical Errors

### Location Not Found

GPS cannot determine the device's position:

```swift
func handleLocationNotFound() {
    // Provide retry option and guidance
    let alert = UIAlertController(
        title: "Location Not Found",
        message: "Unable to determine your location. Make sure you're not in airplane mode and have a clear view of the sky.",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
        Task { await getCurrentLocation() }
    })

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
}
```

### Location Unavailable

Location services are temporarily unavailable:

```swift
func handleLocationUnavailable() {
    // Show temporary message with retry option
    showMessage(
        "Location temporarily unavailable. This may be due to poor GPS signal or airplane mode being enabled.",
        withRetry: true
    )
}
```

### Reverse Geocoding Failure

Address lookup failed but location coordinates are still available:

```swift
do {
    let location = try await LocationProvider().gpsLocation()
    // Success - location.name will be "GPS" if reverse geocoding failed
    print("Location: \(location.name)")
} catch GPSLocationError.reverseGeocoding {
    // This actually won't be thrown - reverse geocoding failures
    // result in location.name defaulting to "GPS"
    print("Got coordinates but couldn't determine address")
} catch {
    // Handle other errors
}
```

> Note: LocationProvider gracefully handles reverse geocoding failures by setting the location name to "GPS" rather than throwing an error. The location coordinates are still available.

## SwiftUI Error Handling

Handle errors elegantly in SwiftUI with proper state management:

```swift
struct LocationErrorHandlingView: View {
    @State private var location: GPSLocation?
    @State private var errorState: ErrorState?
    @State private var isLoading = false

    enum ErrorState {
        case permissionDenied
        case servicesDisabled
        case locationUnavailable
        case notFound
        case other(String)

        var title: String {
            switch self {
            case .permissionDenied: return "Permission Required"
            case .servicesDisabled: return "Location Services Disabled"
            case .locationUnavailable: return "Location Unavailable"
            case .notFound: return "Location Not Found"
            case .other: return "Error"
            }
        }

        var message: String {
            switch self {
            case .permissionDenied:
                return "Enable location access in Settings to use this feature."
            case .servicesDisabled:
                return "Turn on Location Services in Settings > Privacy & Security."
            case .locationUnavailable:
                return "Location is temporarily unavailable. Check your connection and try again."
            case .notFound:
                return "Unable to determine your location. Make sure GPS is available."
            case .other(let message):
                return message
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            if let location = location {
                LocationDisplayView(location: location)
            } else if isLoading {
                ProgressView("Finding location...")
            } else if let errorState = errorState {
                ErrorView(errorState: errorState) {
                    await requestLocation()
                }
            } else {
                Button("Get Location") {
                    Task { await requestLocation() }
                }
            }
        }
        .padding()
    }

    private func requestLocation() async {
        isLoading = true
        errorState = nil
        defer { isLoading = false }

        do {
            location = try await LocationProvider().gpsLocation()
        } catch let error as GPSLocationError {
            errorState = mapErrorToState(error)
        } catch {
            errorState = .other(error.localizedDescription)
        }
    }

    private func mapErrorToState(_ error: GPSLocationError) -> ErrorState {
        switch error {
        case .authorizationDenied:
            return .permissionDenied
        case .authorizationDeniedGlobally:
            return .servicesDisabled
        case .locationUnavailable:
            return .locationUnavailable
        case .notFound:
            return .notFound
        default:
            return .other(error.localizedDescription)
        }
    }
}

struct ErrorView: View {
    let errorState: LocationErrorHandlingView.ErrorState
    let retryAction: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(errorState.title)
                .font(.headline)

            Text(errorState.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                if errorState == .permissionDenied {
                    Button("Open Settings") {
                        openAppSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Try Again") {
                    Task { await retryAction() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
```

## Robust Error Recovery

Implement sophisticated retry logic with backoff strategies:

```swift
import Observation

@MainActor
@Observable
class RobustLocationManager {
    var location: GPSLocation?
    var error: GPSLocationError?
    var isLoading = false

    private let locationProvider = LocationProvider()
    private var retryCount = 0
    private let maxRetries = 3

    func requestLocation() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        retryCount = 0

        await performLocationRequest()
    }

    private func performLocationRequest() async {
        do {
            location = try await locationProvider.gpsLocation()
            retryCount = 0
            isLoading = false
        } catch let locationError as GPSLocationError {
            await handleLocationError(locationError)
        } catch {
            self.error = .notFound
            isLoading = false
        }
    }

    private func handleLocationError(_ locationError: GPSLocationError) async {
        switch locationError {
        case .locationUnavailable, .notFound:
            // Retry these errors
            if retryCount < maxRetries {
                retryCount += 1
                let delay = Double(retryCount * retryCount) // Exponential backoff
                try? await Task.sleep(for: .seconds(delay))
                await performLocationRequest()
            } else {
                error = locationError
                isLoading = false
            }

        case .authorizationDenied, .authorizationDeniedGlobally, .authorizationRestricted:
            // Don't retry permission errors
            error = locationError
            isLoading = false

        default:
            error = locationError
            isLoading = false
        }
    }

    func reset() {
        location = nil
        error = nil
        retryCount = 0
        isLoading = false
    }
}
```

## Error Logging and Analytics

Track location errors for debugging and analytics:

```swift
import os.log

private let logger = Logger(subsystem: "com.yourapp.location", category: "LocationErrors")

func trackLocationError(_ error: GPSLocationError, context: String) {
    // Log for debugging
    logger.error("Location error in \(context): \(error.localizedDescription)")

    // Send to analytics (if applicable)
    #if DEBUG
    print("📍 Location Error: \(error) in \(context)")
    #endif

    // Track error frequency
    UserDefaults.standard.increment(key: "location_error_\(error)")
}

extension UserDefaults {
    func increment(key: String) {
        let current = integer(forKey: key)
        set(current + 1, forKey: key)
    }
}
```

## Testing Error Scenarios

Use mock clients to test all error scenarios:

```swift
@Test("Handle authorization denied error")
func testAuthorizationDeniedError() async {
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.denied()],
        reverseGeocodeLocation: .success("Test")
    )
    let provider = LocationProvider(client: client)

    await #expect(throws: GPSLocationError.authorizationDenied) {
        _ = try await provider.gpsLocation()
    }
}

@Test("Handle location unavailable error")
func testLocationUnavailableError() async {
    let client = LocationProvider.Client.test(
        updates: [MockLocationUpdate.locationNotAvailable()],
        reverseGeocodeLocation: .success("Test")
    )
    let provider = LocationProvider(client: client)

    await #expect(throws: GPSLocationError.locationUnavailable) {
        _ = try await provider.gpsLocation()
    }
}
```

## Next Steps

- <doc:SwiftUIIntegration> - Advanced SwiftUI integration patterns
- <doc:Testing> - Comprehensive testing strategies
- <doc:BestPractices> - Optimize user experience and performance
- <doc:HandlingPermissions> - Deep dive into permission management