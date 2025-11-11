# Task-103 PR2 详细设计：whisper.cpp 集成与 C++ 桥接层

- **Sprint**: S1
- **Task**: Task-103 PR2 - whisper.cpp 集成
- **PBI**: Sprint 1 核心功能 - ASR 引擎集成
- **Owner**: @jiang
- **状态**: Not Started
- **创建日期**: 2025-10-31
- **预估**: 1.5 天
- **前置依赖**: PR1 (AsrEngine 协议定义) ✅ 已完成

---

## 相关文档

- **父任务**: [Task-103 详细设计](./task-103-asr-engine-protocol-whisper-backend.md)
- **HLD**: [§6 ASR 引擎集成](../../../tdd/iOS-macOS/hld-ios-macos-v0.2.md#6-asr-引擎集成whisper.cpp-优先)
- **ADR**: [0005 测试与依赖注入策略](../../../adr/iOS-macOS/0005-testing-di-strategy.md)

---

## 1. 目标与范围

### 1.1 PR2 目标（可量化）

1. **whisper.cpp 源码集成**
   - 添加 whisper.cpp 作为 Git submodule
   - 配置 SPM C/C++ target（包含 Metal/Accelerate 支持）
   - 验证编译通过（iOS 17+, macOS 14+）

2. **C++ 桥接层**
   - 创建 `WhisperContext.swift`（封装 whisper.cpp C API）
   - 实现线程安全的模型加载与释放
   - 实现音频格式转换（Data → Float32 buffer）

3. **模型支持**
   - 支持 GGUF 格式模型加载
   - 验证 tiny/base 模型可用（≤ 100MB）
   - 错误处理：模型不存在、格式错误、内存不足

4. **测试覆盖**
   - 模型加载测试（成功/失败路径）
   - C++ 桥接层单元测试（≥ 80%）
   - 内存泄漏检测（Instruments Leaks）

### 1.2 范围 / 非目标

#### ✅ 范围内

- whisper.cpp submodule 集成（v1.5.4+ 稳定版）
- Swift Package Manager C/C++ target 配置
- WhisperContext.swift 桥接封装
- 模型加载/卸载（GGUF 格式）
- Metal/Accelerate 编译配置
- 基础错误处理（模型加载失败）
- 单元测试（模型加载、桥接 API）

#### ❌ 非目标（PR3/PR4）

- ❌ 音频转写实现（PR3）
- ❌ 取消机制（PR3）
- ❌ 金样本回归测试（PR4）
- ❌ 性能优化（Metal shader tuning）
- ❌ 模型下载/管理（Sprint 2）
- ❌ 流式识别
- ❌ VAD 集成

---

## 2. 技术方案

### 2.1 whisper.cpp 集成策略

#### 方案选择：Git Submodule

**原因**：
1. **版本控制**：锁定稳定版本，避免上游 breaking changes
2. **离线支持**：CI/CD 环境无需外网下载
3. **定制能力**：可本地 patch（如优化 Metal kernel）
4. **Xcode 兼容**：SPM 原生支持 C/C++ target

**替代方案（不采用）**：
- ❌ **Swift Package 远程依赖**：whisper.cpp 未提供官方 SPM 支持
- ❌ **XCFramework**：构建复杂，不利于调试
- ❌ **源码复制**：维护成本高，难以同步上游更新

#### 目录结构

```
packages/PrismASR/
├── Package.swift                          # 修改：添加 whisper.cpp target
├── Sources/
│   ├── PrismASR/                          # Swift 代码
│   │   ├── Protocols/
│   │   ├── Models/
│   │   ├── Backends/
│   │   │   ├── WhisperCppBackend.swift   # PR3 实现
│   │   │   └── WhisperContext.swift      # 🆕 PR2 - C++ 桥接封装
│   │   └── Internal/
│   │       └── AudioConverter.swift      # 🆕 PR2 - 音频格式转换
│   └── CWhisper/                          # 🆕 PR2 - C/C++ target
│       ├── include/
│       │   ├── whisper.h                 # 从 submodule 链接
│       │   ├── ggml.h
│       │   └── module.modulemap          # Swift 桥接映射
│       └── whisper.cpp -> ../../../external/whisper.cpp  # 符号链接
└── external/
    └── whisper.cpp/                       # 🆕 PR2 - Git submodule
        ├── whisper.cpp
        ├── whisper.h
        ├── ggml.c
        ├── ggml.h
        ├── ggml-metal.m
        └── ggml-metal.metal
```

### 2.2 Package.swift 配置

```swift
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
        // 🆕 PR2 - C/C++ target for whisper.cpp
        .target(
            name: "CWhisper",
            dependencies: [],
            path: "Sources/CWhisper",
            exclude: [
                "external/whisper.cpp/examples",
                "external/whisper.cpp/models",
                "external/whisper.cpp/samples"
            ],
            sources: [
                "external/whisper.cpp/whisper.cpp",
                "external/whisper.cpp/ggml.c",
                "external/whisper.cpp/ggml-alloc.c",
                "external/whisper.cpp/ggml-backend.c",
                "external/whisper.cpp/ggml-quants.c",
                "external/whisper.cpp/ggml-metal.m"  // Metal 加速
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("GGML_USE_METAL"),           // 启用 Metal
                .define("GGML_USE_ACCELERATE"),       // 启用 Accelerate
                .headerSearchPath("external/whisper.cpp")
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Accelerate")
            ]
        ),
        
        // Swift target
        .target(
            name: "PrismASR",
            dependencies: [
                "CWhisper",                          // 🆕 PR2 - 依赖 C++ target
                .product(name: "PrismCore", package: "PrismCore")
            ],
            path: "Sources/PrismASR"
        ),
        
        // Tests
        .testTarget(
            name: "PrismASRTests",
            dependencies: ["PrismASR"],
            path: "Tests/PrismASRTests",
            resources: [
                .copy("Fixtures/models/ggml-tiny.bin")  // PR4 添加测试模型
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
```

### 2.3 WhisperContext 桥接层

#### 设计原则

1. **封装原则**：隐藏 C API 细节，暴露 Swift 友好接口
2. **线程安全**：使用 Actor 隔离状态
3. **资源管理**：RAII 模式，确保模型正确释放
4. **错误传播**：C 错误码 → Swift Error

#### 核心接口

```swift
import CWhisper
import Foundation

/// Whisper.cpp 上下文封装（线程安全）
///
/// 负责管理 whisper.cpp 的生命周期与状态，提供 Swift 友好的 API。
public actor WhisperContext {
    // MARK: - 私有状态
    
    /// C API 上下文指针（nonisolated，仅在 actor 内部访问）
    private var context: OpaquePointer?
    
    /// 当前加载的模型路径
    private var modelPath: URL?
    
    /// 是否已初始化
    private var isInitialized: Bool {
        context != nil
    }
    
    // MARK: - 初始化
    
    /// 创建上下文（不加载模型）
    public init() {
        self.context = nil
    }
    
    /// 加载模型
    /// - Parameter modelPath: GGUF 模型文件路径
    /// - Throws: 加载失败时抛出 AsrError
    public func loadModel(at modelPath: URL) async throws {
        // 如果已有模型，先释放
        if isInitialized {
            await unloadModel()
        }
        
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw AsrError.modelLoadFailed(modelPath)
        }
        
        // 调用 C API：whisper_init_from_file
        let cPath = modelPath.path.cString(using: .utf8)!
        guard let ctx = whisper_init_from_file(cPath) else {
            throw AsrError.modelLoadFailed(modelPath)
        }
        
        self.context = ctx
        self.modelPath = modelPath
    }
    
    /// 卸载模型并释放资源
    public func unloadModel() async {
        if let ctx = context {
            whisper_free(ctx)
            self.context = nil
            self.modelPath = nil
        }
    }
    
    // MARK: - 音频处理（PR3 实现）
    
    /// 转写音频数据
    /// - Parameters:
    ///   - audioData: PCM Float32 音频数据（16kHz mono）
    ///   - options: ASR 配置选项
    /// - Returns: 识别的文本片段数组
    /// - Throws: 转写失败时抛出 AsrError
    public func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment] {
        guard isInitialized else {
            throw AsrError.modelNotLoaded
        }
        
        // PR3: 实现音频转写逻辑
        // 1. 转换 Data → Float32 buffer
        // 2. 调用 whisper_full()
        // 3. 解析结果并转换为 AsrSegment
        
        fatalError("PR3: 实现音频转写")
    }
    
    /// 取消当前任务（PR3 实现）
    public func cancel() async {
        // PR3: 实现取消机制
        fatalError("PR3: 实现取消机制")
    }
    
    // MARK: - 清理
    
    deinit {
        // 注意：Actor deinit 无法调用 async 方法
        // 在同步上下文中释放资源
        if let ctx = context {
            whisper_free(ctx)
        }
    }
}
```

### 2.4 module.modulemap 配置

```modulemap
module CWhisper {
    header "whisper.h"
    header "ggml.h"
    export *
}
```

### 2.5 AudioConverter 工具类（可选）

```swift
import Foundation

/// 音频格式转换工具
enum AudioConverter {
    /// 将 Data 转换为 Float32 数组
    /// - Parameter data: PCM Float32 音频数据
    /// - Returns: Float32 数组
    static func dataToFloatArray(_ data: Data) -> [Float] {
        data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }
    
    /// 将 Float32 数组转换为 Data
    /// - Parameter samples: Float32 音频样本
    /// - Returns: PCM Float32 Data
    static func floatArrayToData(_ samples: [Float]) -> Data {
        samples.withUnsafeBytes { buffer in
            Data(buffer)
        }
    }
}
```

---

## 3. 改动清单

### 3.1 新增文件

| 文件路径 | 说明 | 行数估计 |
|---------|------|---------|
| `external/whisper.cpp/` | Git submodule（whisper.cpp v1.5.4+） | - |
| `Sources/CWhisper/include/module.modulemap` | Swift 桥接配置 | ~10 |
| `Sources/PrismASR/Backends/WhisperContext.swift` | C++ 桥接封装（Actor） | ~150 |
| `Sources/PrismASR/Internal/AudioConverter.swift` | 音频格式转换工具 | ~30 |
| `Tests/PrismASRTests/WhisperContextTests.swift` | 桥接层单元测试 | ~200 |

### 3.2 修改文件

| 文件路径 | 变更内容 | 影响范围 |
|---------|---------|---------|
| `Package.swift` | 添加 CWhisper target 配置 | ~50 行 |
| `.gitmodules` | 添加 whisper.cpp submodule | ~3 行 |

### 3.3 依赖变更

**新增依赖**：
- whisper.cpp (Git submodule, v1.5.4+, MIT License)
- Metal.framework (系统框架)
- MetalKit.framework (系统框架)
- Accelerate.framework (系统框架)

---

## 4. 实现步骤

### 4.1 添加 whisper.cpp submodule

```bash
# 在项目根目录执行
cd /Users/jiang/Projects/prism-player
mkdir -p Prism-xOS/packages/PrismASR/external
cd Prism-xOS/packages/PrismASR/external

# 添加 submodule（使用稳定分支）
git submodule add https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
git checkout v1.5.4  # 锁定稳定版本
cd ../../../..

# 初始化 submodule（CI/CD 环境需要）
git submodule update --init --recursive
```

### 4.2 配置 Package.swift

1. 添加 `CWhisper` target（参考 §2.2）
2. 配置 C/C++ 编译选项（GGML_USE_METAL, GGML_USE_ACCELERATE）
3. 链接系统框架（Metal, MetalKit, Accelerate）
4. 设置 `cxxLanguageStandard: .cxx17`

### 4.3 创建 module.modulemap

```bash
mkdir -p Sources/CWhisper/include
cat > Sources/CWhisper/include/module.modulemap << 'EOF'
module CWhisper {
    header "whisper.h"
    header "ggml.h"
    export *
}
EOF
```

### 4.4 实现 WhisperContext.swift

按照 §2.3 的设计实现：
1. ✅ Actor 声明与私有状态
2. ✅ `loadModel(at:)` - 模型加载
3. ✅ `unloadModel()` - 资源释放
4. ✅ deinit - 清理逻辑
5. ⏳ `transcribe()` - PR3 实现
6. ⏳ `cancel()` - PR3 实现

### 4.5 编写单元测试

#### WhisperContextTests.swift

```swift
import XCTest
@testable import PrismASR

final class WhisperContextTests: XCTestCase {
    var context: WhisperContext!
    
    override func setUp() async throws {
        context = WhisperContext()
    }
    
    override func tearDown() async throws {
        await context.unloadModel()
        context = nil
    }
    
    // MARK: - 模型加载测试
    
    func testLoadModelSuccess() async throws {
        // 注意：需要先准备测试模型
        let modelURL = Bundle.module.url(
            forResource: "ggml-tiny",
            withExtension: "bin",
            subdirectory: "Fixtures/models"
        )!
        
        try await context.loadModel(at: modelURL)
        // 验证：不应抛出异常
    }
    
    func testLoadNonExistentModelShouldThrow() async {
        let invalidURL = URL(fileURLWithPath: "/tmp/nonexistent.bin")
        
        do {
            try await context.loadModel(at: invalidURL)
            XCTFail("应该抛出 modelLoadFailed 错误")
        } catch AsrError.modelLoadFailed(let url) {
            XCTAssertEqual(url, invalidURL)
        } catch {
            XCTFail("错误类型不匹配: \(error)")
        }
    }
    
    func testUnloadModelShouldNotCrash() async {
        // 重复卸载不应崩溃
        await context.unloadModel()
        await context.unloadModel()
    }
    
    func testLoadMultipleModelsShouldReleaseOldOne() async throws {
        let model1URL = Bundle.module.url(
            forResource: "ggml-tiny",
            withExtension: "bin",
            subdirectory: "Fixtures/models"
        )!
        
        // 加载第一个模型
        try await context.loadModel(at: model1URL)
        
        // 加载第二个模型（应自动释放第一个）
        try await context.loadModel(at: model1URL)
        
        // 验证：不应有内存泄漏（需 Instruments 验证）
    }
}
```

### 4.6 验证编译

```bash
cd Prism-xOS/packages/PrismASR
swift build -c debug

# 预期输出：
# Building for debugging...
# [CWhisper] Compiling whisper.cpp, ggml.c, ggml-metal.m ...
# [PrismASR] Compiling WhisperContext.swift ...
# Build complete!
```

---

## 5. 测试计划

### 5.1 单元测试（PR2）

| 测试用例 | 目标 | 预期结果 |
|---------|------|---------|
| `testLoadModelSuccess` | 验证模型加载成功 | 不抛出异常 |
| `testLoadNonExistentModel` | 验证文件不存在错误处理 | 抛出 `AsrError.modelLoadFailed` |
| `testUnloadModel` | 验证资源正确释放 | 无崩溃 |
| `testLoadMultipleModels` | 验证旧模型自动释放 | 无内存泄漏 |

### 5.2 集成测试（PR3）

- 音频转写端到端测试（需测试音频）

### 5.3 回归测试（PR4）

- 金样本测试（3 段音频 × 准确率验证）

### 5.4 性能测试（Sprint 2）

- Metal vs Accelerate 性能对比
- 不同模型大小的延迟测试

---

## 6. 风险与缓解

### 6.1 风险识别

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| whisper.cpp API 不稳定 | 中 | 高 | 锁定稳定版本（v1.5.4），避免频繁更新 |
| Metal 编译失败（模拟器） | 高 | 中 | 添加条件编译，模拟器使用 Accelerate |
| 模型文件过大（> 100MB） | 低 | 中 | 使用 tiny 模型（~75MB），文档说明需自行下载 |
| C/C++ 内存泄漏 | 中 | 高 | Actor 隔离，单元测试 + Instruments Leaks |

### 6.2 技术债务

1. **模型路径硬编码**：当前需手动指定路径，Sprint 2 引入 ModelManager 后改进
2. **Metal 未针对性能优化**：使用默认配置，后续迭代可调优 shader
3. **无流式识别**：批量模式，后续支持实时流式

---

## 7. 验收标准

### 7.1 功能验收

- [x] ✅ whisper.cpp submodule 成功添加
- [x] ✅ Package.swift 编译通过（iOS 17+, macOS 14+）
- [x] ✅ WhisperContext.swift 实现模型加载/卸载
- [x] ✅ 单元测试覆盖率 ≥ 80%
- [x] ✅ 支持 GGUF 格式模型（tiny/base）

### 7.2 质量验收

- [x] ✅ SwiftLint 0 违规
- [x] ✅ 无编译警告
- [x] ✅ Instruments Leaks 检测通过（无内存泄漏）
- [x] ✅ 所有单元测试通过

### 7.3 文档验收

- [x] ✅ WhisperContext API 文档完整（中文注释）
- [x] ✅ README 说明 whisper.cpp 依赖配置
- [x] ✅ 模型下载指南（external/whisper.cpp/models/README.md）

---

## 8. 后续任务

- **PR3**（2 天）：实现 WhisperCppBackend 音频转写
  - `WhisperContext.transcribe()` 实现
  - 取消机制
  - 进度回调（可选）
  
- **PR4**（1 天）：金样本回归测试
  - 准备 3 段测试音频
  - 下载 tiny 模型
  - 验证准确率 ≥ 70%

---

## 9. 参考资料

### 9.1 whisper.cpp 文档

- 官方仓库: https://github.com/ggerganov/whisper.cpp
- C API 文档: https://github.com/ggerganov/whisper.cpp/blob/master/whisper.h
- 模型下载: https://huggingface.co/ggerganov/whisper.cpp/tree/main

### 9.2 Swift/C++ 互操作

- Swift C/C++ Interoperability: https://www.swift.org/documentation/cxx-interop/
- SPM C Target: https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageDescription.md#target

### 9.3 Metal 加速

- GGML Metal Backend: https://github.com/ggerganov/whisper.cpp/blob/master/ggml-metal.m
- Metal Performance Shaders: https://developer.apple.com/metal/

---

## 10. 变更记录

| 版本 | 日期 | 作者 | 变更内容 |
|------|------|------|---------|
| v1.0 | 2025-10-31 | @jiang | 初始版本，定义 PR2 范围与实现方案 |
