# Task-002: 多平台工程脚手架

## 任务信息

- **Sprint**: Sprint 0
- **PBI**: 多平台工程脚手架（HLD §13）（3 SP）
- **优先级**: P0
- **状态**: Todo
- **负责人**: TBD
- **相关文档**: 
  - ADR-0001: 多平台工程架构
  - HLD §13: 工程结构
  - Sprint Plan v0.2: Sprint 0 Task 2

## 目标

搭建支持 iOS 17+ 和 macOS 14+ 的多平台工程，采用 Swift Package 模块化架构，为后续开发建立坚实基础。

## 技术方案

### 1. 工程目录结构

```
prism-player/
├── PrismPlayer.xcworkspace          # Workspace 聚合文件
├── .gitignore
├── README.md
├── apps/                             # 应用层
│   ├── PrismPlayer-iOS/
│   │   ├── PrismPlayer-iOS.xcodeproj
│   │   ├── Sources/
│   │   │   ├── PrismPlayerApp.swift
│   │   │   ├── ContentView.swift
│   │   │   └── Info.plist
│   │   └── Resources/
│   │       ├── Assets.xcassets
│   │       │   ├── AppIcon.appiconset/
│   │       │   └── AccentColor.colorset/
│   │       ├── Localizable.xcstrings   # String Catalog
│   │       └── PrivacyInfo.xcprivacy   # 隐私清单
│   └── PrismPlayer-macOS/
│       ├── PrismPlayer-macOS.xcodeproj
│       ├── Sources/
│       │   ├── PrismPlayerApp.swift
│       │   ├── ContentView.swift
│       │   └── Info.plist
│       └── Resources/
│           ├── Assets.xcassets
│           ├── Localizable.xcstrings
│           └── PrivacyInfo.xcprivacy
├── packages/                         # Swift Packages
│   ├── PrismCore/
│   │   ├── Package.swift
│   │   ├── README.md
│   │   ├── Sources/
│   │   │   └── PrismCore/
│   │   │       ├── Models/
│   │   │       │   └── .gitkeep
│   │   │       ├── Protocols/
│   │   │       │   └── .gitkeep
│   │   │       └── Services/
│   │   │           └── .gitkeep
│   │   └── Tests/
│   │       └── PrismCoreTests/
│   │           ├── PrismCoreTests.swift
│   │           └── Fixtures/
│   │               └── .gitkeep
│   ├── PrismASR/
│   │   ├── Package.swift
│   │   ├── README.md
│   │   ├── Sources/
│   │   │   └── PrismASR/
│   │   │       ├── AsrEngine.swift        # 协议定义（占位）
│   │   │       └── WhisperCppBackend.swift # 后端实现（占位）
│   │   └── Tests/
│   │       └── PrismASRTests/
│   │           ├── AsrEngineTests.swift
│   │           └── Mocks/
│   │               └── MockAsrEngine.swift
│   └── PrismKit/
│       ├── Package.swift
│       ├── README.md
│       ├── Sources/
│       │   └── PrismKit/
│       │       ├── Components/
│       │       │   └── .gitkeep
│       │       └── Extensions/
│       │           └── .gitkeep
│       └── Tests/
│           └── PrismKitTests/
│               └── PrismKitTests.swift
└── Tests/                            # 共享测试资源
    ├── Mocks/
    │   └── README.md
    └── Fixtures/
        └── README.md
```

### 2. Swift Package 配置

#### 2.1 PrismCore Package.swift

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
            path: "Tests/PrismCoreTests"
        )
    ]
)
```

#### 2.2 PrismASR Package.swift

```swift
// filepath: packages/PrismASR/Package.swift
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
```

#### 2.3 PrismKit Package.swift

```swift
// filepath: packages/PrismKit/Package.swift
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
```

### 3. iOS App 配置

#### 3.1 PrismPlayerApp.swift

```swift
// filepath: apps/PrismPlayer-iOS/Sources/PrismPlayerApp.swift
import SwiftUI

@main
struct PrismPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### 3.2 ContentView.swift（占位）

```swift
// filepath: apps/PrismPlayer-iOS/Sources/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("app.name")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("app.welcome")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
```

#### 3.3 Info.plist

```xml
<!-- filepath: apps/PrismPlayer-iOS/Sources/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
```

### 4. macOS App 配置

#### 4.1 PrismPlayerApp.swift

