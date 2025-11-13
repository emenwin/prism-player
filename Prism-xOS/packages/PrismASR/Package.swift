// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrismASR",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
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
        // Binary target for whisper.cpp XCFramework (built with official script)
        // Note: The module name is "whisper" (from whisper.framework inside the xcframework)
        .binaryTarget(
            name: "whisper",
            path: "CWhisper.xcframework"
        ),

        // Swift target
        .target(
            name: "PrismASR",
            dependencies: [
                "whisper",  // Binary target from Build/CWhisper.xcframework
                .product(name: "PrismCore", package: "PrismCore"),
            ],
            path: "Sources/PrismASR"
        ),

        // Tests
        .testTarget(
            name: "PrismASRTests",
            dependencies: ["PrismASR"],
            path: "Tests/PrismASRTests"
        ),
    ]
    // Note: cxxLanguageStandard removed as it's only needed for C++ source compilation
    // Binary target (XCFramework) already contains compiled code
)
