# 许可证管理 / License Management

本目录管理 Prism Player 的第三方依赖和 ASR 模型的许可证信息。

This directory manages third-party dependencies and ASR model licenses for Prism Player.

## 目录结构 / Directory Structure

```
docs/licenses/
├── README.md              # 许可证管理说明
├── third-party.json       # 第三方依赖许可证清单
└── models/
    └── README.md          # ASR 模型许可证指南
```

## 第三方依赖 / Third-Party Dependencies

所有第三方依赖的许可证信息记录在 `third-party.json` 中。

All third-party dependency licenses are recorded in `third-party.json`.

### 许可证合规原则 / License Compliance Principles

1. **MIT / Apache 2.0 / BSD**: ✅ 允许使用，需在应用内展示许可证
2. **GPL / LGPL**: ⚠️ 谨慎使用，避免传染性影响
3. **商业许可**: 💰 需购买授权，记录许可证密钥
4. **未知许可**: ❌ 禁止使用，直到许可证明确

### 更新流程 / Update Process

1. **添加新依赖**:
   - 在 `third-party.json` 中添加记录
   - 检查许可证兼容性
   - 更新应用内许可证展示页面

2. **升级依赖版本**:
   - 检查新版本许可证是否变化
   - 更新 `third-party.json` 中的版本号
   - 如许可证变化，重新评估兼容性

3. **移除依赖**:
   - 从 `third-party.json` 中删除记录
   - 清理应用内许可证展示页面

### 自动化工具 / Automation Tools

未来可集成以下工具自动生成许可证清单：

- [LicensePlist](https://github.com/mono0926/LicensePlist): Swift Package Manager 依赖许可证生成
- [SwiftLicensesKit](https://github.com/cybozu/LicenseList): 应用内许可证展示

```bash
# 使用 LicensePlist 生成许可证清单
brew install mono0926/license-plist/license-plist
license-plist --output-path ./Settings.bundle
```

## ASR 模型许可证 / ASR Model Licenses

参见 [`models/README.md`](models/README.md) 了解 ASR 模型许可证管理细节。

See [`models/README.md`](models/README.md) for ASR model license management details.

## 应用内展示 / In-App Display

### iOS / macOS 设置页面

在应用设置页面提供以下入口：

- **关于 Prism Player**: 应用版本、开发团队信息
- **开源许可证**: 展示所有第三方依赖的许可证全文
- **模型许可证**: 展示已下载 ASR 模型的许可证信息

### 实现计划 / Implementation Plan

**Sprint 0**: 占位文档和清单结构（当前阶段）  
**Sprint 1**: 基础 UI 占位页面  
**Sprint 2+**: 完整许可证展示功能

## 常见问题 / FAQ

### Q: 为什么需要许可证管理？

A: App Store 要求应用声明所有第三方依赖的许可证，特别是开源软件。这不仅是法律合规要求，也是对开源社区的尊重。

### Q: 如何选择合适的开源许可证？

A: 
- 优先选择 **MIT** 或 **Apache 2.0** 许可证的依赖，这些许可证非常宽松
- 避免 **GPL** 许可证，除非你的应用也采用 GPL（传染性）
- 商业闭源应用应避免使用 LGPL，除非动态链接

### Q: 如果依赖没有明确许可证怎么办？

A: 不要使用！没有许可证意味着默认版权保留，你无权使用。联系作者获取明确许可证声明。

### Q: 模型许可证和代码许可证有什么区别？

A: 
- **代码许可证**: 管理源代码、二进制文件的使用权
- **模型许可证**: 管理机器学习模型的使用权，可能有商业使用限制

Whisper 模型通常采用 MIT 许可证，但特定微调模型可能有不同授权条款。

## 参考资料 / References

- [Choose a License](https://choosealicense.com/)
- [SPDX License List](https://spdx.org/licenses/)
- [App Store Review Guidelines - Legal](https://developer.apple.com/app-store/review/guidelines/#legal)
- [Open Source Initiative](https://opensource.org/licenses)

---

**最后更新 / Last Updated**: 2025-10-24  
**维护者 / Maintainer**: Prism Player Team
