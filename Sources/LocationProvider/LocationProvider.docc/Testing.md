# Testing

Test the code that uses LocationProvider by putting it behind a protocol your app owns.

## Overview

``LocationProvider/LocationProvider`` talks to Core Location and MapKit directly, and its test seams are internal to the package. To test your own features, depend on a small protocol instead of the concrete class, then hand your code a mock in tests. The mock returns a ``GPSLocation`` or throws a ``GPSLocationError``, which are the only two outcomes your code has to handle.

## Put the Provider Behind a Protocol

Declare the one method your code calls, and conform `LocationProvider` to it:

```swift
import LocationProvider

@MainActor
protocol LocationProviding {
    func gpsLocation(accuracyRequirement: LocationProvider.AccuracyRequirement) async throws(GPSLocationError) -> GPSLocation
}

extension LocationProvider: LocationProviding {}
```

The requirement spells out `accuracyRequirement`. A requirement of plain `gpsLocation()` would not compile, because a default argument does not satisfy a protocol requirement.

Inject it where you use it, defaulting to the real provider:

```swift
import Observation

@MainActor
@Observable
final class LocationViewModel {
    private(set) var location: GPSLocation?
    private(set) var error: GPSLocationError?

    private let locationProvider: any LocationProviding

    init(locationProvider: any LocationProviding = LocationProvider()) {
        self.locationProvider = locationProvider
    }

    func requestLocation() async {
        do {
            location = try await locationProvider.gpsLocation(accuracyRequirement: .any)
            error = nil
        } catch {
            self.error = error
        }
    }
}
```

## Write a Mock

```swift
@MainActor
final class MockLocationProvider: LocationProviding {
    var result: Result<GPSLocation, GPSLocationError>

    init(result: Result<GPSLocation, GPSLocationError>) {
        self.result = result
    }

    func gpsLocation(accuracyRequirement _: LocationProvider.AccuracyRequirement) async throws(GPSLocationError) -> GPSLocation {
        try result.get()
    }
}
```

## Test Success and Each Error

Give the mock the outcome under test. Each ``GPSLocationError`` case is a state your UI should handle:

```swift
import CoreLocation
import LocationProvider
import Testing

@MainActor
struct LocationViewModelTests {
    @Test("Shows the location when one is found")
    func showsLocation() async {
        let viewModel = LocationViewModel(locationProvider: MockLocationProvider(result: .success(.appleHQ)))

        await viewModel.requestLocation()

        #expect(viewModel.location == .appleHQ)
        #expect(viewModel.error == nil)
    }

    @Test("Shows the error when permission is denied")
    func showsAuthorizationDenied() async {
        let viewModel = LocationViewModel(locationProvider: MockLocationProvider(result: .failure(.authorizationDenied)))

        await viewModel.requestLocation()

        #expect(viewModel.location == nil)
        #expect(viewModel.error == .authorizationDenied)
    }
}
```

When reverse geocoding fails, `LocationProvider` still returns the location, named `"GPS"`. To test how your UI shows an unnamed location, build one the same way:

```swift
let unnamedLocation = GPSLocation(name: nil, location: CLLocation(latitude: 1, longitude: 1))
// unnamedLocation.name == "GPS"
```

## Debug Locations

In debug builds, ``GPSLocation`` provides fixtures for tests and previews: `GPSLocation.appleHQ` and `GPSLocation.statueOfLiberty`.

## Check Error Messages

``GPSLocationError`` supplies user-facing text through `localizedDescription`. If your UI shows it, you can assert on the guidance it gives:

```swift
@Test("Error messages tell the user what to do")
func errorMessages() {
    let denied = GPSLocationError.authorizationDenied.localizedDescription
    #expect(denied.contains("Settings"))
    #expect(denied.contains("Location Services"))
    #expect(GPSLocationError.locationUnavailable.localizedDescription.contains("temporarily"))
}
```

## Next Steps

- <doc:BestPractices> - Learn optimization techniques and UX patterns
- <doc:SwiftUIIntegration> - Build robust SwiftUI location features
- <doc:ErrorHandling> - Handle all error scenarios gracefully
