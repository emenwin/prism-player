# Task-006: 安全/隐私与合规占位实现

## 任务概述

**类型**: 基础设施  
**故事点**: 2 SP  
**优先级**: P1（高）  
**负责人**: 待分配

## 背景

iOS 和 macOS 应用上架 App Store 需要满足严格的隐私和安全要求：
- 隐私清单（PrivacyInfo.xcprivacy）声明数据收集行为
- Info.plist 权限描述提供用户友好的说明
- 第三方依赖的许可证合规管理
- ASR 模型的许可证声明

本任务建立隐私与合规的基础框架，为后续功能开发提供指引。

## 任务目标

创建隐私清单、权限描述模板和许可证管理框架，确保应用符合 App Store 审核要求。

## 详细需求

### 1. 隐私清单（PrivacyInfo.xcprivacy）

为 iOS 和 macOS 应用创建隐私清单文件，声明：

#### 数据收集类型
- **不收集用户数据**（当前阶段）
- 未来可能收集：崩溃日志、性能指标（需用户同意）

#### API 使用声明
- 文件系统访问（媒体文件读取）
- 本地存储（SQLite 数据库）
- 麦克风访问（未来功能）

#### 第三方 SDK
- 声明所有第三方依赖及其数据处理行为
- GRDB：本地数据库，无网络传输
- Whisper.cpp / MLX：本地推理，无数据上传

### 2. Info.plist 权限描述

为需要的系统权限添加本地化描述：

| 权限 Key | 中文描述 | 英文描述 |
|---------|---------|---------|
| NSMicrophoneUsageDescription | 需要访问麦克风以录制音频并生成字幕 | Microphone access is needed to record audio and generate subtitles |
| NSFileProviderDomainUsageDescription | 需要访问文件以导入和播放视频 | File access is needed to import and play videos |
| NSAppleMusicUsageDescription | 需要访问媒体库以播放音频文件 | Media library access is needed to play audio files |

**注意**: 当前阶段仅添加描述占位，实际权限请求在功能实现时触发。

### 3. 第三方许可证清单

创建第三方依赖许可证管理框架：

```
docs/
└── licenses/
    ├── README.md              # 许可证管理说明
    ├── third-party.json       # 依赖许可证清单
    └── models/
        └── README.md          # ASR 模型许可证说明
```

#### 依赖清单结构（third-party.json）

```json
{
  "dependencies": [
    {
      "name": "GRDB.swift",
      "version": "6.29.0",
      "license": "MIT",
      "licenseUrl": "https://github.com/groue/GRDB.swift/blob/master/LICENSE",
      "purpose": "SQLite database wrapper"
    }
  ]
}
```

#### 模型许可证说明

为 ASR 模型创建许可证文档模板：
- Whisper 模型：Apache 2.0 / MIT（取决于具体模型）
- 自定义微调模型：需明确授权条款
- 商业模型：需购买许可证

### 4. 应用内许可证展示（占位）

在设置页面预留许可证展示入口：
- "关于"页面显示应用版本和开源许可
- "第三方许可证"列表页（占位）
- "模型许可证"说明页（占位）

## 完成标准

- ✅ iOS 和 macOS 应用的 PrivacyInfo.xcprivacy 文件
- ✅ Info.plist 权限描述（中英文本地化）
- ✅ 第三方许可证清单框架（docs/licenses/）
- ✅ 模型许可证管理文档
- ✅ 应用内展示入口占位（UI 占位）

## 交付物清单

### 1. 隐私清单文件

✅ 已完成：
- `Prism-xOS/apps/PrismPlayer-iOS/Resources/PrivacyInfo.xcprivacy`
- `Prism-xOS/apps/PrismPlayer-macOS/Resources/PrivacyInfo.xcprivacy`

包含以下 API 声明：
- 文件时间戳访问（C617.1）
- UserDefaults 访问（CA92.1）
- 磁盘空间访问（E174.1）
- 系统启动时间（35F9.1）

✅ 已完成：
## 任务信息

## 相关 TDD
- [tdd/iOS-macOS/hld-ios-macos-v0.2.md](../../../../tdd/iOS-macOS/hld-ios-macos-v0.2.md) — 约束：SwiftUI + MVVM，SwiftLint 严格模式，国际化无硬编码

