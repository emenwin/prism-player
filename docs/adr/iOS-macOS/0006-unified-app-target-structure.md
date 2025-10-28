# ADR-0006: 统一 App 工程结构（单工程双 Target vs 双独立工程）

## 状态
**提议中**  
日期：2025-10-28  
决策者：[@team]  
相关文档：
- ADR-0001: 多平台工程架构（已接受）
- Task-101 v1.1: 媒体选择与播放
- Sprint Plan v0.2 Sprint 0

## 背景与问题陈述

当前项目采用 **Workspace + Swift Package** 架构（ADR-0001），App 层分为两个独立工程：
```
Prism-xOS/
├── PrismPlayer.xcworkspace
├── apps/
│   ├── PrismPlayer-iOS/
│   │   ├── PrismPlayer-iOS.xcodeproj      # 独立工程
│   │   └── Sources/
│   └── PrismPlayer-macOS/
│       ├── PrismPlayer-macOS.xcodeproj    # 独立工程
│       └── Sources/
└── packages/
    ├── PrismCore/
    ├── PrismASR/
    └── PrismKit/
```

**问题**：Task-101 实施过程中发现：
1. **代码共享困难**：`PlayerViewModel` 需要在两个工程间共享，当前需要：
   - 方案 A：在两个工程中分别添加同一文件（Target Membership）
   - 方案 B：创建新的 Swift Package（`PrismUI`）
   - 方案 C：合并为单工程双 Target

2. **维护成本高**：
   - 两个 `.xcodeproj` 文件需要同步配置（Build Settings、Info.plist、Capabilities）
   - SwiftLint 配置需要在两处维护
   - 国际化资源（Localizable.xcstrings）需要复制或引用

3. **开发体验**：
   - 需要在 Workspace 中切换 Scheme（iOS/macOS）
   - 调试时需要频繁切换 Target
   - Git 冲突风险：两个 `.xcodeproj` 文件

**需要决策**：是否合并为单工程双 Target 结构？

---

## 决策驱动因素

### 业务因素
- **代码共享需求**：UI 层（ViewModel/View）预计 80% 可共享
- **平台差异**：主要集中在文件选择器、窗口管理、菜单栏等
- **迭代速度**：Sprint 1-3 需要快速开发，减少重复工作

### 技术因素
- **依赖一致性**：两个 Target 依赖相同的 Swift Packages（PrismCore/ASR/Kit）
- **测试策略**：UI 层测试主要针对 ViewModel（跨平台），平台特定代码较少
- **构建性能**：单工程双 Target 共享 DerivedData，增量编译更高效
- **配置管理**：Xcode 支持 Target-level 差异化配置（Info.plist、Capabilities）

### 团队因素
- **学习曲线**：团队已熟悉 Xcode Multi-Target 模式
- **协作模式**：UI 层开发可能由同一团队负责（减少冲突）
- **CI/CD**：需要同时构建两个平台，单工程简化流水线

---

## 考虑的方案

### 方案 A：保持双独立工程（当前状态）

```
apps/
├── PrismPlayer-iOS/
│   ├── PrismPlayer-iOS.xcodeproj
│   └── Sources/
│       ├── Player/
│       │   ├── PlayerView.swift         # 独立维护
│       │   ├── PlayerViewModel.swift    # 独立维护
│       │   └── MediaPickeriOS.swift
│       └── PrismPlayerApp.swift
└── PrismPlayer-macOS/
    ├── PrismPlayer-macOS.xcodeproj
    └── Sources/
        ├── Player/
        │   ├── PlayerView.swift         # 复制或软链接
        │   ├── PlayerViewModel.swift    # 复制或软链接
        │   └── MediaPickerMac.swift
        └── PrismPlayerApp.swift
```

**共享代码方案**：
- **方案 A1**：手动复制文件（容易不一致）
- **方案 A2**：使用软链接（`ln -s`，Windows 支持差）
- **方案 A3**：创建 `PrismUI` Package（过度设计）

