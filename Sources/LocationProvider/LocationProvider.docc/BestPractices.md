# Best Practices

Optimize performance, battery life, and user experience when using LocationProvider.

## Overview

LocationProvider is designed to be efficient and user-friendly, but following best practices ensures optimal performance, battery life, and user experience. This guide covers performance optimization, battery conservation, user experience patterns, and architectural recommendations.

## Performance Optimization

### Efficient Location Requests

LocationProvider automatically stops location services after getting a result, but you can optimize further:

```swift
import Observation

@MainActor
@Observable
class PerformantLocationManager {
    var location: GPSLocation?
    private var lastLocationTime: Date?
    private let locationProvider = LocationProvider()

    // Cache location for 5 minutes to avoid unnecessary requests
    private let cacheTimeout: TimeInterval = 300

    func getLocation() async -> GPSLocation? {
        // Return cached location if still fresh
        if let lastTime = lastLocationTime,
           Date().timeIntervalSince(lastTime) < cacheTimeout,
           let location = location {
            return location
        }

        do {
            let newLocation = try await locationProvider.gpsLocation()
            location = newLocation
            lastLocationTime = Date()
            return newLocation
        } catch {
            return nil
        }
    }
}
```

### Avoid Redundant Requests

Prevent multiple simultaneous location requests:

```swift
import Observation

@MainActor
@Observable
class SingleRequestLocationManager {
    var location: GPSLocation?
    var isLoading = false

    private let locationProvider = LocationProvider()
    private var currentTask: Task<GPSLocation?, Never>?

    func requestLocation() async -> GPSLocation? {
        // Cancel existing request if any
        currentTask?.cancel()

        // Return existing result if loading
        if let task = currentTask {
            return await task.value
        }

        // Create new request
        currentTask = Task {
            isLoading = true
            defer {
                isLoading = false
                currentTask = nil
            }

            do {
                let location = try await locationProvider.gpsLocation()
                self.location = location
                return location
            } catch {
                return nil
            }
        }

        return await currentTask!.value
    }
}
```

### Memory Efficient Location Storage

Store location data efficiently:

```swift
struct LocationCache {
    private var locations: [String: CachedLocation] = [:]
    private let maxCacheSize = 100

    struct CachedLocation {
        let location: GPSLocation
        let timestamp: Date
        let accessCount: Int

        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
    }

    mutating func store(_ location: GPSLocation, forKey key: String) {
        // Remove oldest entries if cache is full
        if locations.count >= maxCacheSize {
            let oldestKey = locations.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let key = oldestKey {
                locations.removeValue(forKey: key)
            }
        }

        locations[key] = CachedLocation(
            location: location,
            timestamp: Date(),
            accessCount: 0
        )
    }

    func retrieve(key: String, maxAge: TimeInterval = 300) -> GPSLocation? {
        guard let cached = locations[key],
              cached.age < maxAge else {
            return nil
        }

        return cached.location
    }
}
```

## Battery Life Optimization

### Request Location Only When Needed

Don't request location on app launch unless required:

```swift
struct ContentView: View {
    @State private var location: GPSLocation?
    @State private var needsLocation = false

    var body: some View {
        VStack {
            if needsLocation {
                LocationRequiredView(location: $location)
            } else {
                LocationOptionalView {
                    needsLocation = true
                }
            }
        }
    }
}

struct LocationRequiredView: View {
    @Binding var location: GPSLocation?
    private let locationProvider = LocationProvider()

    var body: some View {
        // Only request location when this view appears
        Text("Location-based content")
            .task {
                if location == nil {
                    location = try? await locationProvider.gpsLocation()
                }
            }
    }
}
```

### Smart Location Updates

Implement intelligent location refresh based on user activity:

```swift
import Observation

@MainActor
@Observable
class SmartLocationManager {
    var location: GPSLocation?
    private let locationProvider = LocationProvider()
    private var lastUpdate: Date?

    // Adjust update frequency based on context
    func shouldUpdateLocation(userActivity: UserActivity) -> Bool {
        guard let lastUpdate = lastUpdate else { return true }

        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)

        switch userActivity {
        case .navigating:
            return timeSinceUpdate > 30  // Update every 30 seconds when navigating
        case .browsing:
            return timeSinceUpdate > 300  // Update every 5 minutes when browsing
        case .background:
            return timeSinceUpdate > 1800  // Update every 30 minutes in background
        }
    }

    enum UserActivity {
        case navigating
        case browsing
        case background
    }
}
```

### Efficient Reverse Geocoding

Handle reverse geocoding failures gracefully without retrying unnecessarily:

```swift
class EfficientGeocodingManager {
    private var failedCoordinates: Set<String> = []

    func shouldAttemptReverseGeocoding(for location: CLLocation) -> Bool {
        let key = "\(location.coordinate.latitude),\(location.coordinate.longitude)"

        // Don't retry geocoding for the same coordinates if it failed recently
        return !failedCoordinates.contains(key)
    }

    func recordGeocodingFailure(for location: CLLocation) {
        let key = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        failedCoordinates.insert(key)

        // Clear failed coordinates periodically
        if failedCoordinates.count > 50 {
            failedCoordinates.removeAll()
        }
    }
}
```

