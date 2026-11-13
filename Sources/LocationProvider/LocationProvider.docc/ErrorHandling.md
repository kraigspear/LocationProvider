# Error Handling

Respond gracefully to location errors and provide excellent user experiences.

## Overview

LocationProvider reports every failure as a ``GPSLocationError``. Each error carries a user-facing message in `localizedDescription` and a ``GPSLocationError/recovery`` that names what the user can do. This guide shows how to build your error UI from those two properties.

## Error Types

LocationProvider defines specific error cases that cover all possible location service issues:

```swift
public enum GPSLocationError: LocalizedError {
    case authorizationRestricted    // Parental controls/device management
    case notFound                  // No location before timeout or end of updates
    case authorizationDenied       // Location access denied (app or system-wide)
    case insufficientlyInUse       // Updates suspended while the app wasn't in use
    case locationUnavailable       // Core Location couldn't determine a location
    case serviceSessionRequired    // App requires a CLServiceSession but holds none
    case preciseLocationRequired   // User has approximate location but precise is needed
}
```

> **Important**: Each error provides a user-facing message through `localizedDescription`. When the user can fix the problem, the message says how; when only the app can, it names no fix. ``GPSLocationError/recovery`` tells your UI which action to offer.

## Choosing a Recovery

Each error's ``GPSLocationError/recovery`` names what the user can do about it, so every screen offers the same remedy for the same cause:

- ``GPSLocationError/Recovery/retry``: `notFound`, `locationUnavailable`, and `insufficientlyInUse`. The cause may clear on its own, or once the app is in use again, so offer to try again.
- ``GPSLocationError/Recovery/openSettings``: `authorizationDenied` and `preciseLocationRequired`. A setting the user controls blocks the location, so offer ``openLocationSettings()``.
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
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
        Task { await openLocationSettings() }
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

> **Note**: When requesting precise location with `gpsLocation(accuracyRequirement: .precise)`, iOS may show a system prompt asking users to upgrade from approximate to precise location. If users dismiss this prompt, the request throws ``GPSLocationError/preciseLocationRequired``.

> **Best Practice**: Only request `.precise` accuracy when your feature genuinely requires it (navigation, geo-fencing, delivery tracking). Many features work fine with `.any` (the default), which accepts approximate location and respects user privacy.

## Basic Error Handling Pattern

Show the error's message, and let its recovery pick the action:

```swift
import LocationProvider

func getCurrentLocation() async {
    do {
        let location = try await LocationProvider().gpsLocation()
        handleLocationSuccess(location)
    } catch {
        handleLocationError(error)
    }
}

func handleLocationError(_ error: GPSLocationError) {
    switch error.recovery {
    case .retry:
        showRetryAlert(message: error.localizedDescription)
    case .openSettings:
        showSettingsAlert(message: error.localizedDescription)
    case .none:
        showMessage(error.localizedDescription)
    }
}
```

``LocationProvider/LocationProvider/gpsLocation(accuracyRequirement:)`` throws only ``GPSLocationError``, so `catch` binds it without a cast. A request cancelled while waiting for a fix fails as a timeout would; once a fix arrives, it returns that location even if cancelled during reverse geocoding. Inside a closure, such as a SwiftUI `.task`, write `do throws(GPSLocationError)`: Swift infers a closure's thrown type only with full typed throws enabled, so a plain `catch` there binds `any Error`.

## Reverse Geocoding Behavior

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
    @State private var locationError: GPSLocationError?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            if let location = location {
                LocationDisplayView(location: location)
            } else if isLoading {
                ProgressView("Finding location...")
            } else if let locationError = locationError {
                ErrorView(error: locationError) {
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
        locationError = nil
        defer { isLoading = false }

        do {
            location = try await LocationProvider().gpsLocation()
        } catch {
            locationError = error
        }
    }
}

struct ErrorView: View {
    let error: GPSLocationError
    let retryAction: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            switch error.recovery {
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