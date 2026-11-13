# Handling Permissions

Understand and manage location authorization states in your app.

## Overview

LocationProvider requests location permission when needed and reports a refusal as a ``GPSLocationError``. This guide explains how location permissions work and how to build your permission UI from the error's message and ``GPSLocationError/recovery``.

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
} catch {
    print("Location error: \(error.localizedDescription)")
    handleLocationError(error)
}
```

## Permission States

### Successful States

```swift
// Permission granted and location received
let location = try await locationProvider.gpsLocation()
```

### Error States

A permission refusal surfaces as ``GPSLocationError/authorizationDenied``, ``GPSLocationError/authorizationRestricted``, or ``GPSLocationError/preciseLocationRequired``. You rarely need to tell them apart: each error's ``GPSLocationError/recovery`` says whether a setting the user controls can fix it (``GPSLocationError/Recovery/openSettings``) or nothing the user can change will (``GPSLocationError/Recovery/none``). See <doc:ErrorHandling#Choosing-a-Recovery>.

```swift
func showPermissionAlert(for error: GPSLocationError) {
    let alert = UIAlertController(
        title: "Location Unavailable",
        message: error.localizedDescription,
        preferredStyle: .alert
    )

    if error.recovery == .openSettings {
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            Task { await openLocationSettings() }
        })
    }

    alert.addAction(UIAlertAction(title: "OK", style: .cancel))
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
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
        Task { await openLocationSettings() }
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

> **Important**: When you request `.precise` accuracy and the user has approximate location enabled, iOS shows a system prompt asking to upgrade to precise location. If the user dismisses this prompt, the request throws ``GPSLocationError/preciseLocationRequired``.

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
            if permissionError?.recovery == .openSettings {
                Button("Settings") {
                    Task { await openLocationSettings() }
                }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK") {}
            }
        } message: {
            Text(permissionError?.localizedDescription ?? "")
        }
    }

    private func requestLocation() async {
        do {
            location = try await locationProvider.gpsLocation()
        } catch {
            permissionError = error
            showingPermissionAlert = true
        }
    }
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

Ask again when the cause may have cleared: on the user's request for ``GPSLocationError/Recovery/retry``, and when the app returns to the foreground for ``GPSLocationError/Recovery/openSettings``, since the user may have changed the setting.

```swift
@MainActor
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
        } catch {
            lastError = error
        }
    }

    /// Shows a Try Again button.
    var canRetry: Bool {
        lastError?.recovery == .retry
    }

    /// Call when the scene becomes active, in case the user fixed the setting.
    func sceneDidBecomeActive() async {
        if lastError?.recovery == .openSettings {
            await requestLocation()
        }
    }
}
```

## Testing Permission Scenarios

Permission outcomes reach your code as ``GPSLocationError/authorizationDenied``, ``GPSLocationError/authorizationRestricted``, and ``GPSLocationError/preciseLocationRequired``. Have a mock provider throw each one to test your UI's response. See <doc:Testing>.

## Next Steps

- <doc:ErrorHandling> - Handle all types of location errors
- <doc:SwiftUIIntegration> - Advanced SwiftUI integration patterns
- <doc:Testing> - Test permission scenarios thoroughly
- <doc:BestPractices> - Optimize user experience and battery life