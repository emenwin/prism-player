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
        // C/C++ target for whisper.cpp
        .target(
            name: "CWhisper",
            dependencies: [],
            path: ".",
            exclude: [
                "external/whisper.cpp/examples",
                "external/whisper.cpp/models",
                "external/whisper.cpp/samples",
                "external/whisper.cpp/tests",
                "external/whisper.cpp/bindings",
                "external/whisper.cpp/.github",
                "external/whisper.cpp/cmake",
                "external/whisper.cpp/ci",
                "external/whisper.cpp/scripts",
                "external/whisper.cpp/grammars",
                "external/whisper.cpp/src/coreml",
                "external/whisper.cpp/src/openvino",
                "external/whisper.cpp/ggml/src/ggml-cuda",
                "external/whisper.cpp/ggml/src/ggml-hip",
                "external/whisper.cpp/ggml/src/ggml-sycl",
                "external/whisper.cpp/ggml/src/ggml-vulkan",
                "external/whisper.cpp/ggml/src/ggml-opencl",
                "external/whisper.cpp/ggml/src/ggml-hexagon",
                "external/whisper.cpp/ggml/src/ggml-cann",
                "external/whisper.cpp/ggml/src/ggml-musa",
                "external/whisper.cpp/ggml/src/ggml-rpc",
                "external/whisper.cpp/ggml/src/ggml-webgpu",
                "external/whisper.cpp/ggml/src/ggml-zdnn",
                "external/whisper.cpp/ggml/src/ggml-blas",
                "external/whisper.cpp/ggml/src/ggml-cpu",
                "Sources/PrismASR",
                "Tests"
            ],
            sources: [
                "external/whisper.cpp/src/whisper.cpp",
                "external/whisper.cpp/ggml/src/ggml.c",
                "external/whisper.cpp/ggml/src/ggml.cpp",
                "external/whisper.cpp/ggml/src/gguf.cpp",
                "external/whisper.cpp/ggml/src/ggml-alloc.c",
                "external/whisper.cpp/ggml/src/ggml-backend.cpp",
                "external/whisper.cpp/ggml/src/ggml-backend-reg.cpp",
                "external/whisper.cpp/ggml/src/ggml-quants.c",
                "external/whisper.cpp/ggml/src/ggml-threading.cpp",
                "external/whisper.cpp/ggml/src/ggml-metal/ggml-metal.cpp"
            ],
            resources: [
                .copy("external/whisper.cpp/ggml/src/ggml-metal/ggml-metal.metal")
            ],
            publicHeadersPath: "Sources/CWhisper/include",
            cSettings: [
                .define("GGML_USE_METAL"),
                .define("GGML_USE_ACCELERATE"),
                .define("GGML_METAL_NDEBUG"),
                .define("GGML_VERSION", to: "\"master\""),
                .define("GGML_COMMIT", to: "\"unknown\""),
                .define("WHISPER_VERSION", to: "\"master\""),
                .headerSearchPath("external/whisper.cpp/include"),
                .headerSearchPath("external/whisper.cpp/src"),
                .headerSearchPath("external/whisper.cpp/ggml/include"),
                .headerSearchPath("external/whisper.cpp/ggml/src"),
                .headerSearchPath("external/whisper.cpp/ggml/src/ggml-metal")
            ],
            cxxSettings: [
                .define("GGML_USE_METAL"),
                .define("GGML_USE_ACCELERATE"),
                .define("GGML_METAL_NDEBUG"),
                .define("GGML_VERSION", to: "\"master\""),
                .define("GGML_COMMIT", to: "\"unknown\""),
                .define("WHISPER_VERSION", to: "\"master\""),
                .headerSearchPath("external/whisper.cpp/include"),
                .headerSearchPath("external/whisper.cpp/src"),
                .headerSearchPath("external/whisper.cpp/ggml/include"),
                .headerSearchPath("external/whisper.cpp/ggml/src"),
                .headerSearchPath("external/whisper.cpp/ggml/src/ggml-metal")
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Foundation")
            ]
        ),
        
        // Swift target
        .target(
            name: "PrismASR",
            dependencies: [
                "CWhisper",
                .product(name: "PrismCore", package: "PrismCore")
            ],
            path: "Sources/PrismASR"
        ),
        
        // Tests
        .testTarget(
            name: "PrismASRTests",
            dependencies: ["PrismASR"],
            path: "Tests/PrismASRTests"
        )
    ],
    cxxLanguageStandard: .cxx17
)