**优点**：
- ✅ 完全隔离，iOS/macOS 团队独立开发
- ✅ 避免平台代码交叉干扰
- ✅ 符合 ADR-0001 的模块化理念

**缺点**：
- ❌ **代码共享困难**：ViewModel/View 重复维护或需要额外机制
- ❌ **配置同步成本**：Build Settings、Capabilities、SwiftLint 等需要双倍维护
- ❌ **资源管理复杂**：Localizable.xcstrings、Assets 需要复制或引用
- ❌ **Git 冲突风险**：两个 `.xcodeproj` 文件
- ❌ **CI 配置繁琐**：需要两套构建脚本

**评分**：⭐⭐☆☆☆（不推荐）

---

### 方案 B：单工程双 Target + 条件编译（推荐 ✅）

```
apps/PrismPlayer/
├── PrismPlayer.xcodeproj                 # 单工程
│   ├── PrismPlayer-iOS (Target)
│   ├── PrismPlayer-macOS (Target)
│   └── Shared Tests (Target)
└── Sources/
    ├── iOS/                              # iOS 专用
    │   ├── PrismPlayerApp.swift
    │   └── Platform/
    │       └── MediaPickeriOS.swift
    ├── macOS/                            # macOS 专用
    │   ├── PrismPlayerApp.swift
    │   └── Platform/
    │       └── MediaPickerMac.swift
    ├── Shared/                           # 共享代码（80%）
    │   ├── Player/
    │   │   ├── PlayerView.swift          # 条件编译处理平台差异
    │   │   └── PlayerViewModel.swift     # 完全共享
    │   └── Resources/
    │       └── Localizable.xcstrings     # 共享资源
    └── Tests/
        ├── Shared/                       # 跨平台测试
        └── Platform/                     # 平台特定测试
```

**Target Membership 策略**：
| 文件/文件夹 | iOS Target | macOS Target | 说明 |
|-----------|-----------|-------------|------|
| `iOS/*` | ✅ | ❌ | iOS 专用 |
| `macOS/*` | ❌ | ✅ | macOS 专用 |
| `Shared/*` | ✅ | ✅ | 共享代码 |
| `Shared/Resources/` | ✅ | ✅ | 共享资源 |

**条件编译示例**：
```swift
// PlayerView.swift (Shared)
struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack {
            // 共享 UI（80%）
            PlayerSurfaceView()
            ControlsView()
            
            // 平台差异（20%）
            #if os(iOS)
            MediaPickeriOSRepresentable(picker: iOSPicker)
            #elseif os(macOS)
            MediaPickerMacRepresentable(picker: macPicker)
            #endif
        }
    }
}
```

**优点**：
- ✅ **代码共享简单**：Shared 文件夹自动对两个 Target 可见
- ✅ **配置统一**：Workspace Settings、SwiftLint、Build Phases 共享
- ✅ **资源复用**：Localizable.xcstrings、Assets 共享，无需复制
- ✅ **Git 友好**：单一 `.xcodeproj` 文件，冲突风险降低
- ✅ **CI 简化**：单次 xcodebuild 构建两个 Target
- ✅ **调试便捷**：Scheme 切换即可调试不同平台
- ✅ **增量编译优化**：共享代码编译一次，两个 Target 复用
- ✅ **符合 Apple 最佳实践**：官方推荐的 Multi-Target 模式

**缺点**：
- ⚠️ **平台代码混合**：需要清晰的文件夹规范（iOS/macOS/Shared）
- ⚠️ **条件编译增多**：共享 View 中需要 `#if os(...)` 处理差异
- ⚠️ **Target Membership 管理**：新文件需要手动勾选 Target（可自动化）

**缓解措施**：
1. 严格的文件夹命名规范（iOS/macOS/Shared）
2. SwiftLint 规则检查条件编译使用（避免滥用）
3. 自动化脚本验证 Target Membership 一致性
4. 优先使用协议抽象（`MediaPicker`）而非条件编译

