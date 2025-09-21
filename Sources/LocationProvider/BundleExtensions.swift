//
//  BundleExtensions.swift
//  LocationProvider
//
//  Created by Kraig Spear on 1/26/25.
//

import Foundation

extension Bundle {
    /// Returns the display name of the app, falling back to the bundle name if not available.
    ///
    /// This computed property retrieves the app's user-facing name from the Info.plist,
    /// which is typically set via CFBundleDisplayName or CFBundleName. This is used
    /// in error messages to provide context-specific instructions to users.
    var displayName: String {
        // Try CFBundleDisplayName first (user-facing name)
        if let displayName = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return displayName
        }
        // Fall back to CFBundleName (internal name)
        if let bundleName = object(forInfoDictionaryKey: "CFBundleName") as? String {
            return bundleName
        }
        // Last resort: use "this app"
        return "this app"
    }
}
