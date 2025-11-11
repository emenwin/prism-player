# ADR-0001: 多平台工程架构（iOS + macOS）

## 状态
✅ **已接受**  
日期：2025-10-23  
决策者：[@team]  
相关文档：Sprint Plan Sprint 0 Task 2, HLD §13, PRD v0.2

**更新**：2025-10-28 - App 层工程结构细化（见 ADR-0006）

## 背景与问题陈述

Prism Player 需要同时支持 iOS 17+ 和 macOS 14+，实现以下目标：
- 共享核心业务逻辑（ASR、播放、字幕处理、存储）
- UI 层需要平台差异化（SwiftUI 适配不同交互模式）
- 支持独立测试与并行开发
- 保持良好的构建速度与团队协作体验

需要决策：
1. **代码组织方式**：单工程 vs 多工程 vs Workspace
2. **模块化策略**：Swift Package vs Framework vs CocoaPods
3. **依赖管理方式**：如何处理跨平台依赖与平台特定代码
4. **测试策略**：如何实现模块级独立测试

## 决策驱动因素

### 业务因素
- **代码复用率**：ASR/播放/存储逻辑预计 90% 可共享
- **平台差异**：UI 层需要 iOS/macOS 独立实现（文件选择、窗口管理等）
- **迭代速度**：需要快速迭代，增量构建优化

### 技术因素
- **测试性**：核心模块需独立测试，覆盖率目标 ≥70%
- **构建速度**：避免全量编译，支持增量构建
- **团队协作**：清晰的模块边界，减少 Git 冲突
- **生态兼容**：符合 Apple 平台最佳实践

### 约束条件
- 遵循 MVVM 架构模式
- 支持协议式 DI（便于测试与 Mock）
- SwiftLint 严格模式
- 最小化外部依赖

## 考虑的方案

### 方案 1：单 Xcode 工程 + 多 Target + Shared 文件夹

```
PrismPlayer.xcodeproj
├── PrismPlayer-iOS (Target)
├── PrismPlayer-macOS (Target)
└── Shared/ (Folder Reference)
    ├── Models/
    ├── Services/
    └── ViewModels/
```

**实现方式**：
- 使用 Xcode 的 Target Membership 管理文件共享
- 通过编译条件区分平台代码（`#if os(iOS)`）
- 共享代码放在 Shared 文件夹

**优点**：
- ✅ 配置最简单，学习成本低
- ✅ 单工程构建，调试方便
- ✅ 文件导航直观

**缺点**：
- ❌ 模块边界不清晰，容易产生耦合
- ❌ 难以实现模块级独立测试
- ❌ 构建耦合严重，全量编译耗时长
- ❌ `.xcodeproj` 文件 Git 冲突风险高
- ❌ 无法强制依赖方向（可能出现循环依赖）
- ❌ 测试覆盖率难以按模块统计

---

### 方案 2：Xcode Workspace + Swift Package（推荐 ✅）

```
prism-player/
├── PrismPlayer.xcworkspace
├── apps/
│   ├── PrismPlayer-iOS/
│   │   ├── PrismPlayer-iOS.xcodeproj
│   │   └── Sources/
│   └── PrismPlayer-macOS/
│       ├── PrismPlayer-macOS.xcodeproj
│       └── Sources/
└── packages/
    ├── PrismCore/              # 核心协议与模型
    │   ├── Package.swift
    │   ├── Sources/PrismCore/
    │   └── Tests/PrismCoreTests/
    ├── PrismASR/               # ASR 引擎封装
    │   ├── Package.swift
    │   ├── Sources/PrismASR/
    │   └── Tests/PrismASRTests/
    └── PrismKit/               # UI 组件与工具
        ├── Package.swift
        ├── Sources/PrismKit/
        └── Tests/PrismKitTests/
```

**实现方式**：
- Workspace 聚合 App 工程和 Swift Packages
- 每个 Package 独立定义依赖与平台支持
- App Target 通过 SPM 依赖各 Package

**优点**：
- ✅ **清晰的模块边界**：Package = 独立模块，强制依赖方向
- ✅ **独立测试与 CI**：每个 Package 可单独构建测试
- ✅ **增量编译优化**：Package 级缓存，提升构建速度
- ✅ **Git 友好**：`Package.swift` 纯文本，冲突少
- ✅ **符合 Apple 推荐**：官方推荐的模块化方案
- ✅ **测试覆盖率分离**：可按 Package 统计覆盖率
- ✅ **依赖可视化**：Package.swift 明确声明依赖关系
- ✅ **支持本地与远程**：未来可发布为独立库