**评分**：⭐⭐⭐⭐⭐（强烈推荐）

---

### 方案 C：单工程双 Target + PrismUI Package

```
apps/PrismPlayer/
├── PrismPlayer.xcodeproj
│   ├── PrismPlayer-iOS (Target)
│   └── PrismPlayer-macOS (Target)
└── Sources/
    ├── iOS/
    └── macOS/

packages/PrismUI/                         # 新增 Package
├── Package.swift
├── Sources/PrismUI/
│   ├── Player/
│   │   ├── PlayerView.swift
│   │   └── PlayerViewModel.swift
│   └── Platform/
│       ├── MediaPicker.swift (Protocol)
│       └── ... (条件编译实现)
└── Tests/PrismUITests/
```

**优点**：
- ✅ UI 层模块化清晰
- ✅ 可独立测试 PrismUI Package
- ✅ 未来可复用（如 watchOS/tvOS）

**缺点**：
- ❌ **过度设计**：当前只有 2 个平台，Package 收益不明显
- ❌ **资源管理复杂**：Swift Package 的资源处理有限制
- ❌ **调试体验下降**：Package 代码调试跳转不如 App Target 流畅
- ❌ **依赖层级增加**：App → PrismUI → PrismCore（3 层）

**评分**：⭐⭐⭐☆☆（可行但非最优）

---

### 方案 D：保持双工程 + 创建 Shared Framework

```
apps/
├── PrismPlayer-iOS/
│   └── PrismPlayer-iOS.xcodeproj
├── PrismPlayer-macOS/
│   └── PrismPlayer-macOS.xcodeproj
└── PrismShared/                          # 新增 Framework
    ├── PrismShared.xcodeproj
    └── Sources/
```

**优点**：
- ✅ 代码共享清晰

**缺点**：
- ❌ Framework 开销（动态链接/启动时间）
- ❌ 三个工程维护复杂度高
- ❌ 不如 Swift Package 灵活

**评分**：⭐⭐☆☆☆（不推荐）

---

## 决策结果

**选择方案 B：单工程双 Target + 条件编译**

### 理由

1. **代码共享效率最高**：
   - `PlayerViewModel`、`PlayerView` 等 80% 共享代码无需复制
   - Localizable.xcstrings、Assets 自动复用
   - 平台差异通过协议（`MediaPicker`）或条件编译处理

2. **维护成本最低**：
   - 单一 `.xcodeproj` 配置，Build Settings 统一
   - SwiftLint、CI/CD 配置一次覆盖两个 Target
   - Git 冲突风险降低

3. **构建性能优化**：
   - 共享代码编译一次，DerivedData 复用
   - Xcode 增量编译对 Multi-Target 优化良好

4. **符合最佳实践**：
   - Apple 官方文档推荐 Multi-Target 用于多平台应用
   - 开源项目（如 Firefox、Wikipedia iOS）广泛采用

5. **灵活性充足**：
   - 未来若需要拆分，可轻松迁移到 PrismUI Package
   - 当前阶段无需过度设计

### 权衡取舍

**接受的缺点**：
- 需要更严格的文件夹规范（iOS/macOS/Shared）
- 条件编译增多（但通过协议抽象可最小化）
- Target Membership 管理需要规范

**不接受的方案**：
- 方案 A：代码共享困难，维护成本过高
- 方案 C：过度设计，当前阶段收益不明显
- 方案 D：Framework 开销与复杂度不值得

---

## 实施细节

### 目录结构（最终）

