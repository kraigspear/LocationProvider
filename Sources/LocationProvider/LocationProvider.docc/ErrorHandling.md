# Error Handling

Respond gracefully to location errors and provide excellent user experiences.

## Overview

LocationProvider provides comprehensive error handling through the ``GPSLocationError`` enum with significant improvements in error propagation and user messaging. The framework surfaces Core Location errors with specific, actionable messages instead of generic failures. This guide shows you how to handle these errors effectively and provide appropriate fallbacks.

## Critical Error Handling Improvements

LocationProvider has undergone significant improvements to error handling:

### Before: Hidden Authorization Errors
- Authorization failures were swallowed and appeared as generic "Unable to determine location" errors
- Users had no way to understand they needed to fix permissions
- CLError.denied was not properly surfaced to applications

### After: Specific, Actionable Error Messages
- Errors thrown by Core Location's live updates propagate instead of being swallowed
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
    case authorizationDenied       // Location access denied (app or system-wide)
    case insufficientlyInUse       // Need "Always" but have "When In Use"
    case locationUnavailable       // GPS temporarily unavailable
    case serviceSessionRequired    // App requires a CLServiceSession but holds none
    case preciseLocationRequired   // User has approximate location but precise is needed
}
```

> **Important**: Each error provides a user-facing message through `localizedDescription`. When the user can fix the problem, the message says how; when only the app can, it names no fix. ``GPSLocationError/recovery`` tells your UI which action to offer.

## Choosing a Recovery

Each error's ``GPSLocationError/recovery`` names what the user can do about it, so every screen offers the same remedy for the same cause:

- ``GPSLocationError/Recovery/retry``: `notFound` and `locationUnavailable`. The cause may clear on its own, so offer to try again.
- ``GPSLocationError/Recovery/openSettings``: `authorizationDenied`, `insufficientlyInUse`, and `preciseLocationRequired`. A setting the user controls blocks the location, so offer ``openLocationSettings()``.
- ``GPSLocationError/Recovery/none``: `authorizationRestricted` and `serviceSessionRequired`. Neither retrying nor Settings helps, so show the message alone.

```swift
switch error.recovery {
case .retry:
    Button("Try Again") { Task { await requestLocation() } }
case .openSettings:
    Button("Open Settings") { Task { await openLocationSettings() } }
case .none:
    EmptyView()
}
```

## Precision-Related Errors

### Precise Location Required

iOS 14+ allows users to grant only approximate location access (~1-20km accuracy) for privacy. This error occurs in two scenarios:

1. User has granted approximate location and dismisses the iOS "Precise Location" upgrade prompt
2. App explicitly requests precise location but user has only granted approximate access

```swift
func handlePreciseLocationRequired() {
    // User dismissed the precise location prompt or has only approximate location enabled
    let alert = UIAlertController(
        title: "Precise Location Needed",
        message: GPSLocationError.preciseLocationRequired.localizedDescription,
        // Will be: "Precise location is required but only approximate location is available.
        // Enable Precise Location in Settings > Privacy & Security > Location Services >
        // [App Name] to share your exact location."
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    })

    alert.addAction(UIAlertAction(title: "Use Approximate Location", style: .cancel) { _ in
        // Optionally fall back to .any accuracy requirement
        Task {
            do {
                let location = try await LocationProvider().gpsLocation(accuracyRequirement: .any)
                handleLocationSuccess(location)
            } catch {
                handleLocationError(error)
            }
        }
    })

    present(alert, animated: true)
}
```

> **Note**: When requesting precise location with `gpsLocation(accuracyRequirement: .precise)`, iOS may show a system prompt asking users to upgrade from approximate to precise location. If users dismiss this prompt, `CLError.promptDeclined` is thrown and automatically mapped to `GPSLocationError.preciseLocationRequired`.

> **Best Practice**: Only request `.precise` accuracy when your feature genuinely requires it (navigation, geo-fencing, delivery tracking). Many features work fine with `.any` (the default), which accepts approximate location and respects user privacy.

## Basic Error Handling Pattern

LocationProvider now surfaces errors immediately with specific, actionable messages:

```swift
import LocationProvider

func getCurrentLocation() async {
    do {
        let location = try await LocationProvider().gpsLocation()
        handleLocationSuccess(location)
    } catch {
        // Error messages are now specific and actionable
        print("Location error: \(error.localizedDescription)")
        // Example output: "Location access is disabled for this app. You can enable it in Settings > Privacy > Location Services."
        handleLocationError(error)
    }
}

func handleLocationError(_ error: GPSLocationError) {
    switch error {
    case .authorizationDenied:
        showPermissionRequiredAlert()
    case .locationUnavailable:
        showLocationUnavailableMessage()
    case .notFound:
        showLocationNotFoundMessage()
    default:
        showGenericLocationError(error)
    }
}
```

``LocationProvider/LocationProvider/gpsLocation(accuracyRequirement:)`` throws only ``GPSLocationError``, so `catch` binds it without a cast. A request cancelled while waiting for a fix fails as a timeout would; once a fix arrives, it returns that location even if cancelled during reverse geocoding. Inside a closure, such as a SwiftUI `.task`, write `do throws(GPSLocationError)`: Swift infers a closure's thrown type only with full typed throws enabled, so a plain `catch` there binds `any Error`.

## Permission-Related Errors

### Authorization Denied

User has denied location access for your app, or Location Services are disabled system-wide. LocationProvider detects this immediately and provides clear guidance:

> **Key Improvement**: Previously, authorization failures appeared as generic "location not found" errors. Now they surface immediately with specific instructions.

```swift
func handleAuthorizationDenied() {
    // LocationProvider provides the exact message to display
    let alert = UIAlertController(
        title: "Location Permission Required",
        message: GPSLocationError.authorizationDenied.localizedDescription,
        // Will be: "Location access is not available. Enable location in Settings > Privacy & Security > Location Services."
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
    @State private var recovery = GPSLocationError.Recovery.retry
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
                ErrorView(errorState: errorState, recovery: recovery) {
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
        } catch {
            errorState = mapErrorToState(error)
            recovery = error.recovery
        }
    }

    private func mapErrorToState(_ error: GPSLocationError) -> ErrorState {
        switch error {
        case .authorizationDenied:
            return .permissionDenied
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
    let recovery: GPSLocationError.Recovery
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

            switch recovery {
            case .openSettings:
                Button("Open Settings") {
                    Task { await openLocationSettings() }
                }
                .buttonStyle(.borderedProminent)
            case .retry:
                Button("Try Again") {
                    Task { await retryAction() }
                }
                .buttonStyle(.bordered)
            case .none:
                EmptyView()
            }
        }
        .padding()
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
        } catch {
            await handleLocationError(error)
        }
    }

    private func handleLocationError(_ locationError: GPSLocationError) async {
        switch locationError.recovery {
        case .retry:
            if retryCount < maxRetries {
                retryCount += 1
                let delay = Double(retryCount * retryCount) // Exponential backoff
                try? await Task.sleep(for: .seconds(delay))
                await performLocationRequest()
            } else {
                error = locationError
                isLoading = false
            }

        case .openSettings, .none:
            // Asking again can't succeed until the user or device changes something
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

To test how your code handles each ``GPSLocationError``, put `LocationProvider` behind a protocol and have a mock throw the error under test. See <doc:Testing>.

## Next Steps

- <doc:SwiftUIIntegration> - Advanced SwiftUI integration patterns
- <doc:Testing> - Comprehensive testing strategies
- <doc:BestPractices> - Optimize user experience and performance
- <doc:HandlingPermissions> - Deep dive into permission management