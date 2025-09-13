# SwiftUI Integration

Build location-aware SwiftUI apps with reactive patterns and proper state management.

## Overview

LocationProvider is designed with SwiftUI in mind, featuring @MainActor safety and async/await support. This guide demonstrates patterns for integrating location services into SwiftUI apps, from simple location display to complex location-based features.

## Basic SwiftUI Integration

### Simple Location Display

The most basic integration shows current location in a SwiftUI view:

```swift
import SwiftUI
import LocationProvider

struct SimpleLocationView: View {
    @State private var location: GPSLocation?
    @State private var isLoading = false

    private let locationProvider = LocationProvider()

    var body: some View {
        VStack(spacing: 16) {
            if let location = location {
                VStack {
                    Text("Current Location")
                        .font(.headline)
                    Text(location.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Lat: \(location.location.coordinate.latitude, specifier: "%.4f")")
                    Text("Lng: \(location.location.coordinate.longitude, specifier: "%.4f")")
                }
            } else if isLoading {
                ProgressView("Finding location...")
            } else {
                Button("Get My Location") {
                    Task { await requestLocation() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func requestLocation() async {
        isLoading = true
        defer { isLoading = false }

        do {
            location = try await locationProvider.gpsLocation()
        } catch {
            // Handle error appropriately
            print("Location error: \(error)")
        }
    }
}
```

### Automatic Location Loading

Load location automatically when the view appears:

```swift
struct AutoLocationView: View {
    @State private var location: GPSLocation?
    @State private var error: GPSLocationError?

    var body: some View {
        Group {
            if let location = location {
                LocationContentView(location: location)
            } else if let error = error {
                ErrorView(error: error) {
                    await loadLocation()
                }
            } else {
                ProgressView("Loading location...")
            }
        }
        .task {
            await loadLocation()
        }
    }

    private func loadLocation() async {
        error = nil
        do {
            location = try await LocationProvider().gpsLocation()
        } catch let locationError as GPSLocationError {
            error = locationError
        } catch {
            error = .notFound
        }
    }
}
```

## Observable Location Manager

Create a reusable location manager using Swift's @Observable:

```swift
import SwiftUI
import LocationProvider
import Observation

@MainActor
@Observable
class LocationManager {
    var location: GPSLocation?
    var error: GPSLocationError?
    var isLoading = false

    private let locationProvider = LocationProvider()

    func requestLocation() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            location = try await locationProvider.gpsLocation()
        } catch let locationError as GPSLocationError {
            error = locationError
        } catch {
            error = .notFound
        }
    }

    func reset() {
        location = nil
        error = nil
        isLoading = false
    }

    var hasLocation: Bool {
        location != nil
    }

    var canRetry: Bool {
        error != nil && !isLoading
    }
}
```

Use the location manager in your views:

```swift
struct LocationManagerView: View {
    @State private var locationManager = LocationManager()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                LocationStatusView(manager: locationManager)
                LocationActionsView(manager: locationManager)
            }
            .navigationTitle("My Location")
            .padding()
        }
    }
}

struct LocationStatusView: View {
    let manager: LocationManager

    var body: some View {
        Group {
            if manager.isLoading {
                ProgressView("Finding location...")
                    .progressViewStyle(.circular)
            } else if let location = manager.location {
                LocationCard(location: location)
            } else if let error = manager.error {
                ErrorCard(error: error)
            } else {
                Text("Tap below to get your location")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minHeight: 100)
    }
}

struct LocationActionsView: View {
    let manager: LocationManager

    var body: some View {
        HStack(spacing: 12) {
            if manager.hasLocation {
                Button("Refresh") {
                    Task { await manager.requestLocation() }
                }
                .buttonStyle(.bordered)
            } else if manager.canRetry {
                Button("Try Again") {
                    Task { await manager.requestLocation() }
                }
                .buttonStyle(.borderedProminent)
            } else if !manager.isLoading {
                Button("Get Location") {
                    Task { await manager.requestLocation() }
                }
                .buttonStyle(.borderedProminent)
            }

            if manager.hasLocation || manager.error != nil {
                Button("Reset") {
                    manager.reset()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
```

## Advanced Location Features

### Location-Based Search

Combine location services with search functionality:

```swift
@MainActor
@Observable
class LocationSearchManager {
    var currentLocation: GPSLocation?
    var searchResults: [SearchResult] = []
    var isLoadingLocation = false
    var isSearching = false

    private let locationProvider = LocationProvider()

    func loadLocationAndSearch(for query: String) async {
        // First get location
        await loadCurrentLocation()

        // Then search based on location
        guard let location = currentLocation else { return }
        await performSearch(query: query, near: location)
    }

    private func loadCurrentLocation() async {
        isLoadingLocation = true
        defer { isLoadingLocation = false }

        do {
            currentLocation = try await locationProvider.gpsLocation()
        } catch {
            // Handle error appropriately
            currentLocation = nil
        }
    }

    private func performSearch(query: String, near location: GPSLocation) async {
        isSearching = true
        defer { isSearching = false }

        // Perform location-based search
        // Implementation depends on your search service
    }
}
```

### Map Integration with LocationProvider

Integrate with MapKit for location-based maps:

