//
//  LocationSettingsNavigator.swift
//  LocationProvider
//
//  Provides navigation to location-specific system settings
//

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

/// Opens location-specific system settings to help users manage location permissions.
///
/// When an error's ``GPSLocationError/recovery`` is ``GPSLocationError/Recovery/openSettings``,
/// users need a clear path to fix the problem. This function opens the appropriate settings
/// screen where location permissions can be managed.
///
/// ## Usage Example
///
/// ```swift
/// do {
///     let location = try await locationProvider.gpsLocation()
/// } catch where error.recovery == .openSettings {
///     // Show alert with button to open settings
///     Button("Open Location Settings") {
///         Task {
///             await openLocationSettings()
///         }
///     }
/// } catch {
///     // Handle other errors
/// }
/// ```
///
/// ## SwiftUI Integration
///
/// ```swift
/// struct LocationErrorView: View {
///     let error: GPSLocationError
///
///     var body: some View {
///         VStack {
///             Text(error.localizedDescription)
///             Button("Open Settings") {
///                 Task {
///                     await openLocationSettings()
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Platform Behavior
///
/// - **iOS**: Opens your app's settings page where users can manage location permissions
/// - **macOS**: Opens Security & Privacy → Location Services in System Settings
public func openLocationSettings() async {
    #if os(iOS)
        await MainActor.run {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            UIApplication.shared.open(settingsURL)
        }
    #elseif os(macOS)
        await MainActor.run {
            guard let settingsURL =
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
            else {
                return
            }
            NSWorkspace.shared.open(settingsURL)
        }
    #endif
}