**缺点**：
- ⚠️ 初始配置复杂度较高（但可通过脚本缓解）
- ⚠️ Xcode 索引可能较慢（大量 Package 时）
- ⚠️ 需要理解 SPM 的 Manifest 语法

---

### 方案 3：CocoaPods/Carthage

```
prism-player/
├── Podfile
├── PrismPlayer-iOS/
├── PrismPlayer-macOS/
└── Pods/
```

**优点**：
- ✅ 成熟的依赖管理工具

**缺点**：
- ❌ CocoaPods 已逐渐被 SPM 取代
- ❌ 增加外部依赖管理复杂度
- ❌ Carthage 不支持 SwiftUI/资源管理
- ❌ Apple 官方不再推荐
- ❌ 构建速度不如 SPM（XCFramework 开销）

---

## 决策结果

**选择方案 2：Xcode Workspace + Swift Package**

### 模块划分策略

| Package | 职责 | 平台支持 | 测试覆盖率目标 | 依赖 |
|---------|------|----------|---------------|------|
| **PrismCore** | 核心协议定义、Models、业务服务接口 | iOS + macOS | ≥70% | 无外部依赖 |
| **PrismASR** | AsrEngine 协议与后端实现（Whisper） | iOS + macOS | ≥70% | PrismCore |
| **PrismKit** | UI 组件、扩展工具、平台适配层 | iOS + macOS | ≥60% | PrismCore |

### 依赖方向规则

```
┌─────────────────────────────────────┐
│  PrismPlayer-iOS / macOS (App)      │
│  - SwiftUI Views                     │
│  - App Lifecycle                     │
│  - Platform-specific UI              │
└─────────────────┬───────────────────┘
                  │ depends on
                  ▼
         ┌────────────────┐
         │   PrismKit     │
         │  - UI Components│
         │  - Extensions   │
         └────────┬───────┘
                  │ depends on
                  ▼
         ┌────────────────┐
         │  PrismCore     │◄──────────┐
         │  - Protocols    │           │
         │  - Models       │           │ depends on
         │  - Services     │           │
         └─────────────────┘           │
                                ┌──────┴──────┐
                                │  PrismASR   │
                                │ - AsrEngine │
                                │ - Whisper   │
                                └─────────────┘
```

**规则**：
1. App 可依赖所有 Package
2. PrismKit 依赖 PrismCore（不依赖 PrismASR）
3. PrismASR 依赖 PrismCore（实现其协议）
4. PrismCore 不依赖任何内部 Package（纯协议与模型）
5. 禁止循环依赖

### 平台差异化处理

> **注**：App 层工程的平台差异化策略详见 **ADR-0006**（单工程双 Target + 条件编译）

**Package 层示例**（通过条件编译实现跨平台）：

```swift
// filepath: packages/PrismKit/Sources/PrismKit/FilePickerService.swift
#if os(iOS)
import UIKit

public final class FilePickerService {
    public func pickMediaFile() async -> URL? {
        // UIDocumentPickerViewController 实现
    }
}
#elseif os(macOS)
import AppKit

public final class FilePickerService {
    public func pickMediaFile() async -> URL? {
        // NSOpenPanel 实现
    }
}
#endif
```

**App 层示例**（通过 Target Membership 隔离）：
```
apps/PrismPlayer/Sources/
├── iOS/          # iOS Target 独占
│   └── MediaPickerView.swift
├── macOS/        # macOS Target 独占
│   └── MediaPickerView.swift
└── Shared/       # 两 Target 共享
    └── PlayerViewModel.swift
```

### 测试策略

1. **单元测试**：
   - 每个 Package 独立测试目标
   - Mock 对象统一放置 `Tests/Mocks/`
   - 金样本数据放置 `Tests/Fixtures/`

2. **协议契约测试**：
```swift
// filepath: packages/PrismCore/Tests/PrismCoreTests/AsrEngineContractTests.swift
protocol AsrEngineContractTests {
    var sut: AsrEngine { get }
    func testTranscribeReturnsSegments() async throws
    func testTranscribeWithInvalidDataThrows() async throws
}

// filepath: packages/PrismASR/Tests/PrismASRTests/WhisperBackendTests.swift
final class WhisperBackendTests: XCTestCase, AsrEngineContractTests {
    var sut: AsrEngine { WhisperCppBackend() }
    // 实现契约测试
}
```

3. **覆盖率收集**：
   - CI 中为每个 Package 生成独立覆盖率报告
   - 使用 `xcov` 或 `slather` 聚合报告

### 构建配置

#### Workspace Scheme
- `PrismPlayer-iOS-Debug`
- `PrismPlayer-iOS-Release`
- `PrismPlayer-macOS-Debug`
- `PrismPlayer-macOS-Release`