```swift
// filepath: apps/PrismPlayer-macOS/Sources/PrismPlayerApp.swift
import SwiftUI

@main
struct PrismPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1024, height: 768)
    }
}
```

#### 4.2 ContentView.swift（与 iOS 类似）

```swift
// filepath: apps/PrismPlayer-macOS/Sources/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("app.name")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("app.welcome")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    ContentView()
}
```

### 5. String Catalog 配置

#### 5.1 iOS Localizable.xcstrings

```json
{
  "sourceLanguage": "en",
  "strings": {
    "app.name": {
      "extractionState": "manual",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Prism Player"
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "Prism 播放器"
          }
        }
      }
    },
    "app.welcome": {
      "extractionState": "manual",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Welcome to Prism Player"
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "欢迎使用 Prism 播放器"
          }
        }
      }
    }
  },
  "version": "1.0"
}
```

### 6. Xcode Workspace 配置

#### 6.1 创建 Workspace

```bash
# 在项目根目录执行
cd /Users/jiang/Projects/prism-player

# 创建 Workspace（使用 Xcode 或命令行）
xed --create PrismPlayer.xcworkspace
```

#### 6.2 Workspace 文件结构（手动配置或脚本生成）

```xml
<!-- filepath: PrismPlayer.xcworkspace/contents.xcworkspacedata -->
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:apps/PrismPlayer-iOS/PrismPlayer-iOS.xcodeproj">
   </FileRef>
   <FileRef
      location = "group:apps/PrismPlayer-macOS/PrismPlayer-macOS.xcodeproj">
   </FileRef>
   <FileRef
      location = "group:packages/PrismCore">
   </FileRef>
   <FileRef
      location = "group:packages/PrismASR">
   </FileRef>
   <FileRef
      location = "group:packages/PrismKit">
   </FileRef>
</Workspace>
```

### 7. 占位代码示例

#### 7.1 PrismCore 协议占位

```swift
// filepath: packages/PrismCore/Sources/PrismCore/Protocols/.gitkeep
// 占位文件，后续添加协议定义
```

创建示例协议：

```swift
// filepath: packages/PrismCore/Sources/PrismCore/Models/AsrSegment.swift
import Foundation

/// ASR 识别结果片段
public struct AsrSegment: Identifiable, Codable, Sendable {
    public let id: UUID
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let confidence: Double?
    
    public init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        confidence: Double? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
    }
}
```

#### 7.2 PrismASR 协议占位

```swift
// filepath: packages/PrismASR/Sources/PrismASR/AsrEngine.swift
import Foundation
import PrismCore

/// ASR 引擎协议
public protocol AsrEngine: Sendable {
    /// 转写音频数据
    func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment]
}

/// ASR 配置选项
public struct AsrOptions: Sendable {
    public let language: String?
    public let enableTimestamps: Bool
    
    public init(language: String? = nil, enableTimestamps: Bool = true) {
        self.language = language
        self.enableTimestamps = enableTimestamps
    }
}
```

```swift
// filepath: packages/PrismASR/Sources/PrismASR/WhisperCppBackend.swift
import Foundation
import PrismCore

/// Whisper.cpp 后端实现（占位）
public final class WhisperCppBackend: AsrEngine {
    public init() {}
    
    public func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment] {
        // TODO: Sprint 1 实现
        return []
    }
}
```

#### 7.3 测试占位

```swift
// filepath: packages/PrismCore/Tests/PrismCoreTests/PrismCoreTests.swift
import XCTest
@testable import PrismCore

final class PrismCoreTests: XCTestCase {
    func testAsrSegmentCreation() {
        let segment = AsrSegment(
            startTime: 0.0,
            endTime: 5.0,
            text: "Hello, world!",
            confidence: 0.95
        )
        
        XCTAssertEqual(segment.text, "Hello, world!")
        XCTAssertEqual(segment.startTime, 0.0)
        XCTAssertEqual(segment.endTime, 5.0)
        XCTAssertEqual(segment.confidence, 0.95)
    }
}
```

```swift
// filepath: packages/PrismASR/Tests/PrismASRTests/Mocks/MockAsrEngine.swift
import Foundation
import PrismCore
@testable import PrismASR

/// Mock ASR 引擎（用于测试）
public final class MockAsrEngine: AsrEngine {
    public var transcribeResult: [AsrSegment] = []
    public var transcribeCalled = false
    
    public init() {}
    
    public func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment] {
        transcribeCalled = true
        return transcribeResult
    }
}
```

