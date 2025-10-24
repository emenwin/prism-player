// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrismCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PrismCore",
            targets: ["PrismCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0")
    ],
    targets: [
        .target(
            name: "PrismCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/PrismCore"
        ),
        .testTarget(
            name: "PrismCoreTests",
            dependencies: ["PrismCore"],
            path: "Tests/PrismCoreTests"
        ),
    ]
)
