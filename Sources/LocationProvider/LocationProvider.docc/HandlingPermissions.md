# Handling Permissions

Understand and manage location authorization states in your app.

## Overview

LocationProvider automatically handles location permission requests and provides specific, actionable error messages when authorization fails. This guide explains how location permissions work and how to provide a great user experience using the improved error handling that tells users exactly how to fix permission issues.

## Key Improvements in Error Handling

LocationProvider now provides specific, actionable error messages instead of generic "location not found" errors:

- **Before**: All authorization failures resulted in vague "Unable to determine location" messages
- **After**: Clear messages like "Location access is disabled for this app. You can enable it in Settings > Privacy > Location Services"

This critical improvement means users understand exactly what's wrong and how to fix it, dramatically improving the user experience when permission issues occur.

## Permission Flow

When you call `gpsLocation()`, LocationProvider manages the permission flow automatically:

1. **Check Current Status**: Determines if permissions are already granted
2. **Request If Needed**: Shows system permission dialog if required
3. **Wait for Response**: Handles user's decision
4. **Proceed or Error**: Either gets location or throws appropriate error

```swift
let locationProvider = LocationProvider()

do {
    // This may trigger permission request if needed
    let location = try await locationProvider.gpsLocation()
    print("Location received: \(location.name)")
} catch let error as GPSLocationError {
    // Now get specific, actionable error messages
    print("Location error: \(error.localizedDescription)")
    // Example: "Location access is disabled for this app. You can enable it in Settings > Privacy > Location Services."
    handleLocationError(error)
}
```

## Permission States

LocationProvider recognizes several authorization states through ``GPSLocationError``:

### Successful States

```swift
// Permission granted and location received
let location = try await locationProvider.gpsLocation()
```

### Error States

```swift
do {
    let location = try await locationProvider.gpsLocation()
} catch GPSLocationError.authorizationDenied {
    // User denied location access for this app
    showLocationPermissionAlert()
} catch GPSLocationError.authorizationDeniedGlobally {
    // Location Services disabled system-wide
    showSystemLocationServicesAlert()
} catch GPSLocationError.authorizationRestricted {
    // Location access restricted by parental controls
    showRestrictedAlert()
} catch GPSLocationError.insufficientlyInUse {
    // Need "Always" permission but only have "When In Use"
    showInsufficientPermissionAlert()
}
```

## Handling Specific Permission Scenarios

### App-Level Permission Denied

When users deny location access for your specific app:

```swift
func handleAuthorizationDenied() {
    // LocationProvider now provides the exact message to show users
    let alert = UIAlertController(
        title: "Location Access Needed",
        message: GPSLocationError.authorizationDenied.localizedDescription,
        // This will be: "Location access is disabled for this app. You can enable it in Settings > Privacy > Location Services."
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    })

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
}
```

### System-Wide Location Services Disabled

When Location Services are turned off entirely:

```swift
func handleGloballyDenied() {
    // LocationProvider automatically detects system-wide vs app-specific issues
    let alert = UIAlertController(
        title: "Location Services Disabled",
        message: GPSLocationError.authorizationDeniedGlobally.localizedDescription,
        // This will be: "Location Services are turned off. Please enable them in Settings > Privacy > Location Services."
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
}
```

### Restricted Access

When location access is restricted by device management:

```swift
func handleRestrictedAccess() {
    let alert = UIAlertController(
        title: "Location Access Restricted",
        message: "Location access is restricted by device management settings. Contact your administrator for assistance.",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
}
```

### Precise vs Approximate Location (iOS 14+)

Starting in iOS 14, users can choose between precise and approximate location for privacy. Approximate location provides ~1-20km accuracy, which is sufficient for many features like weather, timezone detection, or regional content.

```swift
// Request precise location explicitly
do {
    let location = try await locationProvider.gpsLocation(accuracyRequirement: .precise)
    // Use precise coordinates for navigation, geo-fencing, etc.
} catch GPSLocationError.preciseLocationRequired {
    // User has only granted approximate location or dismissed the upgrade prompt
    showPreciseLocationExplanation()
}

func showPreciseLocationExplanation() {
    let alert = UIAlertController(
        title: "Enable Precise Location",
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

    alert.addAction(UIAlertAction(title: "Use Approximate", style: .cancel) { _ in
        // Fall back to approximate location
        Task {
            do {
                let location = try await LocationProvider().gpsLocation(accuracyRequirement: .any)
                handleApproximateLocation(location)
            } catch {
                handleError(error)
            }
        }
    })

    present(alert, animated: true)
}
```

> **Important**: When you request `.precise` accuracy and the user has approximate location enabled, iOS shows a system prompt asking to upgrade to precise location. If the user dismisses this prompt, `CLError.promptDeclined` is automatically mapped to `GPSLocationError.preciseLocationRequired`.

> **Best Practice**: Only request `.precise` accuracy when your feature genuinely requires it:
> - **Needs Precise**: Navigation, geo-fencing, delivery tracking, location sharing, fitness tracking
> - **Works with Approximate**: Weather, timezone detection, regional content, city-level features, nearby search
>
> Using `.any` (the default) accepts approximate location and respects user privacy preferences.

## SwiftUI Permission Handling

Here's how to handle permissions in SwiftUI:

