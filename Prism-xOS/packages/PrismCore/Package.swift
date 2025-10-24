// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrismCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PrismCore",
            targets: ["PrismCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PrismCore",
            dependencies: [],
            path: "Sources/PrismCore"
        ),
        .testTarget(
            name: "PrismCoreTests",
            dependencies: ["PrismCore"],
            path: "Tests/PrismCoreTests"
        )
    ]
)
