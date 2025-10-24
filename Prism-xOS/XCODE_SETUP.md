# Prism Player 工程配置指南

本文档指导如何在 Xcode 中完成 Prism Player 多平台工程的配置。

## 前置条件

- macOS 14.0+
- Xcode 15.0+
- 已完成目录结构与源代码文件创建

## 工程结构概览

```
Prism-xOS/
├── PrismPlayer.xcworkspace (待创建)
├── apps/
│   ├── PrismPlayer-iOS/ (已有源码，待创建 .xcodeproj)
│   └── PrismPlayer-macOS/ (已有源码，待创建 .xcodeproj)
└── packages/
    ├── PrismCore/ (Swift Package, 已完成)
    ├── PrismASR/ (Swift Package, 已完成)
    └── PrismKit/ (Swift Package, 已完成)
```

## Step 1: 创建 iOS App 项目

1. 打开 Xcode
2. File → New → Project
3. 选择 **iOS** → **App**
4. 配置项目：
   - **Product Name**: `PrismPlayer-iOS`
   - **Team**: 选择你的开发团队
   - **Organization Identifier**: `com.prismplayer`（或你的标识符）
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Storage**: 不勾选 Core Data
   - **Include Tests**: 勾选
5. 保存位置：选择 `Prism-xOS/apps/PrismPlayer-iOS/` 目录
6. 创建后，删除 Xcode 自动生成的文件（保留已有的源码）

### 配置 iOS Target

#### Build Settings
- **Product Name**: `Prism Player`
- **Bundle Identifier**: `com.prismplayer.ios`
- **Marketing Version**: `0.1.0`
- **Current Project Version**: `1`
- **iOS Deployment Target**: `17.0`
- **Swift Language Version**: `Swift 5`
- **Enable Strict Concurrency Checking**: `Yes`

#### Info.plist
- 使用已创建的 `Sources/Info.plist`
- 在 Build Settings 中设置 `Info.plist File` 路径为 `Sources/Info.plist`

#### 添加 Resources
1. 在 Project Navigator 中，选择 `PrismPlayer-iOS` Target
2. Build Phases → Copy Bundle Resources
3. 添加：
   - `Resources/Assets.xcassets`
   - `Resources/Localizable.xcstrings`
   - `Resources/PrivacyInfo.xcprivacy`

#### 链接 Swift Packages
1. 选择 `PrismPlayer-iOS` Target
2. General → Frameworks, Libraries, and Embedded Content
3. 点击 `+` → Add Other → Add Package Dependency (Local)
4. 添加：
   - `../../packages/PrismCore`
   - `../../packages/PrismASR`
   - `../../packages/PrismKit`
5. 选择 `PrismCore`, `PrismASR`, `PrismKit` 库

## Step 2: 创建 macOS App 项目

1. 打开 Xcode
2. File → New → Project
3. 选择 **macOS** → **App**
4. 配置项目：
   - **Product Name**: `PrismPlayer-macOS`
   - **Team**: 选择你的开发团队
   - **Organization Identifier**: `com.prismplayer`
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Storage**: 不勾选 Core Data
   - **Include Tests**: 勾选
5. 保存位置：选择 `Prism-xOS/apps/PrismPlayer-macOS/` 目录
6. 创建后，删除 Xcode 自动生成的文件（保留已有的源码）

### 配置 macOS Target

#### Build Settings
- **Product Name**: `Prism Player`
- **Bundle Identifier**: `com.prismplayer.macos`
- **Marketing Version**: `0.1.0`
- **Current Project Version**: `1`
- **macOS Deployment Target**: `14.0`
- **Swift Language Version**: `Swift 5`
- **Enable Strict Concurrency Checking**: `Yes`

#### Info.plist
- 使用已创建的 `Sources/Info.plist`
- 在 Build Settings 中设置 `Info.plist File` 路径为 `Sources/Info.plist`

#### 添加 Resources
同 iOS，添加相同的资源文件。

