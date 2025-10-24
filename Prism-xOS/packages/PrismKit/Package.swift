// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrismKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PrismKit",
            targets: ["PrismKit"]
        )
    ],
    dependencies: [
        .package(path: "../PrismCore")
    ],
    targets: [
        .target(
            name: "PrismKit",
            dependencies: [
                .product(name: "PrismCore", package: "PrismCore")
            ],
            path: "Sources/PrismKit"
        ),
        .testTarget(
            name: "PrismKitTests",
            dependencies: ["PrismKit"],
            path: "Tests/PrismKitTests"
        )
    ]
)
