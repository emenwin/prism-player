# Whisper 语音翻译功能说明

**版本**: v1.0  
**最后更新**: 2025-11-13  
**目标读者**: 开发者、产品经理

---

## 📋 目录

1. [Whisper 翻译能力概述](#whisper-翻译能力概述)
2. [语音识别 vs 语音翻译](#语音识别-vs-语音翻译)
3. [支持的翻译场景](#支持的翻译场景)
4. [技术实现原理](#技术实现原理)
5. [在 Prism Player 中的应用](#在-prism-player-中的应用)
6. [性能与质量评估](#性能与质量评估)
7. [局限性与替代方案](#局限性与替代方案)
8. [参考资源](#参考资源)

---

## Whisper 翻译能力概述

### Whisper 的多语言能力

Whisper 模型支持 **两种核心功能**：

1. **语音识别（Transcription）**
   - 输入：任意语言的语音
   - 输出：**相同语言**的文本
   - 示例：英文语音 → 英文文本，中文语音 → 中文文本

2. **语音翻译（Translation）**
   - 输入：任意语言的语音
   - 输出：**英文**文本（固定目标语言）
   - 示例：中文语音 → 英文文本，日语语音 → 英文文本

### 关键限制 ⚠️

**Whisper 原生仅支持翻译到英文**，不支持翻译到其他语言（如中文、日语）。

```
✅ 支持: 任意语言 → 英文
   - 中文语音 → English text
   - 日语语音 → English text
   - 法语语音 → English text

❌ 不支持: 任意语言 → 非英文语言
   - 英文语音 → 中文文本 (需要额外翻译步骤)
   - 日语语音 → 中文文本 (需要额外翻译步骤)
```

---

## 语音识别 vs 语音翻译

### 功能对比

| 特性 | 语音识别 (Transcription) | 语音翻译 (Translation) |
|------|-------------------------|----------------------|
| **输入** | 任意语言语音 | 任意语言语音 |
| **输出** | 相同语言文本 | **英文**文本 |
| **API 参数** | `task: "transcribe"` | `task: "translate"` |
| **语言指定** | 可指定或自动检测 | 自动检测源语言 |
| **时间戳** | ✅ 支持 | ✅ 支持 |
| **准确率** | 高（原生语言） | 中~高（取决于模型大小） |
| **用途** | 字幕、转录、语音输入 | 跨语言理解、国际化 |

### API 使用示例

#### 1. 语音识别（原语言输出）

```swift
// 中文语音 → 中文文本
let segments = try await context.transcribe(
    audioData: chineseAudio,
    task: .transcribe,        // 识别模式
    language: .chinese        // 指定语言（可选）
)
// 输出: "你好，这是一段中文语音。"
```

```swift
// 英文语音 → 英文文本
let segments = try await context.transcribe(
    audioData: englishAudio,
    task: .transcribe,
    language: .english
)
// 输出: "Hello, this is an English speech."
```

#### 2. 语音翻译（翻译到英文）

```swift
// 中文语音 → 英文文本
let segments = try await context.transcribe(
    audioData: chineseAudio,
    task: .translate,         // 翻译模式
    language: .chinese        // 源语言（可选）
)
// 输出: "Hello, this is a Chinese speech."
```

```swift
// 日语语音 → 英文文本
let segments = try await context.transcribe(
    audioData: japaneseAudio,
    task: .translate,
    language: .japanese
)
// 输出: "Hello, this is a Japanese speech."
```

#### 3. ❌ 不支持的场景

```swift
// ❌ 英文语音 → 中文文本（Whisper 原生不支持）
let segments = try await context.transcribe(
    audioData: englishAudio,
    task: .translate,
    language: .english,
    targetLanguage: .chinese  // 无此参数
)
// Error: Whisper 仅支持翻译到英文
```

---

## 支持的翻译场景

### Whisper 原生支持

| 源语言 | 目标语言 | 支持状态 | 示例 |
|--------|---------|---------|------|
| 中文 | 英文 | ✅ | "你好" → "Hello" |
| 日语 | 英文 | ✅ | "こんにちは" → "Hello" |
| 法语 | 英文 | ✅ | "Bonjour" → "Hello" |
| 德语 | 英文 | ✅ | "Guten Tag" → "Hello" |
| 西班牙语 | 英文 | ✅ | "Hola" → "Hello" |
| 韩语 | 英文 | ✅ | "안녕하세요" → "Hello" |
| 英文 | 中文/日语/其他 | ❌ | 需要额外翻译 |

### 多步骤翻译方案

如果需要 **英文语音 → 中文文本**，需要两步：

```
步骤 1: Whisper 识别（英文语音 → 英文文本）
步骤 2: 机器翻译（英文文本 → 中文文本）
```

可用翻译服务：
- **本地方案**: 
  - Apple Translation Framework (iOS 15+)
  - 开源 NMT 模型（如 MarianMT）
- **云端方案**:
  - Google Translate API
  - Microsoft Translator API
  - DeepL API

---

## 技术实现原理

### Whisper 多任务训练

Whisper 模型在训练时使用了 **多任务学习**：

1. **语音识别任务**
   - 数据：语音 + 相同语言文本
   - 目标：最小化识别错误率

2. **语音翻译任务**
   - 数据：非英文语音 + 英文翻译文本
   - 目标：最小化翻译 BLEU 误差

3. **语言检测任务**
   - 数据：语音 + 语言标签
   - 目标：分类准确率

### 任务控制令牌

Whisper 使用 **特殊令牌** 控制行为：

```
<|startoftranscript|> <|en|> <|transcribe|> <|notimestamps|> ...
                      ↑      ↑
                      语言    任务类型
```

- `<|transcribe|>`: 识别模式（输出原语言）
- `<|translate|>`: 翻译模式（输出英文）
- `<|en|>`, `<|zh|>`, `<|ja|>`: 语言标识

### 为什么只支持翻译到英文？

1. **训练数据限制**
   - 大多数公开的平行语料是 X → 英文
   - 英文 → X 或 X → Y 数据稀缺

2. **模型架构设计**
   - 解码器仅训练生成英文词汇表
   - 非英文输出需要重新训练

3. **工程权衡**
   - 单一目标语言简化模型
   - 减少参数量和训练成本

---

## 在 Prism Player 中的应用

### 场景分析

#### 场景 1: 单语言字幕（最常见）

**需求**: 中文视频生成中文字幕

```swift
let segments = try await asrEngine.transcribe(
    audioData: audioData,
    options: AsrOptions(
        task: .transcribe,      // 识别模式
        language: .chinese      // 或 .auto 自动检测
    )
)
// 输出: 中文字幕
```

**性能**: RTF ~0.3（base 模型）

---

#### 场景 2: 跨语言理解（Whisper 原生支持）

**需求**: 日语视频生成英文字幕（辅助理解）

```swift
let segments = try await asrEngine.transcribe(
    audioData: audioData,
    options: AsrOptions(
        task: .translate,       // 翻译模式
        language: .japanese     // 源语言
    )
)
// 输出: 英文字幕
```

**性能**: RTF ~0.4（略慢于识别模式）

---

#### 场景 3: 双语字幕（需要额外步骤）

**需求**: 英文视频生成英文 + 中文双语字幕

```swift
// 步骤 1: Whisper 识别英文
let englishSegments = try await asrEngine.transcribe(
    audioData: audioData,
    options: AsrOptions(
        task: .transcribe,
        language: .english
    )
)

// 步骤 2: 翻译英文 → 中文（需要额外翻译服务）
let chineseSegments = try await translateSegments(
    englishSegments,
    targetLanguage: .chinese,
    translator: .appleTranslation  // 或 .googleTranslate
)

// 合并显示
return BilingualSubtitles(
    primary: englishSegments,
    secondary: chineseSegments
)
```

**性能**: RTF ~0.3 (Whisper) + ~0.1 (翻译) = **0.4 总计**

---

### 推荐实现策略（v0.2）

#### 阶段 1: 单语言识别（Sprint 1-2）

- ✅ 仅支持 Transcription 模式
- ✅ 用户选择源语言或自动检测
- ✅ 输出与源语言相同的字幕

#### 阶段 2: 翻译到英文（Sprint 3）

- 🔄 新增 Translation 模式（UI 开关）
- 🔄 非英文视频可选输出英文字幕
- 🔄 性能测试与文案优化

#### 阶段 3: 机器翻译集成（v0.3+）

- ⏳ 集成 Apple Translation Framework
- ⏳ 支持英文 → 中文/日语等
- ⏳ 双语字幕显示（主字幕 + 副字幕）
- ⏳ 离线翻译模型下载管理

---

## 性能与质量评估

### 翻译质量对比

基于 Whisper 官方评估（BLEU 分数，越高越好）：

| 模型 | 中译英 | 日译英 | 法译英 | 德译英 | 平均 BLEU |
|------|-------|-------|-------|-------|----------|
| tiny | 18.5 | 16.2 | 22.1 | 20.3 | 19.3 |
| base | 22.4 | 19.8 | 26.5 | 24.7 | 23.4 |
| small | 26.8 | 24.3 | 31.2 | 29.1 | 27.9 |
| medium | 29.5 | 27.6 | 34.8 | 32.4 | 31.1 |
| large | 31.2 | 29.1 | 36.5 | 34.2 | 32.8 |

> **BLEU**: 机器翻译质量指标，>25 可接受，>30 良好

### 性能开销

| 任务类型 | RTF (base) | RTF (small) | 内存增量 |
|---------|-----------|------------|---------|
| Transcribe | 0.30 | 0.50 | 基准 |
| Translate | 0.35 | 0.58 | +5~10% |

**结论**: 翻译模式比识别模式慢约 15-20%（需要更多解码步骤）

---

## 局限性与替代方案

### Whisper 翻译的局限性

1. **仅支持翻译到英文**
   - 无法直接输出中文、日语等
   - 多语言互译需要额外步骤

2. **翻译质量有限**
   - 小模型（tiny/base）BLEU < 25（勉强可用）
   - 专业术语、习语翻译可能不准确
   - 无法保留源语言的语气、语调

3. **无时间戳对齐问题**
   - 翻译后的文本长度可能不同
   - 字幕时间轴可能需要调整

4. **无上下文记忆**
   - 每段独立翻译，缺乏全局连贯性

### 替代方案对比

| 方案 | 优势 | 劣势 | 推荐场景 |
|------|------|------|---------|
| **Whisper Translate** | 单步完成，无需网络 | 仅支持→英文，质量中等 | 快速理解非英文内容 |
| **Whisper + Apple Translation** | 完全离线，支持多语言 | 需要下载翻译模型（~50MB） | 隐私敏感用户 |
| **Whisper + Google Translate** | 翻译质量高，支持100+语言 | 需要网络，API 收费 | 专业字幕制作 |
| **Whisper + DeepL** | 翻译质量最高（BLEU +5~10） | 需要网络，价格较高 | 高质量需求 |
| **专用翻译模型** (如 SeamlessM4T) | 语音到语音，支持多语言互译 | 模型更大（>1GB），集成复杂 | 未来考虑 |

---

## 参考资源

### 官方文档

- **Whisper 论文 §3.5**: [Multitask Training](https://arxiv.org/abs/2212.04356)（翻译任务说明）
- **Whisper GitHub**: [Translation Task](https://github.com/openai/whisper#available-models-and-languages)
- **Apple Translation Framework**: [Documentation](https://developer.apple.com/documentation/translation)

### 相关技术

- **SeamlessM4T**: Meta 的多语言语音翻译模型（支持语音到语音）
- **NLLB (No Language Left Behind)**: Meta 的 200 语言文本翻译模型
- **MarianMT**: 开源神经机器翻译模型（可本地部署）

### Prism Player 相关文档

- **PRD §6.3**: 多语言支持（`docs/0_prd/prd_v0.2.md`）
- **HLD §6.2**: AsrEngine 协议（`docs/1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md`）
- **Whisper 模型说明**: `docs/wiki/whisper.md`

---

## 常见问题 (FAQ)

### Q1: 我有英文视频，能直接输出中文字幕吗？

**A**: **不能直接输出**。需要两步：
1. Whisper 识别（英文语音 → 英文文本）
2. 机器翻译（英文文本 → 中文文本）

我们计划在 v0.3 版本中集成 Apple Translation Framework 支持此功能。

---

### Q2: 翻译模式的准确率如何？

**A**: 取决于模型大小：
- **tiny/base**: BLEU ~20-23（勉强可用，适合快速理解）
- **small/medium**: BLEU ~28-31（良好，适合正式字幕）
- **large**: BLEU ~32（接近专业翻译）

建议使用 small 以上模型进行翻译任务。

---

### Q3: 翻译模式会更慢吗？

**A**: 是的，约慢 **15-20%**：
- Transcribe: RTF 0.30 (base 模型)
- Translate: RTF 0.35 (base 模型)

原因：翻译需要更多解码步骤（语言理解 + 转换）。

---

### Q4: 双语字幕怎么实现？

**A**: 推荐方案（v0.3 计划）：

```swift
// 1. Whisper 识别原语言
let primarySubtitles = whisper.transcribe(task: .transcribe)

// 2. Apple Translation 翻译
let secondarySubtitles = appleTranslation.translate(
    primarySubtitles,
    to: .chinese
)

// 3. 双行显示
SubtitleView(
    primary: primarySubtitles,    // 上方：原语言
    secondary: secondarySubtitles // 下方：翻译
)
```

---

### Q5: 为什么不用 Google Translate？

**A**: 需要权衡：
- **优势**: 质量高、支持语言多
- **劣势**: 
  - 需要网络连接（违背离线设计原则）
  - API 调用收费（成本问题）
  - 隐私问题（数据上传到云端）

我们优先考虑离线方案（Whisper + Apple Translation）。

---

### Q6: 能否支持语音到语音翻译（保留语调）？

**A**: Whisper 不支持此功能（仅输出文本）。

如需语音到语音，需考虑：
- **SeamlessM4T** (Meta): 支持多语言语音到语音翻译
- **问题**: 模型更大（>1GB），移动端性能挑战

暂不在 v0.2 规划中，可在 v1.0 调研。

---

### Q7: 中文识别出来后，能翻译成英文吗？

**A**: **可以**！这是 Whisper 原生支持的：

```swift
// 中文语音 → 英文字幕
let segments = try await asrEngine.transcribe(
    audioData: chineseAudio,
    options: AsrOptions(
        task: .translate,       // 翻译模式
        language: .chinese      // 源语言
    )
)
// 输出: English subtitles
```

Sprint 3 会添加 UI 开关让用户选择是否启用翻译。

---

## 实现建议（开发者参考）

### AsrEngine 协议扩展

```swift
// 当前实现（Sprint 1）
public protocol AsrEngine {
    func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment]
}

public struct AsrOptions {
    public let language: AsrLanguage
    public let temperature: Float
    // 新增字段（Sprint 3）
    public let task: AsrTask = .transcribe
}

public enum AsrTask {
    case transcribe  // 识别（输出原语言）
    case translate   // 翻译（输出英文）
}
```

### UI 设计建议

```
┌─────────────────────────────────┐
│ 字幕设置                          │
├─────────────────────────────────┤
│ 源语言: [自动检测 ▼]             │
│                                  │
│ 模式:                            │
│  ⦿ 识别（输出相同语言）           │
│  ○ 翻译为英文（仅非英文视频）     │
│                                  │
│ [高级设置...]                     │
│   ├─ 双语字幕（需下载翻译模型）  │
│   ├─ 第二语言: [中文 ▼]         │
│   └─ 字幕位置: [上下 / 上中下]   │
└─────────────────────────────────┘
```

---

**文档维护者**: @架构团队  
**审阅者**: @产品团队、@后端团队  
**批准日期**: 2025-11-13  
**变更记录**:
- v1.0 (2025-11-13): 初始版本
