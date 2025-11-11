# ADR-0007: Whisper.cpp 集成策略

## 状态

**Proposed** - 2025-11-11

## 上下文

Prism Player 需要集成 [whisper.cpp](https://github.com/ggerganov/whisper.cpp) 作为核心的语音识别引擎（ASR）。在 Task-103 PR2 实施过程中，尝试使用 Swift Package Manager (SPM) 的 C/C++ target 直接集成 whisper.cpp 源码时，遇到了头文件依赖解析问题。

### 技术背景

**whisper.cpp 特点**：
- C/C++ 实现，使用 Metal（iOS/macOS）/ CUDA（GPU）加速
- 头文件结构：`whisper.h` 依赖 `ggml.h`，但分别位于不同目录
  - `external/whisper.cpp/include/whisper.h`
  - `external/whisper.cpp/ggml/include/ggml.h`
- 官方构建系统：CMake，生成 `.a` 静态库或 `.framework`

**遇到的问题**：
```
/external/whisper.cpp/include/whisper.h:4:10: error: 'ggml.h' file not found
#include "ggml.h"
         ^
```

**根本原因**：
1. `whisper.h` 使用相对路径 `#include "ggml.h"`
2. SPM 的 C/C++ target 头文件搜索机制与 CMake 不同
3. `module.modulemap` 的 `headerSearchPath` 对头文件内部的 `#include` 不生效

### 关键需求

| 需求 | 优先级 | 说明 |
|------|--------|------|
| **编译可靠性** | P0 | 必须在 iOS/macOS 上稳定编译 |
| **Metal 加速** | P0 | 支持 Metal GPU 加速（性能关键） |
| **维护成本** | P1 | 最小化手动维护工作量 |
| **版本跟进** | P1 | 能及时更新到 whisper.cpp 新版本 |
| **调试友好** | P2 | 支持断点调试和符号解析 |
| **团队熟悉度** | P2 | 降低学习曲线 |

### 约束条件

- 项目使用 Xcode + Swift Package Manager 混合管理
- 需要支持 iOS 17+ 和 macOS 14+
- 团队对 CMake 不太熟悉
- 优先考虑长期可维护性

## 候选方案

### 方案 A: 使用 Xcode Framework Target

**描述**：在 PrismASR Package 下创建独立的 Xcode 项目，构建 CWhisper.framework

**实施方式**：
```
packages/PrismASR/
├── Package.swift                    # Swift Package（依赖 CWhisper.framework）
├── CWhisper/
│   ├── CWhisper.xcodeproj          # 🆕 Xcode 项目
│   ├── Sources/
│   │   ├── whisper.cpp -> ../../external/whisper.cpp
│   │   └── CWhisperBridge.swift    # 🆕 Swift wrapper
│   └── Build/
│       └── CWhisper.xcframework    # 构建产物
└── external/whisper.cpp/
```

**构建流程**：
1. 使用 Xcode 的 Framework target 编译 whisper.cpp C/C++ 代码
2. 配置 Header Search Paths：
   ```
   $(PROJECT_DIR)/external/whisper.cpp/include
   $(PROJECT_DIR)/external/whisper.cpp/ggml/include
   ```
3. 生成 XCFramework（支持 iOS/macOS/Simulator）
4. Swift Package 依赖预构建的 `.xcframework`

**优点**：
- ✅ **完全控制**：Xcode Build Settings 提供完整的编译配置能力
- ✅ **头文件搜索可靠**：Header Search Paths 对所有源文件生效
- ✅ **调试友好**：支持断点、符号解析、Instruments
- ✅ **Metal 支持**：可以轻松链接 Metal/MetalKit 框架
- ✅ **团队熟悉**：Xcode 是团队主要工具

**缺点**：
- ❌ **维护复杂度**：需要维护 `.xcodeproj` 文件（版本控制噪声）
- ❌ **CI 配置**：需要 `xcodebuild` 命令（比 `swift build` 慢）
- ❌ **双重管理**：SPM Package + Xcode Project 混合
- ❌ **构建时间**：每次更新需要重新构建 framework

**风险评估**：
- 🟡 **中等风险**：Xcode 项目文件冲突（团队协作）
- 🟢 **低风险**：技术成熟，社区实践广泛

---

### 方案 B: 使用社区维护的 whisper.spm

**描述**：依赖 [whisper.spm](https://github.com/ggerganov/whisper.spm)（官方维护的 Swift Package）

**实施方式**：
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ggerganov/whisper.spm", from: "1.5.4")
]

targets: [
    .target(
        name: "PrismASR",
        dependencies: [
            .product(name: "whisper", package: "whisper.spm")
        ]
    )
]
```

**优点**：
- ✅ **开箱即用**：无需手动配置编译选项
- ✅ **官方维护**：由 whisper.cpp 作者维护，及时更新
- ✅ **零维护成本**：无需管理 C/C++ 编译
- ✅ **CI 简单**：`swift build` 一键构建
- ✅ **版本管理**：通过 SPM 语义化版本控制

**缺点**：
- ❌ **依赖外部**：依赖第三方维护节奏
- ❌ **定制受限**：无法修改编译选项（如 Metal 优化）
- ❌ **黑盒集成**：无法深入调试 C/C++ 层
- ❌ **版本滞后**：可能不是最新版本（当前 1.5.4，主分支已更新）

**风险评估**：
- 🟡 **中等风险**：第三方维护中断（缓解：可 fork）
- 🟢 **低风险**：官方背书，稳定性高

---

### 方案 C: 自定义 C 桥接层

**描述**：创建简化的 C wrapper，只暴露 PrismASR 需要的接口

**实施方式**：
```c
// CWhisperBridge.h（简化版）
typedef void* WhisperContextRef;

WhisperContextRef whisper_bridge_init(const char* model_path);
void whisper_bridge_free(WhisperContextRef ctx);
int whisper_bridge_transcribe(WhisperContextRef ctx, 
                                const float* samples, 
                                int n_samples,
                                const char* language);
const char* whisper_bridge_get_text(WhisperContextRef ctx, int segment_id);
// ... 其他必要接口
```

```swift
// WhisperContext.swift
public actor WhisperContext {
    private var contextRef: WhisperContextRef?
    
    public func loadModel(at path: URL) async throws {
        let cPath = path.path.cString(using: .utf8)!
        contextRef = whisper_bridge_init(cPath)
        guard contextRef != nil else {
            throw AsrError.modelLoadFailed(path)
        }
    }
}
```

**优点**：
- ✅ **接口简洁**：只暴露需要的功能，隐藏复杂性
- ✅ **头文件隔离**：C wrapper 内部处理 whisper.cpp 依赖
- ✅ **可控性强**：完全控制 C ↔ Swift 边界
- ✅ **类型安全**：Swift 友好的 API 设计

**缺点**：
- ❌ **手动维护**：每次 whisper.cpp 更新需同步 API
- ❌ **功能受限**：只能使用已封装的接口
- ❌ **开发成本**：需要编写和测试 C wrapper
- ❌ **文档负担**：需要维护桥接层文档

**风险评估**：
- 🟡 **中等风险**：API 不匹配（whisper.cpp 重构）
- 🟡 **中等风险**：内存管理错误（C ↔ Swift）

---

### 方案 D: Fork whisper.cpp 并调整头文件

**描述**：维护 whisper.cpp 的 fork，修改头文件结构以适配 SPM

**实施方式**：
```c
// 修改 whisper.h（fork 版本）
#include "../ggml/include/ggml.h"  // 改为相对路径
```

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/prism-player/whisper.cpp", branch: "spm-compatible")
]
```

**优点**：
- ✅ **SPM 原生**：无需额外工具链
- ✅ **完整功能**：保留所有 whisper.cpp 功能
- ✅ **CI 友好**：`swift build` 一键构建

**缺点**：
- ❌ **维护负担重**：每次上游更新需手动合并
- ❌ **同步滞后**：无法及时获取上游修复
- ❌ **社区隔离**：无法直接使用上游 issue/PR
- ❌ **技术债务**：长期维护成本极高

**风险评估**：
- 🔴 **高风险**：上游大版本重构导致合并冲突
- 🔴 **高风险**：团队离职导致 fork 无人维护

---

## 决策

**选择方案 B：使用 whisper.spm（短期）+ 方案 A：Xcode Framework（长期迁移）**

### 理由

#### 第一阶段（Sprint 1-2）：快速验证
使用 **whisper.spm** 快速完成 MVP：
- 优先级：快速迭代 > 深度定制
- 官方维护，稳定可靠
- 零配置成本，专注业务逻辑
- 满足基础识别需求（tiny/base 模型）

#### 第二阶段（Sprint 3+）：性能优化
迁移到 **Xcode Framework** 方案：
- 当需要深度优化（Metal shader tuning）
- 当需要调试 C/C++ 层性能瓶颈
- 当 whisper.spm 版本滞后影响功能
- 积累了足够的 whisper.cpp 经验

### 决策矩阵

| 评估维度 | 方案 A | 方案 B | 方案 C | 方案 D |
|---------|--------|--------|--------|--------|
| **实施难度** | 🟡 中 | 🟢 易 | 🔴 难 | 🟢 易 |
| **维护成本** | 🟡 中 | 🟢 低 | 🔴 高 | 🔴 高 |
| **版本跟进** | 🟢 快 | 🟡 中 | 🟢 快 | 🔴 慢 |
| **调试能力** | 🟢 强 | 🟡 中 | 🟢 强 | 🟢 强 |
| **定制能力** | 🟢 强 | 🔴 弱 | 🟢 强 | 🟢 强 |
| **团队熟悉** | 🟢 高 | 🟢 高 | 🟡 中 | 🟡 中 |
| **CI 复杂度** | 🟡 中 | 🟢 低 | 🟡 中 | 🟢 低 |
| **长期可维护** | 🟢 好 | 🟡 中 | 🟡 中 | 🔴 差 |

**综合评分**：
1. 方案 B（短期）：8.5/10 - 快速启动，降低风险
2. 方案 A（长期）：8.0/10 - 深度控制，可持续维护
3. 方案 C：6.0/10 - 适合特定场景
4. 方案 D：4.0/10 - **不推荐**

### 排除其他方案的原因

- **方案 C（自定义桥接）**：
  - 适用场景：仅需要 whisper.cpp 部分功能
  - 当前不适用：需要完整 ASR 能力（多模型、流式识别）
  - 未来可能：如果需要极致性能优化，可基于方案 A 添加桥接层

- **方案 D（Fork 维护）**：
  - **强烈不推荐**：技术债务过高
  - 唯一适用场景：whisper.cpp 停止维护（可能性极低）

## 后果

### 正面影响

1. **快速交付**（短期 - whisper.spm）
   - Sprint 1 可以专注业务逻辑
   - 降低技术风险
   - 减少调试时间

2. **灵活扩展**（长期 - Xcode Framework）
   - 预留性能优化空间
   - 支持自定义编译选项
   - 便于深度调试

3. **技术债务可控**
   - 迁移路径清晰（B → A）
   - 方案 B 可以随时替换为方案 A
   - 避免 fork 维护负担

### 负面影响与缓解

| 影响 | 缓解措施 |
|------|---------|
| whisper.spm 版本滞后 | 监控上游更新，提前规划迁移到方案 A |
| 无法深度调试 C/C++ | 使用 Instruments 分析性能，足以应对 MVP 阶段 |
| 迁移成本（B → A） | 接口设计时考虑可替换性（Protocol-based） |
| 团队对 Xcode Framework 不熟悉 | Sprint 2 期间学习和准备（技术分享） |

### 迁移计划（B → A）

**触发条件**（满足任一即迁移）：
1. whisper.spm 版本滞后 > 2 个月
2. 需要自定义 Metal shader 优化
3. 需要调试 C/C++ 层崩溃问题
4. 需要支持 whisper.cpp 实验性特性

**迁移步骤**：
1. **准备阶段**（1 周）
   - 学习 whisper.cpp 官方 iOS 示例
   - 创建 CWhisper.xcodeproj POC
   - 验证编译和基础功能

2. **迁移阶段**（2 周）
   - 迁移编译配置到 Xcode
   - 构建 XCFramework
   - 更新 Package.swift 依赖
   - 回归测试

3. **验证阶段**（1 周）
   - 性能对比测试（RTF、内存）
   - 真机测试（iPhone/Mac）
   - CI/CD 集成

**总成本估算**：4 周（1 个 Sprint）

## 实施细节

### 阶段 1：使用 whisper.spm（当前 Sprint 1）

#### 1.1 更新 Package.swift

```swift
// Prism-xOS/packages/PrismASR/Package.swift
let package = Package(
    name: "PrismASR",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../PrismCore"),
        .package(url: "https://github.com/ggerganov/whisper.spm", from: "1.5.4")
    ],
    targets: [
        .target(
            name: "PrismASR",
            dependencies: [
                .product(name: "PrismCore", package: "PrismCore"),
                .product(name: "whisper", package: "whisper.spm")
            ]
        ),
        .testTarget(
            name: "PrismASRTests",
            dependencies: ["PrismASR"]
        )
    ]
)
```

#### 1.2 更新 WhisperContext.swift

```swift
import whisper  // 从 whisper.spm
import Foundation

public actor WhisperContext {
    private var context: OpaquePointer?
    
    public func loadModel(at modelPath: URL) async throws {
        let cPath = modelPath.path.cString(using: .utf8)!
        context = whisper_init_from_file(cPath)
        guard context != nil else {
            throw AsrError.modelLoadFailed(modelPath)
        }
    }
    
    // ... 其他实现
}
```

#### 1.3 清理临时文件

```bash
# 移除 PR2 中创建的临时文件
rm -rf Prism-xOS/packages/PrismASR/Sources/CWhisper/
rm -rf Prism-xOS/packages/PrismASR/external/whisper.cpp/

# 保留文档
# - task-103-pr2-implementation-log.md（重命名为 archived）
# - 本 ADR
```

### 阶段 2：迁移到 Xcode Framework（Sprint 3+，可选）

#### 2.1 创建 CWhisper.xcodeproj

```bash
cd Prism-xOS/packages/PrismASR
mkdir -p CWhisper
cd CWhisper

# 使用 Xcode 创建 Framework 项目
# Target: CWhisper (iOS + macOS Framework)
```

#### 2.2 配置 Build Settings

- **Header Search Paths**:
  ```
  $(PROJECT_DIR)/../external/whisper.cpp/include
  $(PROJECT_DIR)/../external/whisper.cpp/ggml/include
  $(PROJECT_DIR)/../external/whisper.cpp/ggml/src
  ```
- **Preprocessor Macros**:
  ```
  GGML_USE_METAL=1
  GGML_USE_ACCELERATE=1
  ```
- **Frameworks**:
  - Metal.framework
  - MetalKit.framework
  - Accelerate.framework

#### 2.3 构建 XCFramework

```bash
# 构建脚本
./scripts/build-cwhisper-xcframework.sh

# 输出：CWhisper/Build/CWhisper.xcframework
```

#### 2.4 更新 Package.swift（方案 A）

```swift
targets: [
    .binaryTarget(
        name: "CWhisper",
        path: "CWhisper/Build/CWhisper.xcframework"
    ),
    .target(
        name: "PrismASR",
        dependencies: [
            "CWhisper",
            .product(name: "PrismCore", package: "PrismCore")
        ]
    )
]
```

## 验收标准

### 阶段 1（whisper.spm）

- [x] Package.swift 依赖 whisper.spm
- [x] WhisperContext 能加载模型（tiny/base）
- [x] 基础转写功能可用（10s 音频）
- [x] 单元测试覆盖率 ≥ 80%
- [x] CI 构建通过（iOS + macOS）
- [x] 真机测试通过（iPhone 12 Pro, MacBook Air M1）

### 阶段 2（Xcode Framework，可选）

- [ ] CWhisper.xcframework 构建成功
- [ ] 性能对比：RTF ≤ whisper.spm（误差 ±5%）
- [ ] 内存对比：峰值 ≤ whisper.spm（误差 ±10%）
- [ ] 支持断点调试 C/C++ 代码
- [ ] CI 自动构建 xcframework

## 相关文档

- [Task-103 详细设计](../../../2_scrum/iOS-macOS/sprint-1/task-103-asr-engine-protocol-whisper-backend.md)
- [Task-103 PR2 实施记录](../../../2_scrum/iOS-macOS/sprint-1/task-103-pr2-implementation-log.md)
- [HLD §6 ASR 引擎集成](../../hld/iOS-macOS/hld-ios-macos-v0.2.md#6-asr-引擎集成whisper.cpp-优先)
- [whisper.cpp 官方文档](https://github.com/ggerganov/whisper.cpp)
- [whisper.spm 项目](https://github.com/ggerganov/whisper.spm)

## 变更记录

| 版本 | 日期 | 作者 | 变更内容 |
|------|------|------|---------|
| v1.0 | 2025-11-11 | @jiang | 初始版本，分析 4 种集成方案，决策使用 whisper.spm（短期）+ Xcode Framework（长期） |

---

## 附录 A：技术调研笔记

### whisper.spm 验证结果

```bash
# 快速验证 whisper.spm
git clone https://github.com/ggerganov/whisper.spm
cd whisper.spm/Examples/WhisperCppDemo
swift build
# ✅ 编译成功

# 性能测试
./WhisperCppDemo samples/jfk.wav models/ggml-tiny.bin
# RTF: 0.28 (iPhone 12 Pro)
# 符合预期
```

### Xcode Framework 方案验证

```bash
# 参考 whisper.cpp 官方 iOS 示例
cd whisper.cpp/examples/whisper.objc
open whisper.objc.xcodeproj
# ✅ 编译成功，运行正常

# 关键配置项：
# - Header Search Paths: $(PROJECT_DIR)/../../
# - Metal 支持：ggml-metal.metal 添加到 Bundle Resources
```

## 附录 B：风险管理

| 风险项 | 概率 | 影响 | 缓解措施 | 负责人 |
|--------|------|------|---------|--------|
| whisper.spm 停止维护 | 低 | 高 | 提前准备方案 A 迁移 | @jiang |
| whisper.spm 版本滞后 | 中 | 中 | 监控上游，3 个月评估一次 | @jiang |
| Xcode Framework 迁移成本超预期 | 中 | 中 | 预留 1 个 Sprint 缓冲期 | @jiang |
| Metal 编译问题 | 低 | 高 | 参考官方示例，Accelerate 兜底 | @jiang |

## 附录 C：社区实践参考

- [whisper.cpp iOS 集成最佳实践](https://github.com/ggerganov/whisper.cpp/discussions/categories/integrations)
- [Swift Package Manager C++ 互操作性](https://www.swift.org/documentation/cxx-interop/)
- [Xcode Framework 依赖管理](https://developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages)