## User Experience Best Practices

### Contextual Permission Requests

Always explain why location is needed before requesting:

```swift
struct ContextualLocationRequest: View {
    @State private var showingLocationRequest = false
    @State private var location: GPSLocation?

    var body: some View {
        VStack(spacing: 20) {
            if location != nil {
                LocationBasedContent(location: location!)
            } else if showingLocationRequest {
                LocationRequestView { requestedLocation in
                    location = requestedLocation
                    showingLocationRequest = false
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)

                    Text("Find Nearby Places")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("We'll show you restaurants, shops, and attractions near your location.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    Button("Enable Location Services") {
                        showingLocationRequest = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
```

### Progressive Disclosure

Start with basic functionality and add location features progressively:

```swift
struct ProgressiveLocationApp: View {
    @State private var location: GPSLocation?
    @State private var showingLocationFeatures = false

    var body: some View {
        TabView {
            BasicContentTab()
                .tabItem { Label("Home", systemImage: "house") }

            if let location = location {
                LocationBasedTab(location: location)
                    .tabItem { Label("Nearby", systemImage: "location") }
            }

            SettingsTab {
                if location == nil && !showingLocationFeatures {
                    Button("Enable Location Features") {
                        showingLocationFeatures = true
                    }
                }
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
        .sheet(isPresented: $showingLocationFeatures) {
            LocationOnboardingView { enabledLocation in
                location = enabledLocation
                showingLocationFeatures = false
            }
        }
    }
}
```

### Graceful Error Recovery

Provide helpful alternatives when location fails:

```swift
struct GracefulLocationView: View {
    @State private var location: GPSLocation?
    @State private var error: GPSLocationError?
    @State private var showingManualLocation = false

    var body: some View {
        VStack(spacing: 20) {
            if let location = location {
                LocationContentView(location: location)
            } else if let error = error {
                LocationErrorView(error: error) {
                    // Primary action: Retry
                    Task { await attemptLocationRequest() }
                } secondaryAction: {
                    // Secondary action: Manual location
                    showingManualLocation = true
                }
            } else {
                LocationLoadingView()
                    .task { await attemptLocationRequest() }
            }
        }
        .sheet(isPresented: $showingManualLocation) {
            ManualLocationPicker { selectedLocation in
                location = selectedLocation
                showingManualLocation = false
            }
        }
    }

    private func attemptLocationRequest() async {
        do {
            location = try await LocationProvider().gpsLocation()
            error = nil
        } catch let locationError as GPSLocationError {
            error = locationError
        } catch {
            error = .notFound
        }
    }
}
```

### Loading States and Feedback

Provide clear feedback during location requests:

```swift
struct LocationLoadingView: View {
    @State private var animationPhase = 0

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(Double(animationPhase) * 360 / 8))
            }

            Text("Finding your location...")
                .font(.headline)

            Text("This may take a few moments")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                animationPhase = (animationPhase + 1) % 8
            }
        }
    }
}
```

## Architecture Best Practices

### Separation of Concerns

Keep location logic separate from UI logic:

```swift
import Observation

// Domain layer - handles location business logic
@MainActor
@Observable
class LocationService {
    var currentLocation: GPSLocation?
    var locationHistory: [GPSLocation] = []

    private let locationProvider = LocationProvider()

    func updateLocation() async {
        do {
            let location = try await locationProvider.gpsLocation()
            currentLocation = location
            addToHistory(location)
        } catch {
            // Handle error appropriately
        }
    }

    private func addToHistory(_ location: GPSLocation) {
        locationHistory.append(location)
        // Keep only last 10 locations
        if locationHistory.count > 10 {
            locationHistory.removeFirst()
        }
    }
}

// UI layer - handles presentation
struct LocationView: View {
    @State private var locationService = LocationService()

    var body: some View {
        VStack {
            if let location = locationService.currentLocation {
                LocationDisplayView(location: location)
            }

            Button("Update Location") {
                Task { await locationService.updateLocation() }
            }
        }
    }
}
```

### Dependency Injection for Testing

Make LocationProvider injectable for better testing:

```swift
protocol LocationProviding {
    func gpsLocation() async throws -> GPSLocation
}

extension LocationProvider: LocationProviding {}

@MainActor
@Observable
class LocationViewModel {
    var location: GPSLocation?
    var error: GPSLocationError?

    private let locationProvider: LocationProviding

    init(locationProvider: LocationProviding = LocationProvider()) {
        self.locationProvider = locationProvider
    }

    func requestLocation() async {
        do {
            location = try await locationProvider.gpsLocation()
            error = nil
        } catch let locationError as GPSLocationError {
            error = locationError
        } catch {
            error = .notFound
        }
    }
}

// Easy testing with mock
class MockLocationProvider: LocationProviding {
    var result: Result<GPSLocation, Error> = .failure(GPSLocationError.notFound)

    func gpsLocation() async throws -> GPSLocation {
        switch result {
        case .success(let location):
            return location
        case .failure(let error):
            throw error
        }
    }
}
```

