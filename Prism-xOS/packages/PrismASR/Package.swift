// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrismASR",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PrismASR",
            targets: ["PrismASR"]
        )
    ],
    dependencies: [
        .package(path: "../PrismCore")
    ],
    targets: [
        .target(
            name: "PrismASR",
            dependencies: [
                .product(name: "PrismCore", package: "PrismCore")
            ],
            path: "Sources/PrismASR"
        ),
        .testTarget(
            name: "PrismASRTests",
            dependencies: ["PrismASR"],
            path: "Tests/PrismASRTests"
        )
    ]
)
