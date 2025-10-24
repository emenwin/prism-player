# Prism-xOS

Prism Player iOS、macOS 版本

音视频播放器，支持实时离线语音转文字字幕功能。

## 功能特性

- 🎬 本地视频/音频播放
- 🔤 实时离线 ASR 字幕生成
- 📱 iOS 17.0+ / macOS 14.0+ 支持
- 🌍 中英双语界面
- ♿️ 完整可访问性支持

## 工程结构

```
Prism-xOS/
├── PrismPlayer.xcworkspace          # Xcode Workspace
├── apps/                            # 应用目标
│   ├── PrismPlayer-iOS/            # iOS 应用
│   └── PrismPlayer-macOS/          # macOS 应用
├── packages/                        # Swift Packages
│   ├── PrismCore/                  # 核心业务逻辑
│   ├── PrismASR/                   # ASR 引擎封装
│   └── PrismKit/                   # UI 组件库
└── Tests/                          # 测试资源
    ├── Fixtures/                   # 测试数据
    └── Mocks/                      # Mock 对象
```

## 开发环境

### 系统要求

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### 依赖安装

```bash
# 安装 SwiftLint（代码规范检查）
brew install swiftlint

# 克隆仓库
git clone <repository-url>
cd prism-player/Prism-xOS

# 打开 Workspace
open PrismPlayer.xcworkspace
```

### 构建与运行

#### iOS

1. 选择 `PrismPlayer-iOS` Scheme
2. 选择 iOS Simulator（iPhone 15+）
3. 点击 Run (⌘R)

#### macOS

1. 选择 `PrismPlayer-macOS` Scheme
2. 选择 "My Mac"
3. 点击 Run (⌘R)

### 运行测试

```bash
# 运行所有测试
xcodebuild test -workspace PrismPlayer.xcworkspace \
  -scheme PrismPlayer-iOS -destination 'platform=iOS Simulator,name=iPhone 15'

# 或在 Xcode 中
# Product → Test (⌘U)
```

## 代码规范

### SwiftLint

项目采用 SwiftLint 严格模式，确保代码风格一致性。

#### 本地检查

```bash
# 在 Prism-xOS 目录下运行
cd Prism-xOS

# 检查所有文件
swiftlint lint

# 严格模式（CI 使用）
swiftlint lint --strict

# 自动修复部分问题
swiftlint --fix
```

#### 核心规则

- ✅ **禁止硬编码字符串**：所有用户可见文本必须使用 `String(localized:)` 国际化
- ✅ **禁止强制解包**：避免使用 `!`，优先使用 `if let`、`guard let` 或 `??`
- ✅ **行长度限制**：120 字符警告，150 字符错误
- ✅ **函数长度**：40 行警告，60 行错误
- ✅ **圈复杂度**：10 警告，20 错误

完整规则见 [`.swiftlint.yml`](.swiftlint.yml)

#### Xcode 集成

SwiftLint 已集成到 Xcode Build Phase，构建时自动检查。

#### CI 检查

每次 Push/PR 都会自动运行 SwiftLint 检查，必须通过才能合并。

### 代码风格

遵循 Swift 官方风格指南和移动端最佳实践：

```swift
// ✅ 正确：使用国际化
let title = String(localized: "player.title")

// ❌ 错误：硬编码字符串
let title = "播放器"

// ✅ 正确：安全解包
guard let url = URL(string: path) else { return }

// ❌ 错误：强制解包
let url = URL(string: path)!

// ✅ 正确：清晰的命名
func loadVideoFromLocalStorage(at url: URL) async throws -> Video

// ❌ 错误：模糊的命名
func load(u: String) -> Bool
```

### MVVM 架构

项目采用 MVVM 架构模式：

- **Model**: 业务数据模型（`PrismCore`）
- **View**: SwiftUI 视图
- **ViewModel**: 视图逻辑与状态管理

```
packages/PrismCore/
  └── Sources/
      ├── Models/          # 数据模型
      ├── Services/        # 业务服务
      └── ViewModels/      # 视图模型

apps/PrismPlayer-iOS/Sources/
  └── Views/               # SwiftUI 视图
```

## 国际化（i18n）

### 添加新文本

使用 String Catalog（`.xcstrings`）管理多语言：

1. 在代码中使用 `String(localized:)`：
   ```swift
   Text(String(localized: "welcome.message"))
   ```

2. Xcode 会自动提取到 `Localizable.xcstrings`

3. 在 String Catalog 中添加翻译：
   - `zh-Hans`：简体中文
   - `en-US`：英文

### 支持的语言

- 🇨🇳 简体中文（zh-Hans）
- 🇺🇸 英文（en-US）

## 贡献指南

详见项目根目录 [`CONTRIBUTING.md`](../CONTRIBUTING.md)

### 提交代码前检查清单

- [ ] 通过 SwiftLint 检查（`swiftlint lint --strict`）
- [ ] 所有测试通过（⌘U）
- [ ] 无硬编码字符串
- [ ] 新增文本已添加中英文翻译
- [ ] 提交信息符合 Conventional Commits 规范

## 许可证

详见 [`LICENSE`](../LICENSE)

---

**文档版本**: v1.0  
**最后更新**: 2025-10-24