```swift
struct LocationPermissionView: View {
    @State private var location: GPSLocation?
    @State private var permissionError: GPSLocationError?
    @State private var showingPermissionAlert = false

    private let locationProvider = LocationProvider()

    var body: some View {
        VStack(spacing: 20) {
            if let location = location {
                LocationDisplayView(location: location)
            } else {
                Button("Get Location") {
                    Task {
                        await requestLocation()
                    }
                }
            }
        }
        .alert("Location Permission", isPresented: $showingPermissionAlert) {
            switch permissionError {
            case .authorizationDenied:
                Button("Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) {}
            case .authorizationDeniedGlobally:
                Button("OK") {}
            default:
                Button("OK") {}
            }
        } message: {
            // LocationProvider provides clear, actionable error messages
            Text(permissionError?.localizedDescription ?? "")
            // Examples:
            // "Location access is disabled for this app. You can enable it in Settings > Privacy > Location Services."
            // "Location Services are turned off. Please enable them in Settings > Privacy > Location Services."
        }
    }

    private func requestLocation() async {
        do {
            location = try await locationProvider.gpsLocation()
        } catch let error as GPSLocationError {
            permissionError = error
            showingPermissionAlert = true
        } catch {
            // Handle other errors
            print("Unexpected error: \(error)")
        }
    }

    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
```

## Migration from Previous Versions

If you're updating from an earlier version of LocationProvider, you'll benefit from these improvements automatically:

### Before (Generic Errors)
```swift
// Old behavior: All permission errors were generic
catch {
    print("Unable to determine location")  // Not helpful to users
}
```

### After (Specific Errors)
```swift
// New behavior: Specific, actionable error messages
catch let error as GPSLocationError {
    print(error.localizedDescription)
    // "Location access is disabled for this app. You can enable it in Settings > Privacy > Location Services."
}
```

### Simplified Error Handling

You can now use the error messages directly without crafting your own:

```swift
func showLocationError(_ error: GPSLocationError) {
    // Just use the provided error message - it's now user-friendly and actionable
    let alert = UIAlertController(
        title: "Location Error",
        message: error.localizedDescription,
        preferredStyle: .alert
    )

    // Add appropriate actions based on error type
    switch error {
    case .authorizationDenied, .authorizationDeniedGlobally:
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            openAppSettings()
        })
    default:
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
            Task { await requestLocation() }
        })
    }

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
}
```

## Best Practices for Permission Requests

### 1. Provide Context Before Requesting

Explain why your app needs location access before the system dialog appears:

```swift
struct ContextualLocationRequest: View {
    @State private var showingExplanation = true
    @State private var location: GPSLocation?

    var body: some View {
        if showingExplanation {
            VStack(spacing: 16) {
                Image(systemName: "location.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)

                Text("Find Nearby Places")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("We'll use your location to show nearby restaurants, shops, and points of interest.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Button("Enable Location") {
                    Task {
                        await requestLocationWithContext()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else {
            // Show location-based content
            LocationContentView(location: location)
        }
    }

    private func requestLocationWithContext() async {
        do {
            location = try await LocationProvider().gpsLocation()
            showingExplanation = false
        } catch {
            // Handle appropriately
        }
    }
}
```

### 2. Graceful Degradation

Provide alternative functionality when location isn't available:

```swift
struct LocationAwareView: View {
    @State private var location: GPSLocation?
    @State private var useManualLocation = false

    var body: some View {
        VStack {
            if let location = location {
                Text("Current location: \(location.name)")
            } else if useManualLocation {
                LocationPicker { selectedLocation in
                    // Handle manual location selection
                }
            } else {
                Button("Use Current Location") {
                    Task { await tryLocationRequest() }
                }

                Button("Choose Location Manually") {
                    useManualLocation = true
                }
            }
        }
    }

    private func tryLocationRequest() async {
        do {
            location = try await LocationProvider().gpsLocation()
        } catch {
            // Fallback to manual selection
            useManualLocation = true
        }
    }
}
```

### 3. Retry Mechanisms

Allow users to retry location requests after fixing permission issues:

```swift
@Observable
class LocationManager {
    var location: GPSLocation?
    var lastError: GPSLocationError?
    var isLoading = false

    private let locationProvider = LocationProvider()

    func requestLocation() async {
        isLoading = true
        defer { isLoading = false }

        do {
            location = try await locationProvider.gpsLocation()
            lastError = nil
        } catch let error as GPSLocationError {
            lastError = error
        }
    }

    var canRetry: Bool {
        guard let error = lastError else { return false }

        switch error {
        case .authorizationDenied, .authorizationDeniedGlobally:
            return true // User might have changed settings
        case .locationUnavailable, .notFound:
            return true // Might be temporary
        case .authorizationRestricted:
            return false // Can't be changed by user
        default:
            return true
        }
    }
}
```

## Testing Permission Scenarios

Test different permission states using mock clients:

```swift
// Test permission denied
let deniedClient = LocationProvider.Client.test(
    updates: [MockLocationUpdate.denied()],
    reverseGeocodeLocation: .success("Test")
)

// Test globally denied
let globallyDeniedClient = LocationProvider.Client.test(
    updates: [MockLocationUpdate.deniedGlobally()],
    reverseGeocodeLocation: .success("Test")
)

// Test permission request flow
let permissionFlowClient = LocationProvider.Client.test(
    updates: [
        MockLocationUpdate.requestInProgress(),
        MockLocationUpdate.authorized(with: CLLocation.appleHQ)
    ],
    reverseGeocodeLocation: .success("Cupertino")
)
```

## Next Steps

- <doc:ErrorHandling> - Handle all types of location errors
- <doc:SwiftUIIntegration> - Advanced SwiftUI integration patterns
- <doc:Testing> - Test permission scenarios thoroughly
- <doc:BestPractices> - Optimize user experience and battery life