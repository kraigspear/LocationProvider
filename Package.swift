// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocationProvider",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LocationProvider",
            targets: ["LocationProvider"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kraigspear/Spearfoundation", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LocationProvider",
            dependencies: [
                .product(name: "SpearFoundation", package: "SpearFoundation"),
            ]
        ),
        .testTarget(
            name: "LocationProviderTests",
            dependencies: ["LocationProvider"]
        ),
    ]
)

// Enable Approachable Concurrency for all targets
for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(contentsOf: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ])
    target.swiftSettings = settings
}