```swift
import MapKit
import SwiftUI
import LocationProvider

struct LocationMapView: View {
    @State private var location: GPSLocation?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
                MapPin(coordinate: annotation.coordinate, tint: .blue)
            }
            .onAppear {
                Task { await loadLocation() }
            }

            VStack {
                Spacer()
                HStack {
                    if let location = location {
                        LocationInfoCard(location: location)
                    }
                    Spacer()
                }
            }
            .padding()
        }
    }

    private var annotations: [LocationAnnotation] {
        guard let location = location else { return [] }
        return [LocationAnnotation(location: location)]
    }

    private func loadLocation() async {
        do {
            let newLocation = try await LocationProvider().gpsLocation()
            location = newLocation

            // Update map region to center on user location
            region = MKCoordinateRegion(
                center: newLocation.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        } catch {
            // Handle error
        }
    }
}

struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String

    init(location: GPSLocation) {
        self.coordinate = location.location.coordinate
        self.title = location.name
    }
}
```

## State Management Patterns

### Using Environment for Location

Share location data across your app using SwiftUI's environment:

```swift
@MainActor
@Observable
class AppLocationManager {
    var currentLocation: GPSLocation?
    var error: GPSLocationError?
    var isLoading = false

    private let locationProvider = LocationProvider()

    func initialize() async {
        await requestLocation()
    }

    func requestLocation() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            currentLocation = try await locationProvider.gpsLocation()
        } catch let locationError as GPSLocationError {
            error = locationError
        } catch {
            error = .notFound
        }
    }
}

// In your App file
@main
struct LocationApp: App {
    @State private var locationManager = AppLocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
                .task {
                    await locationManager.initialize()
                }
        }
    }
}

// In child views
struct ChildView: View {
    @Environment(AppLocationManager.self) private var locationManager

    var body: some View {
        if let location = locationManager.currentLocation {
            Text("Current location: \(location.name)")
        } else {
            Text("Location not available")
        }
    }
}
```

### Location-Aware Navigation

Create navigation that adapts based on location availability:

```swift
struct LocationAwareApp: View {
    @State private var locationManager = LocationManager()

    var body: some View {
        TabView {
            LocationTab(manager: locationManager)
                .tabItem {
                    Label("Location", systemImage: "location")
                }

            if locationManager.hasLocation {
                NearbyTab(location: locationManager.location!)
                    .tabItem {
                        Label("Nearby", systemImage: "map")
                    }
            }

            SettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .task {
            await locationManager.requestLocation()
        }
    }
}
```

## Reactive Location Updates

For apps that need to react to location changes, create reactive patterns:

```swift
@MainActor
@Observable
class ReactiveLocationManager {
    var location: GPSLocation?
    var isMonitoring = false

    private let locationProvider = LocationProvider()
    private var monitoringTask: Task<Void, Never>?

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitoringTask = Task {
            while !Task.isCancelled {
                do {
                    location = try await locationProvider.gpsLocation()
                    // Wait before next update
                    try? await Task.sleep(for: .seconds(30))
                } catch {
                    // Handle error, maybe reduce frequency
                    try? await Task.sleep(for: .seconds(60))
                }
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    deinit {
        stopMonitoring()
    }
}
```

## Testing SwiftUI Location Features

Test your SwiftUI location components using preview-friendly patterns:

```swift
struct LocationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with location
            LocationView()
                .environment(mockLocationManager(with: .appleHQ))
                .previewDisplayName("With Location")

            // Preview loading state
            LocationView()
                .environment(mockLocationManager(loading: true))
                .previewDisplayName("Loading")

            // Preview error state
            LocationView()
                .environment(mockLocationManager(error: .authorizationDenied))
                .previewDisplayName("Permission Denied")
        }
    }

    static func mockLocationManager(
        with location: GPSLocation? = nil,
        loading: Bool = false,
        error: GPSLocationError? = nil
    ) -> LocationManager {
        let manager = LocationManager()
        manager.location = location
        manager.isLoading = loading
        manager.error = error
        return manager
    }
}

#if DEBUG
extension GPSLocation {
    static let appleHQ = GPSLocation(
        name: "Apple Park",
        location: CLLocation(latitude: 37.334922, longitude: -122.009033)
    )
}
#endif
```

## Performance Considerations

### Efficient Location Sharing

Share location data efficiently across views without unnecessary requests:

```swift
@MainActor
@Observable
class SharedLocationManager {
    private(set) var location: GPSLocation?
    private(set) var lastUpdated: Date?
    private let locationProvider = LocationProvider()

    // Cache location for 5 minutes
    private let cacheTimeout: TimeInterval = 300

    var isLocationFresh: Bool {
        guard let lastUpdated = lastUpdated else { return false }
        return Date().timeIntervalSince(lastUpdated) < cacheTimeout
    }

    func getLocation() async -> GPSLocation? {
        if isLocationFresh, let location = location {
            return location
        }

        do {
            let newLocation = try await locationProvider.gpsLocation()
            location = newLocation
            lastUpdated = Date()
            return newLocation
        } catch {
            return nil
        }
    }
}
```

## Next Steps

- <doc:Testing> - Test your SwiftUI location features thoroughly
- <doc:BestPractices> - Optimize performance and user experience
- <doc:ErrorHandling> - Handle errors gracefully in SwiftUI
- <doc:HandlingPermissions> - Manage permissions in SwiftUI apps