#### Package Scheme（自动生成）
- `PrismCore-Package`（供 CI 独立构建）
- `PrismASR-Package`
- `PrismKit-Package`

### 示例 Package.swift

```swift
// filepath: packages/PrismCore/Package.swift
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
            path: "Tests/PrismCoreTests",
            resources: [.process("Fixtures")]
        )
    ]
)
```

## 后果

### 正面影响

1. **开发效率**：
   - 模块可独立演进，减少团队协作冲突
   - 增量编译显著提升构建速度（预计 30-50%）
   - 清晰的依赖关系便于理解与维护

2. **测试质量**：
   - 模块级独立测试，覆盖率可量化
   - Mock 对象管理清晰
   - 契约测试保证接口一致性

3. **代码质量**：
   - 强制依赖方向，避免循环依赖
   - 模块边界清晰，职责分离
   - 符合 SOLID 原则

4. **生态兼容**：
   - 符合 Apple 官方推荐
   - 未来可发布为独立库
   - 便于集成其他 SPM 依赖

### 负面影响

1. **学习成本**：
   - 团队需要学习 SPM Manifest 语法
   - 初次配置 Workspace 较复杂

2. **工具支持**：
   - Xcode 索引可能较慢（>10 个 Package 时）
   - 某些第三方工具可能不完全支持 SPM

3. **调试体验**：
   - 跨 Package 调试时堆栈可能较深
   - 需要理解模块边界

### 缓解措施

1. **降低学习成本**：
   - 提供脚手架脚本（Sprint 0 Task 2）
   - 文档化常见配置模式
   - Code Review 时关注 Package 设计

2. **优化工具支持**：
   - 限制 Package 数量（≤5 个）
   - 使用 Xcode 15+ 改进的 SPM 支持
   - 配置 `.gitignore` 忽略索引缓存

3. **改善调试体验**：
   - 提供调试配置文档
   - 使用符号化日志与断点

## 遵从性

### 强制规则
1. ✅ 所有新增模块必须以 Swift Package 形式组织
2. ✅ 禁止 App Target 直接访问 Package 内部实现（仅通过 public API）
3. ✅ 每个 Package 必须有独立测试目标
4. ✅ Package 间依赖必须在 `Package.swift` 中显式声明
5. ✅ 禁止循环依赖

### 检查机制
- CI 中独立构建每个 Package（验证依赖正确性）
- 测试覆盖率报告按 Package 分离
- Code Review 检查依赖方向

## 相关决策

- **延续**：ADR-0002: DI 策略（协议式 DI 与 Package 边界配合）
- **延续**：ADR-0003: 双后端策略（PrismASR 支持多后端）
- **补充**：ADR-0006: 统一 App 工程结构（2025-10-28）
  - 细化 App 层工程组织方式（单工程双 Target vs 双独立工程）
  - 本 ADR 定义 Workspace + Package 整体架构
  - ADR-0006 定义 App 层内部结构与代码共享策略
- **替代**：无
- **冲突**：无

## 实施计划

### Sprint 0（当前）
- [x] 创建 Workspace 与基础目录结构
- [x] 配置 PrismCore/PrismASR/PrismKit Package
- [x] 创建 iOS/macOS App Target（已更新为单工程双 Target，见 ADR-0006）
- [x] 配置测试目标与 Mock 目录
- [x] 验证构建与依赖关系

### Sprint 1
- [ ] App 层工程迁移（执行 ADR-0006 迁移脚本）
- [ ] 补充核心协议与实现
- [ ] 完善测试覆盖率
- [ ] 优化构建配置

## 后续决策

**ADR-0006: 统一 App 工程结构**（2025-10-28）
- 问题：App 层采用双独立工程还是单工程双 Target？
- 决策：单工程双 Target（优化代码共享与维护成本）
- 影响：App 层目录结构调整，不影响 Package 架构
- 关系：本 ADR 定义整体架构，ADR-0006 细化 App 层实现

## 备注

- Package 数量控制在 5 个以内（当前 3 个）
- 如需新增 Package，需经过 Code Review 讨论
- 未来可考虑使用 Swift Package Plugin 自动化任务（如代码生成）

## 参考资料

- [Swift Package Manager](https://www.swift.org/package-manager/)
- [WWDC22: Meet Swift Package plugins](https://developer.apple.com/videos/play/wwdc2022/110359/)
- [WWDC23: Create Swift Package plugins](https://developer.apple.com/videos/play/wwdc2023/10185/)
- [Swift.org - Package Manager Evolution](https://github.com/apple/swift-evolution/blob/main/proposals/0303-swiftpm-extensible-build-tools.md)
- HLD §13（工程结构规范）
- PRD v0.2
- Sprint Plan v0.2
