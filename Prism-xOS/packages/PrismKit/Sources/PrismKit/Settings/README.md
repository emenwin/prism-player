# 安全、隐私与合规 / Security, Privacy & Compliance

本目录包含 Prism Player 的安全、隐私和许可证合规相关配置和文档。

This directory contains security, privacy, and license compliance configurations for Prism Player.

## 📋 任务概览 / Task Overview

**任务**: Sprint 0 - Task-006  
**状态**: ✅ 已完成 / Completed  
**日期**: 2025-10-24

## 🎯 已完成工作 / Completed Work

### 1. 隐私清单 / Privacy Manifests

为 iOS 和 macOS 应用创建了完整的 `PrivacyInfo.xcprivacy` 文件：

Created comprehensive `PrivacyInfo.xcprivacy` files for iOS and macOS apps:

**位置 / Location**:
- `Prism-xOS/apps/PrismPlayer-iOS/Resources/PrivacyInfo.xcprivacy`
- `Prism-xOS/apps/PrismPlayer-macOS/Resources/PrivacyInfo.xcprivacy`

**声明内容 / Declared Content**:
- ✅ 无跨应用跟踪 / No cross-app tracking
- ✅ 不收集用户数据 / No user data collection
- ✅ API 使用声明：
  - 文件时间戳访问 / File timestamp access (C617.1)
  - UserDefaults 读写 / UserDefaults access (CA92.1)
  - 磁盘空间查询 / Disk space query (E174.1)
  - 系统启动时间 / System boot time (35F9.1)

### 2. 权限描述 / Permission Descriptions

在 `Info.plist` 中添加了所有需要的权限描述：

Added all required permission descriptions in `Info.plist`:

| 权限 / Permission | iOS | macOS |
|------------------|-----|-------|
| 麦克风 / Microphone | ✅ | ✅ |
| 照片库 / Photo Library | ✅ | - |
| 媒体库 / Media Library | ✅ | ✅ |
| 语音识别 / Speech Recognition | ✅ | ✅ |
| 桌面文件夹 / Desktop Folder | - | ✅ |
| 文档文件夹 / Documents Folder | - | ✅ |
| 下载文件夹 / Downloads Folder | - | ✅ |

**特点 / Features**:
- ✅ 中英文双语支持 / Bilingual (Chinese & English)
- ✅ 用户友好描述 / User-friendly descriptions
- ✅ 符合 App Store 审核要求 / App Store compliant

### 3. 本地化字符串 / Localized Strings

在 `Localizable.xcstrings` 中添加了 20+ 新字符串：

Added 20+ new strings in `Localizable.xcstrings`:

**类别 / Categories**:
- 权限标题和描述 / Permission titles & descriptions
- 设置页面文本 / Settings page text
- 关于页面文本 / About page text
- 许可证页面文本 / License page text
- 隐私政策文本 / Privacy policy text

### 4. 许可证管理框架 / License Management Framework

创建了完整的许可证管理文档结构：

Created comprehensive license management documentation:

```
docs/licenses/
├── README.md              # 90+ 行管理指南
├── third-party.json       # 依赖清单（GRDB, whisper.cpp, mlx-swift）
└── models/
    └── README.md          # 220+ 行模型许可证指南
```

**文档内容 / Documentation Content**:
- ✅ 许可证合规原则 / License compliance principles
- ✅ 第三方依赖清单 / Third-party dependency list
- ✅ ASR 模型许可证说明 / ASR model license guidelines
- ✅ 自动化工具推荐 / Automation tool recommendations
- ✅ 常见问题解答 / FAQ

### 5. 设置页面 UI / Settings UI

创建了完整的设置页面占位实现：

Created complete settings page placeholder implementation:

**文件 / File**:
- `Prism-xOS/packages/PrismKit/Sources/PrismKit/Settings/SettingsView.swift`

**包含视图 / Included Views**:
1. **SettingsView**: 主设置页面 / Main settings page
   - 关于部分 / About section
   - 许可证部分 / Licenses section
   - 隐私部分 / Privacy section

2. **AboutView**: 关于页面 / About page
   - 应用名称和版本 / App name & version
   - 构建号 / Build number
   - GitHub 链接 / GitHub link

3. **LicensesPlaceholderView**: 开源许可证占位 / Open source licenses placeholder
   - "即将推出" 提示 / "Coming Soon" message

4. **ModelLicensesPlaceholderView**: 模型许可证占位 / Model licenses placeholder
   - ASR 模型许可证展示占位 / ASR model license display placeholder

5. **PrivacyPolicyView**: 隐私政策 / Privacy policy
   - 数据收集声明 / Data collection statement
   - 权限说明 / Permission descriptions
   - 本地处理承诺 / Local processing commitment

## 📊 统计数据 / Statistics

- **创建文件数 / Files Created**: 7
- **更新文件数 / Files Updated**: 4
- **新增代码行数 / Lines of Code**: ~850
- **文档行数 / Documentation Lines**: ~400
- **本地化字符串 / Localized Strings**: 40+ (中英文)
- **许可证声明 / License Declarations**: 3 dependencies

## ✅ 验收检查 / Acceptance Criteria

| 项目 / Item | 状态 / Status |
|------------|--------------|
| PrivacyInfo.xcprivacy 完整性 | ✅ |
| Info.plist 权限描述 | ✅ |
| 中英文本地化支持 | ✅ |
| 许可证文档框架 | ✅ |
| 第三方依赖清单 | ✅ |
| 模型许可证指南 | ✅ |
| 设置页面 UI 占位 | ✅ |
| App Store 审核合规 | ✅ |

## 🔮 未来工作 / Future Work

### Sprint 1+
- [ ] 实现完整的开源许可证展示页面
- [ ] 集成 LicensePlist 自动生成许可证
- [ ] 添加模型下载时的许可证同意流程
- [ ] 实现权限请求 UI（首次使用引导）

### Sprint 2+
- [ ] 添加隐私仪表盘（权限管理）
- [ ] 实现应用内许可证搜索功能
- [ ] 添加数据导出功能（GDPR 合规）
- [ ] 集成第三方审计工具

## 📚 参考资料 / References

### Apple 官方文档
- [Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Requesting Permission](https://developer.apple.com/design/human-interface-guidelines/privacy)

### 许可证资源
- [Choose a License](https://choosealicense.com/)
- [SPDX License List](https://spdx.org/licenses/)
- [Open Source Initiative](https://opensource.org/licenses)

### 工具推荐
- [LicensePlist](https://github.com/mono0926/LicensePlist) - Swift 依赖许可证生成
- [SwiftLicensesKit](https://github.com/cybozu/LicenseList) - 应用内许可证展示

## 🤝 贡献指南 / Contributing

更新许可证信息时：

When updating license information:

1. ✅ 检查许可证兼容性 / Check license compatibility
2. ✅ 更新 `third-party.json` / Update `third-party.json`
3. ✅ 添加本地化字符串 / Add localized strings
4. ✅ 更新设置页面 UI / Update settings UI
5. ✅ 提交前审查合规性 / Review compliance before commit

---

**维护者 / Maintainer**: Prism Player Team  
**最后更新 / Last Updated**: 2025-10-24  
**许可证 / License**: 参见 [许可证文档](../docs/licenses/README.md)