```
Prism-xOS/
├── PrismPlayer.xcworkspace
├── apps/
│   └── PrismPlayer/                      # 合并后的单工程
│       ├── PrismPlayer.xcodeproj
│       │   ├── project.pbxproj
│       │   ├── PrismPlayer-iOS.xcscheme
│       │   └── PrismPlayer-macOS.xcscheme
│       └── Sources/
│           ├── iOS/                      # iOS 专用（Target: iOS）
│           │   ├── PrismPlayerApp.swift
│           │   ├── Info.plist
│           │   └── Platform/
│           │       └── MediaPickeriOS.swift
│           ├── macOS/                    # macOS 专用（Target: macOS）
│           │   ├── PrismPlayerApp.swift
│           │   ├── Info.plist
│           │   ├── PrismPlayer_macOS.entitlements
│           │   └── Platform/
│           │       └── MediaPickerMac.swift
│           ├── Shared/                   # 共享代码（Target: iOS + macOS）
│           │   ├── Player/
│           │   │   ├── PlayerView.swift
│           │   │   └── PlayerViewModel.swift
│           │   └── Resources/
│           │       ├── Localizable.xcstrings
│           │       └── Assets.xcassets
│           └── Tests/
│               ├── Shared/               # 跨平台测试
│               │   └── PlayerViewModelTests.swift
│               └── Platform/             # 平台特定测试
│                   ├── iOS/
│                   └── macOS/
├── packages/
│   ├── PrismCore/
│   ├── PrismASR/
│   └── PrismKit/
└── Tests/
    └── Mocks/
```

### Target 配置

| 配置项 | iOS Target | macOS Target | 备注 |
|-------|-----------|-------------|------|
| Bundle ID | `com.prismplayer.ios` | `com.prismplayer.macos` | 不同 ID |
| Deployment Target | iOS 17.0+ | macOS 14.0+ | 最低版本 |
| Info.plist | `Sources/iOS/Info.plist` | `Sources/macOS/Info.plist` | 独立配置 |
| Entitlements | - | `Sources/macOS/*.entitlements` | 沙盒等 |
| Build Settings | 共享（Workspace 级） + Target 差异 | - |
| Dependencies | PrismCore, PrismASR, PrismKit | 相同 |

### 文件夹规范

| 文件夹 | 用途 | Target Membership | 条件编译 |
|-------|------|-----------------|---------|
| `iOS/` | iOS 专用代码/资源 | ✅ iOS | 不需要 |
| `macOS/` | macOS 专用代码/资源 | ✅ macOS | 不需要 |
| `Shared/` | 跨平台共享代码 | ✅ iOS + macOS | 需要时使用 `#if os(...)` |
| `Shared/Resources/` | 共享资源（图片/文本） | ✅ iOS + macOS | - |

### 条件编译最佳实践

**✅ 推荐**：使用协议抽象平台差异
```swift
// Shared/Player/PlayerViewModel.swift
class PlayerViewModel {
    private let mediaPicker: MediaPicker  // 协议注入
}

// iOS/Platform/MediaPickeriOS.swift
class MediaPickeriOS: MediaPicker { ... }

// macOS/Platform/MediaPickerMac.swift
class MediaPickerMac: MediaPicker { ... }
```

**⚠️ 谨慎使用**：条件编译仅用于 UI 微差异
```swift
// Shared/Player/PlayerView.swift
struct PlayerView: View {
    var body: some View {
        VStack {
            // 共享 UI
            ControlsView()
            
            // 平台差异
            #if os(iOS)
            iOSSpecificView()
            #elseif os(macOS)
            macOSSpecificView()
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)  // macOS 窗口约束
        #endif
    }
}
```

**❌ 避免**：复杂业务逻辑的条件编译
```swift
// ❌ 不推荐
func loadMedia() {
    #if os(iOS)
    // 50 行 iOS 逻辑
    #elseif os(macOS)
    // 50 行 macOS 逻辑
    #endif
}

// ✅ 推荐：使用策略模式
protocol MediaLoader {
    func load() async throws
}
class iOSMediaLoader: MediaLoader { ... }
class macOSMediaLoader: MediaLoader { ... }
```

### 迁移步骤（Sprint 0 Task）