### 8. Xcode 项目配置

#### 8.1 iOS 项目设置

- **Target**: PrismPlayer-iOS
- **Deployment Target**: iOS 17.0
- **Supported Devices**: iPhone, iPad
- **Linked Frameworks**: 
  - PrismCore
  - PrismASR
  - PrismKit
- **Build Settings**:
  - `SWIFT_VERSION`: 5.9
  - `MARKETING_VERSION`: 0.1.0
  - `CURRENT_PROJECT_VERSION`: 1
  - `ENABLE_STRICT_CONCURRENCY_CHECKING`: YES

#### 8.2 macOS 项目设置

- **Target**: PrismPlayer-macOS
- **Deployment Target**: macOS 14.0
- **Linked Frameworks**: 
  - PrismCore
  - PrismASR
  - PrismKit
- **Build Settings**: 同 iOS

### 9. 自动化脚本（可选）

创建工程初始化脚本：

```bash
#!/bin/bash
# filepath: scripts/setup-workspace.sh

set -e

echo "🚀 Setting up Prism Player workspace..."

# 创建目录结构
mkdir -p apps/PrismPlayer-iOS/{Sources,Resources}
mkdir -p apps/PrismPlayer-macOS/{Sources,Resources}
mkdir -p packages/PrismCore/{Sources/PrismCore/{Models,Protocols,Services},Tests/PrismCoreTests/Fixtures}
mkdir -p packages/PrismASR/{Sources/PrismASR,Tests/PrismASRTests/Mocks}
mkdir -p packages/PrismKit/{Sources/PrismKit/{Components,Extensions},Tests/PrismKitTests}
mkdir -p Tests/{Mocks,Fixtures}

# 创建占位文件
touch packages/PrismCore/Sources/PrismCore/Models/.gitkeep
touch packages/PrismCore/Sources/PrismCore/Protocols/.gitkeep
touch packages/PrismCore/Sources/PrismCore/Services/.gitkeep

echo "✅ Workspace structure created!"
echo "📝 Next steps:"
echo "   1. Open PrismPlayer.xcworkspace in Xcode"
echo "   2. Add iOS and macOS projects to workspace"
echo "   3. Add Swift Packages to workspace"
echo "   4. Build and verify"
```

## 验收标准 (AC)

### 功能验收
- [ ] Xcode Workspace 可成功打开，所有引用正确
- [ ] iOS 17+ Simulator（至少 iPhone 15）构建成功
- [ ] macOS 14+ 本地构建成功
- [ ] PrismCore/ASR/Kit 三个 Package 可独立编译
- [ ] String Catalog 支持 zh-Hans 和 en-US，至少包含 2 个字符串
- [ ] 运行空白 SwiftUI App 显示 "Prism Player" 与欢迎文本
- [ ] 测试目标配置完成，可运行占位测试用例

### 代码质量
- [ ] 所有 Swift 文件遵循 SwiftLint 规范
- [ ] 无硬编码字符串，使用 String Catalog
- [ ] Package.swift 依赖关系正确（PrismCore 无依赖，ASR/Kit 依赖 Core）
- [ ] `.gitignore` 配置正确（排除 `.DS_Store`, `*.xcuserstate`, `DerivedData/` 等）

### 文档完整性
- [ ] 每个 Package 包含 README.md，说明职责与使用方式
- [ ] 根目录 README.md 包含工程结构说明
- [ ] 占位协议与模型包含文档注释

### 构建配置
- [ ] iOS 和 macOS Scheme 配置正确
- [ ] Test Scheme 可独立运行
- [ ] 支持 Debug 和 Release 配置

## 依赖

### 开发环境
- Xcode 15.0+
- macOS 14.0+（开发机）
- Swift 5.9+

### 外部依赖
- 无（本 Task 仅使用原生 Swift Package）

## 风险与缓解

### 风险 1: Swift Package 跨平台配置复杂
**影响**: 高  
**概率**: 中  
**缓解措施**:
- 参考 Apple 官方模板与文档
- 使用相对路径避免路径问题
- 在 Xcode 中逐步添加引用，验证每一步

### 风险 2: Workspace 引用路径问题
**影响**: 中  
**概率**: 低  
**缓解措施**:
- 使用 `group:` 相对路径
- 提供初始化脚本统一创建
- 文档化路径约定

