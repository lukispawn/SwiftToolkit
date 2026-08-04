// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftToolkit",
    platforms: [
        .iOS(.v17),
        .macOS(.v15)
    ],
    products: [
        // Dynamic multi-target product: consumers linking several dynamic images
        // (app + frameworks) share ONE copy of both modules. A static product
        // was copied into every client image, duplicating class metadata
        // (spurious casting failures, split static state). LoadableModel must
        // ride in the SAME framework: as a separate static product its
        // same-package dependency on SwiftToolkit drags a private static copy
        // of SwiftToolkit into every client. See BluetoothKit ADR-033.
        .library(
            name: "SwiftToolkit",
            type: .dynamic,
            targets: ["SwiftToolkit", "LoadableModel"]),
        // Kept for consumers that link only LoadableModel. Do NOT link both
        // products from one app: that reintroduces the duplication.
        .library(
            name: "LoadableModel",
            targets: ["LoadableModel"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "0.1.0"),
        /*.package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0")*/
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftToolkit",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ]
        ),
        .target(
            name: "LoadableModel",
            dependencies: [
                "SwiftToolkit",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ]
        ),
        .testTarget(
            name: "SwiftToolkitTests",
            dependencies: [
                "SwiftToolkit",
                /*.product(name: "Testing", package: "swift-testing")*/
            ]
        ),
        .testTarget(
            name: "LoadableModelTests",
            dependencies: [
                "LoadableModel",
                /*.product(name: "Testing", package: "swift-testing")*/
            ]
        )
    ]
)
