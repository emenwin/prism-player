# ASR 模型许可证管理 / ASR Model License Management

本文档说明 Prism Player 使用的 ASR（自动语音识别）模型的许可证管理策略。

This document explains the license management strategy for ASR (Automatic Speech Recognition) models used in Prism Player.

## 模型许可证概述 / Model License Overview

与代码许可证不同，机器学习模型的许可证管理有其特殊性：

- **训练数据许可**: 模型训练所用数据集的许可证
- **模型权重许可**: 模型参数文件的分发许可
- **商业使用限制**: 某些模型禁止商业使用
- **衍生作品**: 微调模型是否可以分发

Unlike code licenses, machine learning model licenses have unique considerations:

- **Training data license**: License of datasets used for training
- **Model weights license**: Distribution license for model parameters
- **Commercial use restrictions**: Some models prohibit commercial use
- **Derivative works**: Whether fine-tuned models can be distributed

## Whisper 模型许可证 / Whisper Model Licenses

### OpenAI Whisper 官方模型

**许可证**: MIT License  
**来源**: [OpenAI Whisper](https://github.com/openai/whisper)  
**商业使用**: ✅ 允许  
**修改和分发**: ✅ 允许  
**归属要求**: ✅ 需要声明

#### 许可证全文

```
MIT License

Copyright (c) 2022 OpenAI

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

#### 模型变体 / Model Variants

| 模型 / Model | 大小 / Size | 许可证 / License | 状态 / Status |
|-------------|------------|-----------------|--------------|
| Whisper Tiny | 39 MB | MIT | ✅ 已验证 |
| Whisper Base | 74 MB | MIT | ✅ 已验证 |
| Whisper Small | 244 MB | MIT | ✅ 已验证 |
| Whisper Medium | 769 MB | MIT | ✅ 已验证 |
| Whisper Large-v2 | 1.5 GB | MIT | ✅ 已验证 |
| Whisper Large-v3 | 1.5 GB | MIT | ✅ 已验证 |

### 社区微调模型 / Community Fine-Tuned Models

使用社区微调的 Whisper 模型时，需额外检查：

When using community fine-tuned Whisper models, additional checks are required:

1. **基础模型许可证**: 通常继承 Whisper MIT 许可证
2. **微调数据集许可证**: 可能有额外限制（如 CC-BY-NC 禁止商业使用）
3. **模型发布许可证**: 作者可能添加额外条款

#### 推荐来源 / Recommended Sources

- **Hugging Face**: 查看每个模型页面的 "License" 标签
- **OpenSLR**: 开放语音和语言资源，通常采用 Apache 2.0
- **Common Voice**: Mozilla 数据集，CC0 公共领域

#### ⚠️ 高风险许可证 / High-Risk Licenses

以下许可证需谨慎评估：

- **CC-BY-NC**: ❌ 禁止商业使用
- **CC-BY-SA**: ⚠️ 要求衍生作品使用相同许可证（传染性）
- **研究专用 (Research Only)**: ❌ 禁止生产环境使用
- **未明确许可证**: ❌ 默认版权保留，禁止使用

## 应用内模型声明 / In-App Model Attribution

### UI 展示要求 / UI Display Requirements

在应用内"模型许可证"页面展示：

1. **模型名称**: 如 "Whisper Large-v3"
2. **模型来源**: OpenAI / Hugging Face / 自定义
3. **许可证类型**: MIT / Apache 2.0 / 自定义
4. **版权声明**: © 2022 OpenAI
5. **许可证全文链接**: 提供查看完整许可证的入口

### 实现示例 / Implementation Example

```swift
struct ModelLicense: Identifiable {
    let id: UUID
    let modelName: String
    let version: String
    let license: String
    let copyright: String
    let licenseURL: URL?
    let fullLicenseText: String
}

// 示例数据
let whisperLicense = ModelLicense(
    id: UUID(),
    modelName: "Whisper Large-v3",
    version: "v3.0",
    license: "MIT License",
    copyright: "© 2022 OpenAI",
    licenseURL: URL(string: "https://github.com/openai/whisper/blob/main/LICENSE"),
    fullLicenseText: "..." // MIT 全文
)
```

## 模型下载和分发 / Model Download and Distribution

### 官方渠道 / Official Channels

**推荐**: 从官方源下载模型，确保许可证清晰

- OpenAI Whisper: https://github.com/openai/whisper
- Hugging Face Hub: https://huggingface.co/models?filter=whisper
- ggml Format: https://huggingface.co/ggerganov/whisper.cpp

### 应用内分发策略 / In-App Distribution Strategy

**选项 1: 按需下载（推荐）**
- 应用不预装模型
- 用户首次使用时从官方源下载
- 优点：应用体积小，许可证风险低
- 缺点：需要网络连接

**选项 2: 预装小型模型**
- 仅预装 Whisper Tiny (39 MB)
- 大型模型按需下载
- 优点：离线可用，用户体验好
- 缺点：需在应用内明确声明许可证

### 商业模型 / Commercial Models

如果未来使用商业 ASR 模型：

- **Azure Speech Services**: 按 API 调用付费，无需分发许可证
- **Google Cloud Speech-to-Text**: 同上
- **Rev AI**: 同上
- **自研模型**: 需明确内部授权条款

这些云服务通过 API 提供，模型权重不分发，许可证管理由服务商负责。

## 合规检查清单 / Compliance Checklist

在添加新模型前，检查以下项目：

- [ ] 模型许可证类型明确（MIT / Apache / 自定义）
- [ ] 商业使用权限确认（允许 / 禁止）
- [ ] 训练数据集许可证检查（如适用）
- [ ] 归属要求明确（版权声明格式）
- [ ] 应用内许可证展示已实现
- [ ] `third-party.json` 或 `models.json` 已更新
- [ ] 法务审核通过（如需要）

## 常见问题 / FAQ

### Q: Whisper 模型可以商业使用吗？

A: ✅ 可以。OpenAI Whisper 采用 MIT 许可证，明确允许商业使用、修改和分发。

### Q: 我可以微调 Whisper 模型并分发吗？

A: ✅ 可以。MIT 许可证允许创建衍生作品，但需保留原始版权声明。注意你用于微调的数据集许可证可能有额外限制。

### Q: 使用 Hugging Face 上的模型安全吗？

A: ⚠️ 需要逐个检查。Hugging Face 是平台，不保证所有模型的许可证。务必查看模型页面的 "License" 标签，避免使用 CC-BY-NC 或 "Research Only" 模型。

### Q: 如果模型没有明确许可证怎么办？

A: ❌ 不要使用。联系模型作者获取明确许可证声明，或选择其他有明确许可证的模型。

### Q: 需要在应用启动时显示许可证吗？

A: ❌ 不需要。在设置页面提供"关于"或"许可证"入口即可。但某些许可证（如 GPL）可能要求更显著的声明。

## 参考资料 / References

- [OpenAI Whisper License](https://github.com/openai/whisper/blob/main/LICENSE)
- [Hugging Face Model Licensing](https://huggingface.co/docs/hub/model-cards#model-card-metadata)
- [Creative Commons Licenses](https://creativecommons.org/licenses/)
- [Model Cards for Model Reporting](https://arxiv.org/abs/1810.03993)

---

**最后更新 / Last Updated**: 2025-10-24  
**维护者 / Maintainer**: Prism Player Team  
**审核状态 / Review Status**: ✅ 初步完成，待法务审核