### Error Handling Strategy

Implement consistent error handling across your app:

```swift
import Observation

@MainActor
@Observable
class AppErrorHandler {
    var currentError: AppError?

    enum AppError: LocalizedError {
        case locationError(GPSLocationError)
        case networkError(URLError)
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .locationError(let gpsError):
                return gpsError.localizedDescription
            case .networkError(let urlError):
                return urlError.localizedDescription
            case .unknown(let error):
                return error.localizedDescription
            }
        }

        var recoveryAction: String? {
            switch self {
            case .locationError(let gpsError):
                return gpsError.recoveryAction
            case .networkError:
                return "Check your internet connection and try again."
            case .unknown:
                return "Please try again."
            }
        }
    }

    func handle(_ error: Error) {
        if let gpsError = error as? GPSLocationError {
            currentError = .locationError(gpsError)
        } else if let urlError = error as? URLError {
            currentError = .networkError(urlError)
        } else {
            currentError = .unknown(error)
        }
    }
}

extension GPSLocationError {
    var recoveryAction: String {
        switch self {
        case .authorizationDenied:
            return "Enable location access in Settings."
        case .locationUnavailable, .notFound:
            return "Make sure you have GPS signal and try again."
        default:
            return "Please try again."
        }
    }
}
```

## Data Privacy and Security

### Minimize Location Data Storage

Only store location data when necessary:

```swift
class PrivacyAwareLocationManager {
    // Store only essential location data
    struct MinimalLocation: Codable {
        let latitude: Double
        let longitude: Double
        let timestamp: Date
        let name: String

        init(from gpsLocation: GPSLocation) {
            self.latitude = gpsLocation.location.coordinate.latitude
            self.longitude = gpsLocation.location.coordinate.longitude
            self.timestamp = gpsLocation.location.timestamp
            self.name = gpsLocation.name
        }
    }

    private let maxStoredLocations = 5
    private let storageKey = "recent_locations"

    func storeLocation(_ location: GPSLocation) {
        var stored = getStoredLocations()
        stored.append(MinimalLocation(from: location))

        // Keep only recent locations
        if stored.count > maxStoredLocations {
            stored.removeFirst()
        }

        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func getStoredLocations() -> [MinimalLocation] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let locations = try? JSONDecoder().decode([MinimalLocation].self, from: data) else {
            return []
        }
        return locations
    }

    func clearStoredLocations() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
```

### Location Data Lifecycle

Implement proper data lifecycle management:

```swift
import Observation

@MainActor
@Observable
class LocationDataManager {
    var currentLocation: GPSLocation?

    private let sessionTimeout: TimeInterval = 3600 // 1 hour
    private var sessionStart: Date?

    func startLocationSession() async {
        sessionStart = Date()
        await updateLocation()
    }

    func endLocationSession() {
        currentLocation = nil
        sessionStart = nil
        clearTemporaryData()
    }

    private func updateLocation() async {
        guard let sessionStart = sessionStart,
              Date().timeIntervalSince(sessionStart) < sessionTimeout else {
            endLocationSession()
            return
        }

        do {
            currentLocation = try await LocationProvider().gpsLocation()
        } catch {
            // Handle error
        }
    }

    private func clearTemporaryData() {
        // Clear any temporary location data
        UserDefaults.standard.removeObject(forKey: "temp_location_data")
    }
}
```

## Monitoring and Analytics

### Performance Monitoring

Track location request performance:

```swift
class LocationPerformanceMonitor {
    static let shared = LocationPerformanceMonitor()
    private var requestTimes: [TimeInterval] = []

    func trackLocationRequest<T>(_ operation: () async throws -> T) async rethrows -> T {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)

        recordRequestTime(duration)
        return result
    }

    private func recordRequestTime(_ duration: TimeInterval) {
        requestTimes.append(duration)

        // Keep only last 100 requests
        if requestTimes.count > 100 {
            requestTimes.removeFirst()
        }

        // Log slow requests
        if duration > 10.0 {
            print("Slow location request: \(duration)s")
        }
    }

    var averageRequestTime: TimeInterval {
        guard !requestTimes.isEmpty else { return 0 }
        return requestTimes.reduce(0, +) / Double(requestTimes.count)
    }
}

// Usage
class MonitoredLocationManager {
    func getLocation() async throws -> GPSLocation {
        return try await LocationPerformanceMonitor.shared.trackLocationRequest {
            try await LocationProvider().gpsLocation()
        }
    }
}
```

## Next Steps

With these best practices, you're ready to build robust, efficient location-based apps:

- <doc:GettingStarted> - Review basic integration
- <doc:SwiftUIIntegration> - Apply best practices to SwiftUI
- <doc:Testing> - Test your optimized location features
- <doc:ErrorHandling> - Implement robust error handling