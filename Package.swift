// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CanvasKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CanvasKitCore",
            targets: ["CanvasKitCore"]
        ),
        .library(
            name: "CanvasKitUIKit",
            targets: ["CanvasKitUIKit"]
        ),
        .library(
            name: "CanvasKitSwiftUI",
            targets: ["CanvasKitSwiftUI"]
        )
    ],
    targets: [
        .target(
            name: "CanvasKitCore",
            path: "Sources/CanvasKitCore",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "CanvasKitUIKit",
            dependencies: ["CanvasKitCore"],
            path: "Sources/CanvasKitUIKit"
        ),
        .target(
            name: "CanvasKitSwiftUI",
            dependencies: [
                "CanvasKitCore",
                "CanvasKitUIKit"
            ],
            path: "Sources/CanvasKitSwiftUI"
        ),
        .testTarget(
            name: "CanvasKitCoreTests",
            dependencies: ["CanvasKitCore"],
            path: "Tests/CanvasKitCoreTests"
        )
    ]
)