## 相关 ADR
- [docs/adr/iOS-macOS/0001-multiplatform-architecture.md](../../../../adr/iOS-macOS/0001-multiplatform-architecture.md) — Accepted
- [docs/adr/iOS-macOS/0002-player-view-ui-stack.md](../../../../adr/iOS-macOS/0002-player-view-ui-stack.md) — Accepted
- [docs/adr/iOS-macOS/0003-sqlite-storage-solution.md](../../../../adr/iOS-macOS/0003-sqlite-storage-solution.md) — Accepted
- [docs/adr/iOS-macOS/0004-logging-metrics-strategy.md](../../../../adr/iOS-macOS/0004-logging-metrics-strategy.md) — Accepted
- [docs/adr/iOS-macOS/0005-testing-di-strategy.md](../../../../adr/iOS-macOS/0005-testing-di-strategy.md) — Accepted

## 定义完成（DoD）
- [ ] CI 通过（构建/测试/SwiftLint 严格模式）
- [ ] 无硬编码字符串（使用国际化）
- [ ] 文档/变更日志更新（PRD/TDD/ADR/Scrum）
- [ ] 关键路径测试覆盖与可观测埋点到位
- iOS Info.plist 添加 5 个权限描述
- macOS Info.plist 添加 6 个权限描述（含文件夹访问）

### 3. 本地化文本（Localizable.xcstrings）

- 设置页面文本（关于、许可证、隐私政策）
- 占位提示文本

### 4. 许可证文档

✅ 已完成：
```
docs/licenses/
├── README.md              # 许可证管理流程说明（90+ 行）
├── third-party.json       # 第三方依赖清单（GRDB, whisper.cpp, mlx-swift）
└── models/
    └── README.md          # 模型许可证指南（220+ 行）
```

### 5. 设置页面占位（UI）

✅ 已完成：
- `Prism-xOS/packages/PrismKit/Sources/PrismKit/Settings/SettingsView.swift`
- 包含 5 个视图：
  - `SettingsView`: 主设置页面
  - `AboutView`: 关于页面（应用信息）
  - `LicensesPlaceholderView`: 开源许可证占位
  - `ModelLicensesPlaceholderView`: 模型许可证占位
  - `PrivacyPolicyView`: 隐私政策展示

---

**任务状态**: ✅ 已完成  
**创建日期**: 2025-10-24  
**完成日期**: 2025-10-24

## 技术细节

### PrivacyInfo.xcprivacy 结构

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### Info.plist 权限配置

```xml
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) needs microphone access to record audio and generate subtitles</string>
```

**本地化支持**: 使用 InfoPlist.strings 实现多语言。

### 许可证合规检查

未来可集成自动化工具：
- **LicensePlist**: Swift Package Manager 依赖许可证生成
- **license-checker**: npm 依赖许可证检查（如有 web 组件）

## 验收标准

### 功能验收

1. ✅ **隐私清单完整性**
   - iOS 和 macOS 均有 PrivacyInfo.xcprivacy
   - 声明所有使用的受限 API
   - 明确标注不收集用户数据

2. ✅ **权限描述清晰性**
   - Info.plist 包含所有需要的权限描述
   - 描述语言用户友好，解释权限用途
   - 支持中英文本地化

3. ✅ **许可证文档完整性**
   - 第三方依赖清单准确
   - 模型许可证说明清晰
   - 许可证管理流程文档化

4. ✅ **UI 占位可访问**
   - 设置页面有许可证入口
   - 点击入口有占位提示（如"即将推出"）

### 合规验收

1. ✅ **App Store 审核要求**
   - PrivacyInfo.xcprivacy 符合最新规范
   - 权限描述符合 App Store 审核指南
   - 无隐藏的数据收集行为

2. ✅ **开源许可证合规**
   - MIT/Apache 2.0 许可证正确声明
   - GPL 等传染性许可证避免使用
   - 商业许可证明确标注

## 依赖关系

### 前置任务

- Task-002: 多平台工程脚手架（需要应用目录结构）
- Task-005: 数据存储（声明 GRDB 依赖许可证）

### 后续任务

- Sprint 1 所有功能开发（权限请求实现）
- Task-007: 指标与日志（合规数据收集）

## 参考资料

### Apple 官方文档

- [Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [App Store Review Guidelines - Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Requesting Permission](https://developer.apple.com/design/human-interface-guidelines/privacy)

### 许可证资源

- [Choose a License](https://choosealicense.com/)
- [SPDX License List](https://spdx.org/licenses/)
- [Open Source Initiative](https://opensource.org/licenses)

### 工具

- [LicensePlist](https://github.com/mono0926/LicensePlist) - Swift 依赖许可证生成器
- [SwiftLicensesKit](https://github.com/cybozu/LicenseList) - 应用内许可证展示

---

**任务状态**: 进行中  
**创建日期**: 2025-10-24  
**最后更新**: 2025-10-24