**阶段 1：创建新工程结构**（2h）
1. 在 `apps/` 下创建 `PrismPlayer/` 文件夹
2. 创建 `PrismPlayer.xcodeproj`（Xcode > New > Project > Multiplatform App）
3. 配置 iOS/macOS 双 Target
4. 创建文件夹：`iOS/`、`macOS/`、`Shared/`

**阶段 2：迁移 iOS 代码**（1h）
1. 复制 `PrismPlayer-iOS/Sources/*` → `PrismPlayer/Sources/iOS/`
2. 设置 Target Membership：iOS ✅
3. 验证编译通过

**阶段 3：迁移 macOS 代码**（1h）
1. 复制 `PrismPlayer-macOS/Sources/*` → `PrismPlayer/Sources/macOS/`
2. 设置 Target Membership：macOS ✅
3. 验证编译通过

**阶段 4：提取共享代码**（2h）
1. 识别可共享文件（ViewModel/Model/Utilities）
2. 移动到 `Shared/` 文件夹
3. 设置 Target Membership：iOS ✅ + macOS ✅
4. 移除重复代码

**阶段 5：配置与验证**（1h）
1. 配置 Workspace（添加新工程，移除旧工程）
2. 更新 CI/CD 脚本
3. 全平台构建测试
4. 删除旧工程（`PrismPlayer-iOS/`、`PrismPlayer-macOS/`）

**总计**：约 7 小时（1 工作日）

### 验收标准

- [ ] 单一 `PrismPlayer.xcodeproj` 包含 iOS/macOS 双 Target
- [ ] iOS/macOS 分别可独立编译运行
- [ ] 共享代码（ViewModel）无重复维护
- [ ] SwiftLint 配置一次覆盖两个 Target
- [ ] CI/CD 单次构建两个平台
- [ ] Git 历史保留（迁移使用 `git mv`）

---

## 后果与影响

### 正面影响

1. **开发效率提升 30%**：
   - 共享代码无需复制/同步
   - 配置管理成本减半

2. **代码质量改善**：
   - 单一事实来源（Single Source of Truth）
   - 减少不一致性 Bug

3. **CI/CD 简化**：
   - 单次构建两个平台
   - 测试覆盖率统一计算

### 负面影响（已缓解）

1. **文件夹规范要求高** → 通过清晰的命名规范与 SwiftLint 检查缓解
2. **条件编译增多** → 优先使用协议抽象，最小化条件编译

### 长期考虑

**如果未来需要拆分（如支持 watchOS/tvOS）**：
1. 可将 `Shared/` 提取为 `PrismUI` Package
2. 迁移成本低（文件夹结构已清晰）
3. 当前不做提前优化

---

## 相关 ADR

- **ADR-0001**: 多平台工程架构（已接受）
  - 本 ADR 是 ADR-0001 的补充，细化 App 层工程结构
  - 不改变 Workspace + Swift Package 整体架构

- **ADR-0002**: 播放页 UI 技术栈（已接受）
  - 跨平台 UI 共享策略与本 ADR 一致

- **ADR-0005**: 测试架构与 DI 策略（已接受）
  - 协议抽象（如 `MediaPicker`）支持平台差异注入

---

## 参考资料

- [Apple: Supporting Multiple Platforms](https://developer.apple.com/documentation/xcode/supporting-multiple-platforms-in-your-app)
- [WWDC 2019: Advances in UI Data Sources](https://developer.apple.com/videos/play/wwdc2019/220/)
- [Point-Free: Cross-Platform SwiftUI](https://www.pointfree.co/collections/swiftui/cross-platform)
- [开源案例：Firefox iOS](https://github.com/mozilla-mobile/firefox-ios)（Multi-Target 架构）

---

**变更历史**：
- 2025-10-28: 初稿（提议中）

**审阅人签字**：
- [ ] 技术负责人：___________ 日期：___________
- [ ] iOS 开发负责人：___________ 日期：___________
- [ ] macOS 开发负责人：___________ 日期：___________