### 风险 3: Xcode 索引慢或卡顿
**影响**: 低  
**概率**: 低  
**缓解措施**:
- 限制 Package 数量（当前 3 个）
- 清理 DerivedData（必要时）
- 使用 Xcode 15+ 改进的 SPM 支持

## 测试策略

### 单元测试
1. **PrismCore 测试**:
   - 测试 `AsrSegment` 模型创建与属性
   - 验证 Codable 序列化/反序列化

2. **PrismASR 测试**:
   - 测试 `MockAsrEngine` 可正确记录调用
   - 验证 `AsrOptions` 默认值

3. **PrismKit 测试**:
   - 占位测试（后续补充）

### 集成测试
- iOS App 启动测试（UI 测试框架）
- macOS App 启动测试

### 手动测试
- [ ] 在 iPhone Simulator 运行，验证 UI 显示
- [ ] 在 macOS 运行，验证窗口与 UI
- [ ] 切换语言（系统设置），验证本地化生效
- [ ] 在 Xcode 中切换 Scheme，验证构建

## 时间估算

- **目录结构与脚本**: 0.5 天
- **Package.swift 配置**: 0.5 天
- **iOS/macOS App 配置**: 0.5 天
- **String Catalog 与本地化**: 0.5 天
- **测试配置与占位用例**: 0.5 天
- **验证与文档**: 0.5 天

**总计**: 3 Story Points (~3 天，1 人)

## 实施步骤

### Step 1: 创建目录结构（0.5 天）
1. 创建 `apps/`, `packages/`, `Tests/` 目录
2. 为每个 Package 创建子目录（Sources/Tests）
3. 添加 `.gitkeep` 占位文件

### Step 2: 配置 Swift Packages（0.5 天）
1. 创建 `PrismCore/Package.swift`
2. 创建 `PrismASR/Package.swift`（依赖 PrismCore）
3. 创建 `PrismKit/Package.swift`（依赖 PrismCore）
4. 添加占位代码与测试

### Step 3: 创建 iOS App（0.5 天）
1. 使用 Xcode 创建 iOS App 项目
2. 配置 Deployment Target 为 iOS 17.0
3. 添加 SwiftUI 入口与占位 View
4. 配置 String Catalog
5. 添加 PrivacyInfo.xcprivacy

### Step 4: 创建 macOS App（0.5 天）
1. 使用 Xcode 创建 macOS App 项目
2. 配置 Deployment Target 为 macOS 14.0
3. 添加 SwiftUI 入口与占位 View
4. 配置 String Catalog
5. 添加 PrivacyInfo.xcprivacy

### Step 5: 配置 Workspace（0.5 天）
1. 创建 `PrismPlayer.xcworkspace`
2. 添加 iOS/macOS 项目引用
3. 添加三个 Swift Package 引用
4. 在 App Target 中链接 Packages
5. 配置 Scheme

### Step 6: 验证与测试（0.5 天）
1. 构建 iOS Target
2. 构建 macOS Target
3. 运行单元测试
4. 验证本地化
5. 清理警告与错误

## 交付物

### 代码
- [x] Xcode Workspace 文件
- [x] iOS App 项目（可运行）
- [x] macOS App 项目（可运行）
- [x] PrismCore Package（含占位协议）
- [x] PrismASR Package（含占位实现）
- [x] PrismKit Package（含占位组件）
- [x] 测试目标与 Mock 占位

### 文档
- [x] 各 Package 的 README.md
- [x] 根目录 README.md（工程结构说明）
- [x] 本 Task 设计文档

### 配置
- [x] `.gitignore`
- [x] String Catalog（zh-Hans/en-US）
- [x] PrivacyInfo.xcprivacy 占位

## 后续任务

- **Task-009**: 测试架构与 DI 策略定义（补充契约测试与 Mock 规范）
- **Sprint 1**: 补充核心业务逻辑与协议实现
- **Sprint 1**: 集成 whisper.cpp 依赖

## 参考资料

- [Swift Package Manager](https://www.swift.org/package-manager/)
- [Xcode Workspace Documentation](https://developer.apple.com/documentation/xcode/organizing-your-code-with-workspaces)
- [String Catalog Guide](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- ADR-0001: 多平台工程架构
- HLD §13: 工程结构
- Sprint Plan v0.2: Sprint 0

## 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2025-10-23 | v1.0 | 初始版本 | AI Agent |
