# Error Handling

Respond gracefully to location errors and provide excellent user experiences.

## Overview

LocationProvider provides comprehensive error handling through the ``GPSLocationError`` enum with significant improvements in error propagation and user messaging. The framework now uses `AsyncThrowingStream` to properly surface Core Location errors with specific, actionable messages instead of generic failures. This guide shows you how to handle these errors effectively and provide appropriate fallbacks.

## Critical Error Handling Improvements

LocationProvider has undergone significant improvements to error handling:

### Before: Hidden Authorization Errors
- Authorization failures were swallowed and appeared as generic "Unable to determine location" errors
- Users had no way to understand they needed to fix permissions
- CLError.denied was not properly surfaced to applications

### After: Specific, Actionable Error Messages
- `Client.updates()` now returns `AsyncThrowingStream<LocationUpdate, Error>` instead of `AsyncStream`
- CLError types are mapped to specific GPSLocationError cases with clear user guidance
- Authorization errors surface immediately with instructions on how to fix them
- CancellationError is filtered out (not surfaced to users as it's expected behavior)

### Error Mapping Examples
- `CLError.denied` → `GPSLocationError.authorizationDenied` → "Location access is disabled for this app. You can enable it in Settings > Privacy > Location Services."
- `CLError.locationUnknown` → `GPSLocationError.locationUnavailable` → "Location services are temporarily unavailable. This might be due to no GPS signal or airplane mode being enabled."
- `CancellationError` → Filtered out (not surfaced to users)

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
}
```

> **Important**: Each error now provides specific, user-friendly messages through `localizedDescription`. These messages tell users exactly what's wrong and how to fix it, eliminating the need for generic error handling.

## Basic Error Handling Pattern

LocationProvider now surfaces errors immediately with specific, actionable messages:

```swift
import LocationProvider

func getCurrentLocation() async {
    do {
        let location = try await LocationProvider().gpsLocation()
        handleLocationSuccess(location)
    } catch let error as GPSLocationError {
        // Error messages are now specific and actionable
        print("Location error: \(error.localizedDescription)")
        // Example output: "Location access is disabled for this app. You can enable it in Settings > Privacy > Location Services."
        handleLocationError(error)
    } catch {
        // Unexpected errors (should be rare with improved error mapping)
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

User has specifically denied location access for your app. LocationProvider now detects this immediately and provides clear guidance:

> **Key Improvement**: Previously, authorization failures appeared as generic "location not found" errors. Now they surface immediately with specific instructions.

```swift
func handleAuthorizationDenied() {
    // LocationProvider provides the exact message to display
    let alert = UIAlertController(
        title: "Location Permission Required",
        message: GPSLocationError.authorizationDenied.localizedDescription,
        // Will be: "Location access is disabled for this app. You can enable it in Settings > Privacy > Location Services."
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

Location Services are turned off system-wide. LocationProvider automatically distinguishes between app-specific and system-wide permission issues:

```swift
func handleGlobalLocationServicesDisabled() {
    // LocationProvider automatically detects system-wide vs app-specific denial
    let alert = UIAlertController(
        title: "Location Services Disabled",
        message: GPSLocationError.authorizationDeniedGlobally.localizedDescription,
        // Will be: "Location Services are turned off. Please enable them in Settings > Privacy > Location Services."
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

GPS cannot determine the device's position. This is now distinguished from authorization errors:

> **Improvement**: Previously, authorization denials and technical failures both appeared as "location not found". Now they're clearly separated.

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

Location services are temporarily unavailable. Multiple CLError types are intelligently mapped to this category:

```swift
func handleLocationUnavailable() {
    // LocationProvider maps multiple CLError types to this category:
    // CLError.locationUnknown, .network, .deferredAccuracyTooLow, etc.
    showMessage(
        GPSLocationError.locationUnavailable.localizedDescription,
        // Will be: "Location services are temporarily unavailable. This might be due to no GPS signal or airplane mode being enabled."
        withRetry: true
    )
}
```

### Reverse Geocoding Behavior

LocationProvider gracefully handles reverse geocoding failures without throwing errors:

```swift
do {
    let location = try await LocationProvider().gpsLocation()
    // location.name defaults to "GPS" if reverse geocoding failed
    if location.name == "GPS" {
        print("Location coordinates available but address lookup failed")
        print("Coordinates: \(location.location.coordinate)")
    } else {
        print("Location: \(location.name)")
    }
} catch {
    // Handle location acquisition errors
    print("Location error: \(error.localizedDescription)")
}
```

> **Note**: LocationProvider gracefully handles reverse geocoding failures by setting the location name to `"GPS"` rather than throwing an error. The location coordinates are still available, ensuring users always get their location even if address lookup fails.

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