#### 链接 Swift Packages
同 iOS，添加相同的 Package 依赖。

## Step 3: 创建 Workspace

1. 关闭所有打开的 Xcode 项目
2. File → New → Workspace
3. 名称：`PrismPlayer`
4. 保存位置：`Prism-xOS/` 目录

### 添加项目到 Workspace

1. 在 Workspace Navigator 中，点击左下角 `+` 或右键 → Add Files to "PrismPlayer"
2. 依次添加：
   - `apps/PrismPlayer-iOS/PrismPlayer-iOS.xcodeproj`
   - `apps/PrismPlayer-macOS/PrismPlayer-macOS.xcodeproj`
   - `packages/PrismCore` (作为 Package)
   - `packages/PrismASR` (作为 Package)
   - `packages/PrismKit` (作为 Package)

### Workspace 结构

完成后，Workspace 应显示：
```
PrismPlayer.xcworkspace
├── PrismPlayer-iOS
├── PrismPlayer-macOS
├── PrismCore
├── PrismASR
└── PrismKit
```

## Step 4: 配置 Schemes

### iOS Scheme
1. Product → Scheme → Manage Schemes
2. 确保 `PrismPlayer-iOS` Scheme 存在
3. 编辑 Scheme：
   - **Build**: 勾选 Run、Test、Profile、Analyze、Archive
   - **Test**: 添加 `PrismPlayer-iOSTests` 目标
   - **Run**: Executable 设为 `PrismPlayer-iOS.app`

### macOS Scheme
同 iOS，创建并配置 `PrismPlayer-macOS` Scheme。

### Package Schemes
Swift Packages 会自动创建测试 Schemes：
- `PrismCore-Package`
- `PrismASR-Package`
- `PrismKit-Package`

## Step 5: 验证构建

### 构建 iOS Target
1. 选择 `PrismPlayer-iOS` Scheme
2. 选择 Simulator（iPhone 15 或更新）
3. 点击 Run (⌘R)
4. 应看到欢迎界面显示 "Prism Player" 和 "Welcome to Prism Player"

### 构建 macOS Target
1. 选择 `PrismPlayer-macOS` Scheme
2. 选择 "My Mac"
3. 点击 Run (⌘R)
4. 应看到窗口显示欢迎界面

### 运行单元测试
1. 选择任意 Scheme
2. Product → Test (⌘U)
3. 所有测试应通过

## Step 6: 配置 SwiftLint（可选，Task-003）

将在 Task-003 中配置 SwiftLint，此处暂不处理。

## 常见问题

### Q: Package 依赖无法解析
A: 
1. File → Packages → Reset Package Caches
2. 关闭 Xcode，删除 `~/Library/Developer/Xcode/DerivedData/PrismPlayer-*`
3. 重新打开 Workspace

### Q: "No such module 'PrismCore'" 错误
A:
1. 确保 Package 已添加到 Target 的 Frameworks
2. 确保 Package 路径正确（使用相对路径）
3. Clean Build Folder (⌘⇧K) 后重新构建

### Q: String Catalog 本地化不生效
A:
1. 在 Simulator/Device 中切换系统语言
2. 确保 `Localizable.xcstrings` 已添加到 Copy Bundle Resources
3. 检查 Base Localization 和 Development Language 设置

## 验收检查清单

- [x] iOS 项目可成功构建并运行
- [x] macOS 项目可成功构建并运行
- [x] 所有 Swift Packages 可独立构建
- [x] 单元测试全部通过
- [x] 字符串本地化生效（中文/英文）
- [x] Workspace 包含所有项目和 Packages
- [x] 无编译警告或错误

## 下一步

完成本配置后，继续执行：
- **Task-003**: 代码规范与质量基线（SwiftLint）
- **Task-004**: 构建与 CI 基线
- **Sprint 1**: 核心功能开发

---

**文档版本**: v1.0  
**最后更新**: 2025-10-24
