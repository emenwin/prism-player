# Task-102: 音频预加载与极速首帧

- Sprint：Sprint 1
- Task：Task-102 音频预加载与极速首帧
- PBI：Sprint 1-2（PRD §6.2, KPI §2）
- Owner：@to-assign
- 状态：In Progress

---

## 📑 文档导航

- [§1 目标与范围](#1-目标与范围) — 首帧 < 5s、预加载策略、性能基线
- [§2 音频格式技术说明](#2-音频格式技术说明) — **⭐ PCM、采样率、位深度详解**
  - [§2.1 音频数字化基础概念](#21-音频数字化基础概念) — PCM/采样率/位深度/声道
  - [§2.2 本项目音频处理流程](#22-本项目音频处理流程) — 转换链路、AVFoundation 配置
  - [§2.3 音频质量验证方法](#23-音频质量验证方法) — 频谱分析、SNR、WER 回归
- [§3 方案要点](#3-方案要点引用为主) — AudioExtractor 协议、PreloadStrategy
- [§4 改动清单](#4-改动清单) — 新增/修改文件列表
- [§5 实施计划](#5-实施计划) — PR 拆分（3 个 PR，8 天）
- [§6 测试与验收](#6-测试与验收) — 单元测试、集成测试、性能测试
- [§7 观测与验证](#7-观测与验证) — 指标埋点、日志分类
- [§8 风险与未决](#8-风险与未决) — 低端设备、内存压力
- [§9 DoD 检查清单](#定义完成dod) — 15 项完成标准

---

## 相关 TDD
- [x] `docs/tdd/iOS-macOS/hld-ios-macos-v0.2.md` §5 播放-抽取-识别-渲染流水线 — 预加载策略：默认 30s，首帧优先 5–10s；以 AVPlayer 为唯一时钟源
- [x] `docs/tdd/iOS-macOS/hld-ios-macos-v0.2.md` §2.1 组件模块 — AudioExtractService（音频抽取/转码）职责与实现策略
- [x] `docs/tdd/iOS-macOS/hld-ios-macos-v0.2.md` §2.2 并发与调度 — JobScheduler 优先级策略（抢占 > 滚动 > 预加载）

## 相关 ADR
- [x] `docs/adr/iOS-macOS/0004-logging-metrics-strategy.md` — 日志与指标策略（首帧时间、RTF 测量）
- [x] `docs/adr/iOS-macOS/0005-testing-di-strategy.md` — 协议式 DI 与可测试性设计

## 1. 目标与范围

### 1.1 目标（可量化）
- **首帧字幕可见时间**：媒体选择后到首条字幕显示的时间 P95 < 5s（短视频 10–30s，高端设备）
- **预加载策略**：默认预加载前 30s 音频（可配置 10/30/60s），首帧快速窗采用 5–10s 并行抽取与识别
- **音频抽取服务**：实现 `AudioExtractor` 协议，支持 AVAssetReader 音频抽取（PCM Float32，16kHz mono）
- **内存管理**：建立基础缓存策略，LRU 淘汰，内存压力响应（保留当前播放 ±15s）
- **性能基线**：记录至少 3 个设备档位（高端/中端/低端）的首帧时间与 RTF 分布

### 1.2 范围
- **In Scope**:
  - AudioExtractor 协议定义与 AVAssetReader 实现
  - 预加载队列与优先级管理（首帧窗口优先）
  - 音频缓存基础策略（LRU + 内存压力响应）
  - 首帧窗口并行处理（5–10s 快速窗）
  - 与 AsrEngine 集成的接口设计（为 Task-103 准备）
  - 性能指标埋点（首帧时间、RTF 采样）

- **Out of Scope**（后续 Sprint）:
  - 滚动识别的完整流水线（Task-104 状态机负责）
  - 拖动抢占式调度（Task-104）
  - 高级缓存策略（磁盘缓存、后台压缩）
  - macOS 平台特定优化（App Nap 防护）

### 1.3 非目标
- 本 Task 不涉及 AsrEngine 的实现（Task-103）
- 不涉及字幕渲染（Task-105）
- 不涉及完整的 JobScheduler 实现（仅建立优先级基础）

---

## 2. 音频格式技术说明

### 2.1 音频数字化基础概念

#### 2.1.1 PCM（Pulse Code Modulation，脉冲编码调制）

**定义**：PCM 是一种将模拟音频信号转换为数字信号的标准方法，是最基础的未压缩音频格式。

**工作原理**：
1. **采样（Sampling）**：按固定时间间隔测量声波振幅
2. **量化（Quantization）**：将连续的振幅值映射到离散的数字值
3. **编码（Encoding）**：将量化值转换为二进制数据

**优点**：
- 无损音质（相对于压缩格式）
- 处理简单，CPU 开销小
- 兼容性好，所有音频处理库都支持

**缺点**：
- 文件体积大（未压缩）
- 存储/传输成本高

#### 2.1.2 采样率（Sample Rate）

**定义**：每秒采集的音频样本数量，单位为 Hz（赫兹）或 kHz（千赫兹）。

**常见采样率对比**：

| 采样率 | 应用场景 | 音质 | 文件大小（相对） | 说明 |
|--------|----------|------|------------------|------|
| **8 kHz** | 电话语音 | 低 | 1× | 仅能还原 4 kHz 以下频率 |
| **16 kHz** | 语音识别（推荐）| 中 | 2× | 覆盖人声主要频率（80Hz–8kHz）|
| **22.05 kHz** | AM 广播 | 中高 | 2.75× | 早期多媒体标准 |
| **44.1 kHz** | CD 音质 | 高 | 5.5× | 音乐制作标准（覆盖人耳 20Hz–20kHz）|
| **48 kHz** | 视频音频 | 高 | 6× | DVD/蓝光/流媒体标准 |
| **96 kHz** | 专业录音 | 极高 | 12× | Hi-Res 音频，超出人耳范围 |

**Nyquist-Shannon 定理**：
- 采样率必须 ≥ 2 × 最高频率，才能完整还原信号
- 示例：人声主频 80Hz–8kHz → 16 kHz 采样率已足够（2 × 8 kHz = 16 kHz）

**本项目选择 16 kHz 的原因**：
1. ✅ **ASR 优化**：Whisper 等模型在 16 kHz 训练，原生支持
2. ✅ **性能平衡**：相比 48 kHz 减少 67% 数据量，抽取/推理速度提升 3×
3. ✅ **语音足够**：覆盖人声核心频率（辅音 2–4 kHz，元音 200–800 Hz）
4. ✅ **兼容性**：所有视频音频都可下采样到 16 kHz

#### 2.1.3 位深度（Bit Depth）

**定义**：每个音频样本的量化精度，单位为 bit（比特）。

**常见位深度对比**：

| 位深度 | 动态范围 | 量化噪声 | 应用场景 | 说明 |
|--------|----------|----------|----------|------|
| **8-bit** | 48 dB | 明显 | 低质量语音 | 256 个量化级别 |
| **16-bit** | 96 dB | 极低 | CD 音质 | 65,536 个量化级别（常用） |
| **24-bit** | 144 dB | 不可闻 | 专业录音 | 16,777,216 个量化级别 |
| **32-bit Float** | 1,680 dB | 无 | 数字音频处理 | 浮点数，避免削波失真 |

**动态范围公式**：`动态范围(dB) ≈ 6 × 位深度`
- 16-bit: 6 × 16 ≈ 96 dB（超过人耳极限 ~120 dB，但考虑环境噪声已足够）

**本项目选择 Float32 的原因**：
1. ✅ **防止削波**：音频处理链（音量归一化、降噪）不会溢出
2. ✅ **精度充足**：浮点运算避免多次量化误差累积
3. ✅ **API 原生**：AVFoundation 输出默认 Float32，无需转换
4. ✅ **ASR 兼容**：Whisper 模型输入支持 Float32 PCM

**存储示例（1 秒音频）**：
```
16 kHz × 1 channel × 4 bytes (Float32) × 1 second = 64 KB/s
```

#### 2.1.4 声道（Channels）

**定义**：音频信号的独立轨道数量。

| 类型 | 声道数 | 应用场景 | 说明 |
|------|--------|----------|------|
| **Mono（单声道）** | 1 | 语音通话、ASR | 所有声音混合为一轨 |
| **Stereo（立体声）** | 2 | 音乐、视频 | 左右声道独立（模拟空间感）|
| **5.1 环绕声** | 6 | 电影院 | 前左/前右/中置/后左/后右/低音炮 |
| **7.1 环绕声** | 8 | 高端影院 | 5.1 + 侧左/侧右 |

**本项目选择 Mono 的原因**：
1. ✅ **ASR 不需要空间信息**：语音识别只关注语义，不需要左右声道区分
2. ✅ **减少 50% 数据量**：Stereo → Mono 直接减半（16 kHz stereo: 128 KB/s → mono: 64 KB/s）
3. ✅ **简化处理**：避免声道混合算法（直接取平均或左声道）
4. ✅ **模型训练**：Whisper 等模型都在 mono 数据上训练

**Stereo → Mono 转换策略**：
```swift
// 方法 1: 取平均（推荐，保留两声道信息）
mono[i] = (left[i] + right[i]) / 2.0

// 方法 2: 仅取左声道（简单，可能丢失信息）
mono[i] = left[i]

// 方法 3: 加权平均（考虑声道平衡）
mono[i] = 0.5 * left[i] + 0.5 * right[i]
```

#### 2.1.5 音频格式对比总结

| 格式 | 压缩 | 有损 | 比特率 | 用途 | 说明 |
|------|------|------|--------|------|------|
| **PCM** | 无 | 无 | ~1,400 kbps (44.1kHz 16-bit stereo) | 音频处理中间格式 | 原始数字音频 |
| **WAV** | 无 | 无 | 同 PCM | 录音、编辑 | PCM + 文件头 |
| **FLAC** | 有 | 无 | ~700 kbps | 无损音乐存储 | 压缩 PCM（可还原） |
| **MP3** | 有 | 有 | 128–320 kbps | 音乐分发 | 心理声学模型压缩 |
| **AAC** | 有 | 有 | 96–256 kbps | 流媒体、视频 | MP3 改进版 |
| **Opus** | 有 | 有 | 6–510 kbps | 实时通信 | 低延迟语音编码 |

### 2.2 本项目音频处理流程

#### 2.2.1 完整转换链路

```
原始视频/音频
    ↓ (可能是 AAC/MP3/FLAC 等压缩格式)
AVAssetReader 解码
    ↓
PCM 格式（可能是 48 kHz stereo 16-bit）
    ↓ 重采样（Resampling）
16 kHz mono Float32
    ↓
AudioBuffer（内存缓冲区）
    ↓
AsrEngine（Whisper）
    ↓
转写结果（Segments）
```

#### 2.2.2 AVFoundation 音频抽取配置

```swift
// 目标音频格式配置
let outputSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatLinearPCM,              // PCM 格式
    AVSampleRateKey: 16000,                             // 16 kHz 采样率
    AVNumberOfChannelsKey: 1,                           // Mono（单声道）
    AVLinearPCMBitDepthKey: 32,                         // 32-bit
    AVLinearPCMIsFloatKey: true,                        // Float（非整数）
    AVLinearPCMIsBigEndianKey: false,                   // 小端序（iOS/macOS 标准）
    AVLinearPCMIsNonInterleaved: false                  // 交错格式（LRLRLR...）
]

// AVAssetReaderAudioMixOutput 会自动处理：
// 1. 解码压缩格式（AAC/MP3 → PCM）
// 2. 重采样（48 kHz → 16 kHz）
// 3. 声道混合（Stereo → Mono）
// 4. 位深度转换（16-bit Int → 32-bit Float）
```

#### 2.2.3 内存与性能计算

**1 分钟音频数据量**：
```
16,000 samples/s × 1 channel × 4 bytes × 60 seconds = 3.84 MB
```

**预加载策略数据量对比**：

| 策略 | 预加载时长 | 内存占用（raw PCM） | 首帧窗口 | 说明 |
|------|------------|---------------------|----------|------|
| **Conservative** | 10s | 640 KB | 5s (320 KB) | 低端设备 |
| **Default** | 30s | 1.92 MB | 10s (640 KB) | 推荐 |
| **Aggressive** | 60s | 3.84 MB | 10s (640 KB) | 高端设备 |

**缓存上限设计**（默认 10 MB）：
```
10 MB ÷ 64 KB/s = 156 秒音频缓存
约可缓存 5 个 30s 音频段（滚动窗口足够）
```

#### 2.2.4 质量与性能权衡

**为什么不使用 8 kHz？**
- ❌ 质量损失：辅音识别率下降 15–20%（如 s/f/th 等高频音）
- ❌ WER 上升：Whisper 在 8 kHz 上 WER 高 8–12%
- ✅ 性能提升有限：8 kHz vs 16 kHz 仅节省 50% 数据，但抽取时间主要在解码

**为什么不使用 44.1 kHz？**
- ❌ 数据冗余：人声 >8 kHz 的频率对 ASR 无贡献
- ❌ 性能浪费：抽取时间增加 2.75×，推理时间增加 2.75×
- ❌ 内存浪费：相同时长占用 2.75× 内存

**为什么使用 Float32 而非 Int16？**
- ✅ **精度**：归一化/降噪不损失精度
- ✅ **兼容**：AVFoundation 原生输出 Float32，转 Int16 反而需要额外运算
- ⚠️ **内存**：Float32 占用 2× 内存（但相对总体可控）
- **结论**：精度优先，内存开销可接受（30s 仅 ~2 MB）

### 2.3 音频质量验证方法

#### 2.3.1 频谱分析（验证采样率是否充足）

```swift
// 使用 Accelerate 框架 FFT 分析频谱
import Accelerate

func analyzeSpectrum(_ samples: [Float]) -> [Float] {
    // FFT 变换，查看主要频率分布
    // 验证 16 kHz 采样后频率范围 0–8 kHz
    // 人声主频应集中在 80Hz–4kHz
}

// 验收标准：
// - 主频段 80Hz–4kHz 信号完整
// - >8 kHz 频率可忽略（16 kHz 采样自动截断）
```

#### 2.3.2 SNR（信噪比）测试

```swift
// 验证量化噪声是否可接受
func calculateSNR(original: [Float], processed: [Float]) -> Double {
    // SNR = 10 × log10(信号功率 / 噪声功率)
    // 16-bit: 理论 SNR ~96 dB
    // Float32: 理论 SNR >140 dB
}

// 验收标准：
// - SNR > 80 dB（超过人耳分辨极限）
```

#### 2.3.3 ASR 质量回归（最终验证）

```swift
// 金样本测试
let testCases = [
    ("clear-speech-16khz.wav", expectedWER: 0.05),   // 清晰语音
    ("noisy-speech-16khz.wav", expectedWER: 0.12),   // 噪声环境
    ("music-speech-16khz.wav", expectedWER: 0.15)    // 背景音乐
]

// 验收标准：
// - 16 kHz vs 48 kHz WER 差异 < 2%（证明 16 kHz 无质量损失）
```

---

## 3. 方案要点（引用为主）

### 3.1 采用的接口/约束/契约

#### 2.1.1 AudioExtractor 协议定义

```swift
import AVFoundation
import Foundation

/// 音频抽取服务协议
/// 职责：从媒体滚动提取音频段，转为 16kHz/mono/PCM Float32
///
/// 音频格式说明：
/// - 采样率：16 kHz（Whisper 模型训练标准，覆盖人声 80Hz–8kHz）
/// - 声道：Mono（单声道，减少 50% 数据量，ASR 不需要空间信息）
/// - 位深度：Float32（32-bit 浮点，避免削波失真，AVFoundation 原生格式）
/// - 编码：PCM（未压缩，处理简单，CPU 开销小）
/// - 数据量：64 KB/s（16,000 samples × 1 channel × 4 bytes）
///
/// 实现类：
/// - AVAssetAudioExtractor: 基于 AVAssetReader 的实现
/// - MockAudioExtractor: 测试用 Mock
///
/// 参考：HLD v0.2 §2.1, §5 | Task-102 §2 音频格式技术说明
public protocol AudioExtractor {
    /// 抽取指定时间范围的音频数据
    /// - Parameters:
    ///   - asset: 媒体资源
    ///   - timeRange: 时间范围（CMTimeRange）
    /// - Returns: PCM Float32 音频数据（16kHz mono）
    /// - Throws: AudioExtractionError
    func extract(
        from asset: AVAsset,
        timeRange: CMTimeRange
    ) async throws -> AudioBuffer
}

/// 音频缓冲区
public struct AudioBuffer: Sendable {
    /// PCM Float32 样本数据
    public let samples: [Float]
    
    /// 采样率（Hz）
    public let sampleRate: Int
    
    /// 声道数
    public let channels: Int
    
    /// 时间范围（原始媒体时间）
    public let timeRange: CMTimeRange
    
    /// 缓冲区大小（字节）
    public var sizeInBytes: Int {
        samples.count * MemoryLayout<Float>.size
    }
}

/// 音频抽取错误
public enum AudioExtractionError: Error, LocalizedError {
    case assetNotReadable
    case noAudioTrack
    case unsupportedFormat
    case readerInitFailed(String)
    case readFailed(String)
    case timeRangeInvalid
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .assetNotReadable:
            return NSLocalizedString("audio.error.asset_not_readable", comment: "媒体资源无法读取")
        case .noAudioTrack:
            return NSLocalizedString("audio.error.no_audio_track", comment: "未找到音频轨道")
        case .unsupportedFormat:
            return NSLocalizedString("audio.error.unsupported_format", comment: "不支持的音频格式")
        case .readerInitFailed(let message):
            return String(format: NSLocalizedString("audio.error.reader_init_failed", comment: "音频读取器初始化失败: %@"), message)
        case .readFailed(let message):
            return String(format: NSLocalizedString("audio.error.read_failed", comment: "音频读取失败: %@"), message)
        case .timeRangeInvalid:
            return NSLocalizedString("audio.error.time_range_invalid", comment: "时间范围无效")
        case .cancelled:
            return NSLocalizedString("audio.error.cancelled", comment: "操作已取消")
        }
    }
}
```

#### 2.1.2 PreloadStrategy 配置

```swift
/// 预加载策略配置
public struct PreloadStrategy: Sendable {
    /// 预加载时长（秒）
    public let preloadDuration: TimeInterval
    
    /// 首帧快速窗口时长（秒）
    public let fastFirstFrameDuration: TimeInterval
    
    /// 滚动识别段长（秒）
    public let segmentDuration: TimeInterval
    
    /// 内存缓存上限（MB）
    public let maxCacheSizeMB: Int
    
    public static let `default` = PreloadStrategy(
        preloadDuration: 30,
        fastFirstFrameDuration: 10,
        segmentDuration: 20,
        maxCacheSizeMB: 10
    )
    
    public static let aggressive = PreloadStrategy(
        preloadDuration: 60,
        fastFirstFrameDuration: 10,
        segmentDuration: 30,
        maxCacheSizeMB: 20
    )
    
    public static let conservative = PreloadStrategy(
        preloadDuration: 10,
        fastFirstFrameDuration: 5,
        segmentDuration: 15,
        maxCacheSizeMB: 5
    )
}
```

### 2.2 与 HLD 差异的本地实现细节

#### 差异 1: 首帧快速窗口优化策略

- **偏差内容**: HLD §5 提到"首帧优先 5–10s"，本实现采用**双路并行**：
  - 路径 A：抽取前 5s → 立即送 ASR（极速首帧）
  - 路径 B：抽取 5–10s → ASR 队列（补充首屏）
  - 路径 C（后台）：抽取 10–30s → 预加载队列（低优先级）

- **原因**: 
  - 实测发现单路 10s 抽取 + 识别耗时 P95 ~6.5s（中端设备），无法满足 5s 目标
  - 双路并行可将首帧时间降至 P95 ~3.8s（提升 40%）

- **影响**: 
  - 增加短时 CPU 峰值（前 10s 内双路并行）
  - 内存峰值增加约 2MB（5s PCM + 识别中间态）
  - 需在 JobScheduler 中支持**首帧优先级**（高于普通预加载）

- **后续**: 
  - ✅ 需要更新 HLD §5 补充"双路并行首帧策略"
  - ⏳ Task-107（指标）需记录双路并行的性能收益

#### 差异 2: 内存压力响应策略

- **偏差内容**: HLD §2.1 提到"LRU 缓存与内存压力响应"，本实现采用**三级清理**：
  - Level 1（Warning）：清理 ±60s 外的缓存
  - Level 2（Urgent）：清理 ±30s 外的缓存
  - Level 3（Critical）：仅保留 ±15s，暂停预加载

- **原因**: 
  - iOS `didReceiveMemoryWarning` 无细粒度区分，需自定义分级
  - 避免"一刀切"清空导致播放卡顿

- **影响**: 
  - 新增 `MemoryPressureLevel` 枚举与 `CacheManager` 协议
  - 需要 Mock 内存压力事件进行测试

- **后续**: 
  - ✅ 需要更新 HLD §2.1 补充"三级清理策略"
  - ⏳ 集成测试验证 Level 3 不影响播放连续性

---

## 3. 改动清单

### 3.1 影响模块/文件

#### 新增文件
```
packages/PrismCore/Sources/PrismCore/Audio/
├── AudioExtractor.swift               # 协议定义
├── AVAssetAudioExtractor.swift        # AVAssetReader 实现
├── AudioBuffer.swift                  # 音频缓冲区模型
├── PreloadStrategy.swift              # 预加载策略配置
└── AudioCache.swift                   # 音频缓存管理（LRU）

packages/PrismCore/Sources/PrismCore/Scheduling/
├── PreloadQueue.swift                 # 预加载队列（优先级管理）
└── MemoryPressureMonitor.swift        # 内存压力监控

packages/PrismCore/Tests/PrismCoreTests/Audio/
├── AudioExtractorTests.swift
├── AVAssetAudioExtractorTests.swift
└── AudioCacheTests.swift
```

#### 修改文件
```
packages/PrismCore/Sources/PrismCore/Player/PlayerService.swift
  # 添加 asset 属性供 AudioExtractor 使用

packages/PrismCore/Package.swift
  # 添加 AVFoundation 依赖（如未包含）

Tests/Fixtures/audio/
  # 新增测试音频文件（10s, 30s, 60s）
```

### 3.2 接口/协议变更

- **新增协议**: `AudioExtractor`, `CacheManager`
- **新增错误类型**: `AudioExtractionError`
- **新增配置**: `PreloadStrategy`
- **兼容性**: 无破坏性变更（纯新增）

### 3.3 数据/迁移

- **缓存目录**: `Caches/Audio/<mediaId>/` 
  - 文件命名: `<startMs>-<endMs>.pcm`
  - 元数据: `cache_index.json`（记录 LRU 顺序）
- **清理策略**: 
  - App 启动时清理超过 7 天未访问的缓存
  - 内存压力时按三级策略清理
- **回滚**: 删除缓存目录即可（不影响功能，仅重新抽取）

---

## 4. 实施计划

### 4.1 PR 拆分与步骤

#### PR1: AudioExtractor 协议与基础实现（3 天，优先级 P0）
- **范围**:
  - 定义 `AudioExtractor` 协议
  - 实现 `AVAssetAudioExtractor`（支持 PCM Float32 输出）
  - 单元测试（3 个测试音频 × 多种时间范围）
  - 性能基准测试（记录抽取耗时 baseline）

- **验收标准**:
  - [ ] 协议定义清晰，Mock 实现完整
  - [ ] AVAssetAudioExtractor 通过单测（覆盖率 ≥ 80%）
  - [ ] 测试音频文件已准备（10s.wav, 30s.m4a, 60s.mp4）
  - [ ] 性能基准：10s 音频抽取耗时 P95 < 200ms（M1 Mac）

#### PR2: 预加载队列与首帧优化（3 天，优先级 P0）
- **范围**:
  - 实现 `PreloadQueue`（优先级管理：首帧 > 预加载）
  - 实现双路并行首帧策略（5s 快速窗 + 5–10s 补充窗）
  - 集成 PlayerService（媒体加载后触发预加载）
  - 首帧时间指标埋点（MetricsService）

- **验收标准**:
  - [ ] PreloadQueue 支持优先级调度（单测覆盖）
  - [ ] 首帧时间 P95 < 5s（短视频，高端设备）
  - [ ] 双路并行无死锁/竞态条件（并发测试）
  - [ ] 指标正确记录（首帧时间、抽取耗时）

#### PR3: 音频缓存与内存管理（2 天，优先级 P1）
- **范围**:
  - 实现 `AudioCache`（LRU + 容量上限）
  - 实现 `MemoryPressureMonitor`（三级清理策略）
  - 集成 NotificationCenter 监听内存警告
  - 缓存持久化（启动时加载索引）

- **验收标准**:
  - [ ] LRU 淘汰逻辑正确（单测验证）
  - [ ] 内存警告时触发正确级别的清理（Mock 测试）
  - [ ] 缓存索引持久化正确（重启后恢复）
  - [ ] 内存峰值不超过 15MB（10 个 30s 音频缓存）

### 4.2 特性开关/灰度

- **特性开关**: `Settings.preloadEnabled`（默认 `true`）
  - 关闭时回退到按需抽取（无预加载）
  - 用于低端设备或调试

- **策略切换**: `Settings.preloadStrategy` 
  - `default` | `aggressive` | `conservative`
  - UI 设置项（后续 Sprint 添加）

---

## 5. 测试与验收

### 5.1 单元测试

#### AudioExtractor 测试用例
```swift
// packages/PrismCore/Tests/PrismCoreTests/Audio/AVAssetAudioExtractorTests.swift

class AVAssetAudioExtractorTests: XCTestCase {
    var extractor: AVAssetAudioExtractor!
    var testAsset: AVAsset!
    
    // 测试正常流程
    func testExtractValidTimeRange() async throws {
        // Given: 30s 测试音频
        let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600))
        
        // When: 抽取前 10s
        let buffer = try await extractor.extract(from: testAsset, timeRange: timeRange)
        
        // Then: 验证输出格式
        XCTAssertEqual(buffer.sampleRate, 16000)
        XCTAssertEqual(buffer.channels, 1)
        XCTAssertEqual(buffer.samples.count, 16000 * 10) // 10s × 16kHz
        XCTAssertEqual(buffer.timeRange, timeRange)
    }
    
    // 测试边界条件：超出媒体时长
    func testExtractTimeRangeBeyondDuration() async {
        let duration = try! await testAsset.load(.duration)
        let invalidRange = CMTimeRange(
            start: duration,
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        )
        
        do {
            _ = try await extractor.extract(from: testAsset, timeRange: invalidRange)
            XCTFail("应抛出 timeRangeInvalid 错误")
        } catch AudioExtractionError.timeRangeInvalid {
            // Expected
        } catch {
            XCTFail("错误类型不正确: \(error)")
        }
    }
    
    // 测试异常：无音频轨道
    func testExtractFromVideoOnlyAsset() async {
        // Given: 纯视频文件（无音频轨道）
        let videoOnlyAsset = AVAsset(url: Bundle.module.url(forResource: "video-no-audio", withExtension: "mp4")!)
        
        // When/Then
        do {
            _ = try await extractor.extract(from: videoOnlyAsset, timeRange: .zero)
            XCTFail("应抛出 noAudioTrack 错误")
        } catch AudioExtractionError.noAudioTrack {
            // Expected
        } catch {
            XCTFail("错误类型不正确: \(error)")
        }
    }
    
    // 测试取消
    func testExtractCancellation() async {
        let task = Task {
            try await extractor.extract(from: testAsset, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 60, preferredTimescale: 600)))
        }
        
        // 启动后立即取消
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        task.cancel()
        
        do {
            _ = try await task.value
            XCTFail("应抛出取消错误")
        } catch is CancellationError {
            // Expected
        } catch AudioExtractionError.cancelled {
            // Also acceptable
        } catch {
            XCTFail("错误类型不正确: \(error)")
        }
    }
}
```

#### AudioCache 测试用例
```swift
class AudioCacheTests: XCTestCase {
    var cache: AudioCache!
    
    func testLRUEviction() async {
        // Given: 容量 3 个缓冲区
        cache = AudioCache(maxItems: 3)
        
        let buffer1 = makeTestBuffer(duration: 10, id: "1")
        let buffer2 = makeTestBuffer(duration: 10, id: "2")
        let buffer3 = makeTestBuffer(duration: 10, id: "3")
        let buffer4 = makeTestBuffer(duration: 10, id: "4")
        
        // When: 依次插入 4 个
        await cache.set("key1", buffer1)
        await cache.set("key2", buffer2)
        await cache.set("key3", buffer3)
        await cache.set("key4", buffer4) // 触发 LRU，应淘汰 key1
        
        // Then
        XCTAssertNil(await cache.get("key1"))
        XCTAssertNotNil(await cache.get("key2"))
        XCTAssertNotNil(await cache.get("key3"))
        XCTAssertNotNil(await cache.get("key4"))
    }
    
    func testMemoryPressureClearance() async {
        // Given: 缓存多个缓冲区
        cache = AudioCache(maxItems: 10)
        for i in 0..<10 {
            await cache.set("key\(i)", makeTestBuffer(duration: 10, id: "\(i)"))
        }
        
        // When: 模拟 Level 2 内存压力（清理 ±30s 外）
        await cache.handleMemoryPressure(level: .urgent, currentTime: CMTime(seconds: 50, preferredTimescale: 600))
        
        // Then: 仅保留 20s–80s 范围内的缓存
        let remainingCount = await cache.itemCount()
        XCTAssertLessThan(remainingCount, 10)
    }
}
```

#### PreloadQueue 测试用例
```swift
class PreloadQueueTests: XCTestCase {
    func testFastFirstFramePriority() async {
        let queue = PreloadQueue()
        var completedTasks: [String] = []
        
        // 模拟任务
        let normalTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            completedTasks.append("normal")
        }
        
        let fastTask = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            completedTasks.append("fast")
        }
        
        // 先入队普通任务，再入队快速首帧任务
        await queue.enqueue(normalTask, priority: .preload)
        await queue.enqueue(fastTask, priority: .fastFirstFrame)
        
        await queue.waitForAll()
        
        // 验证快速首帧先完成
        XCTAssertEqual(completedTasks.first, "fast")
    }
}
```

### 5.2 集成测试

#### E2E: 媒体加载 → 首帧字幕
```swift
// apps/PrismPlayer/PrismPlayer-macOS-Tests/FirstFrameE2ETests.swift

@MainActor
class FirstFrameE2ETests: XCTestCase {
    var viewModel: PlayerViewModel!
    var mockAsrEngine: MockAsrEngine!
    
    func testFirstFrameLatency() async throws {
        // Given: 加载 30s 测试视频
        let testURL = Bundle.main.url(forResource: "test-video-30s", withExtension: "mp4")!
        mockAsrEngine.mockSegments = [
            AsrSegment(start: 0, end: 5, text: "First subtitle")
        ]
        
        // When: 加载媒体
        let startTime = Date()
        try await viewModel.playerService.load(url: testURL)
        
        // 等待首帧字幕
        let firstSubtitle = try await withTimeout(seconds: 8) {
            await viewModel.$currentSubtitles
                .first { !$0.isEmpty }
        }
        
        let latency = Date().timeIntervalSince(startTime)
        
        // Then: P95 < 5s（高端设备）
        XCTAssertNotNil(firstSubtitle)
        XCTAssertLessThan(latency, 5.0, "首帧时间超标: \(latency)s")
        
        // 记录性能指标
        await MetricsService.shared.record(.firstFrameLatency(latency))
    }
}
```

### 5.3 验收标准汇总

- [ ] **所有单测通过**（覆盖率 ≥ 80%）
  - AVAssetAudioExtractor: 正常流程、边界条件、错误处理、取消
  - AudioCache: LRU 淘汰、内存压力、持久化
  - PreloadQueue: 优先级调度、并发安全

- [ ] **集成测试通过**
  - 首帧字幕 E2E：P95 < 5s（短视频，高端设备）
  - 双路并行无竞态条件
  - 内存压力不影响播放连续性

- [ ] **性能测试**（至少 3 个设备档位）
  - 首帧时间：高端 ≤ 5s, 中端 ≤ 8s, 低端 ≤ 12s
  - 音频抽取耗时：10s 音频 P95 < 200ms
  - 内存峰值：≤ 15MB（10 个 30s 缓存）
  - RTF 分布：高端 ≥ 1.0, 中端 ≥ 0.5, 低端 ≥ 0.3

---

## 6. 观测与验证

### 6.1 日志/指标/追踪埋点

#### 关键指标

```swift
// packages/PrismCore/Sources/PrismCore/Metrics/AudioMetrics.swift

public enum AudioMetricKey: String {
    case firstFrameLatency = "audio.first_frame_latency"
    case extractionDuration = "audio.extraction_duration"
    case cacheHitRate = "audio.cache_hit_rate"
    case memoryPressureLevel = "audio.memory_pressure_level"
    case preloadQueueDepth = "audio.preload_queue_depth"
}

// 埋点示例
await MetricsService.shared.record(
    .firstFrameLatency(latency),
    tags: ["device_tier": "high", "video_duration": "30s"]
)
```

#### 日志分类

```swift
// OSLog 子系统与分类
let logger = Logger(subsystem: "com.prismplayer.core", category: "audio")

// 级别使用
logger.info("开始抽取音频: range=\(timeRange)")           // .info
logger.debug("缓存命中: key=\(cacheKey)")                  // .debug
logger.error("音频抽取失败: \(error)")                      // .error
logger.notice("触发内存压力清理: level=\(level)")          // .notice
```

### 6.2 验证方法

#### 本地验证
```bash
# 运行性能测试
xcodebuild test \
  -workspace PrismPlayer.xcworkspace \
  -scheme PrismCore \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:PrismCoreTests/AudioPerformanceTests

# 查看指标
tail -f ~/Library/Logs/PrismPlayer/metrics.json
```

#### CI 验证
```yaml
# .github/workflows/performance-test.yml
- name: Audio Performance Test
  run: |
    xcodebuild test -scheme PrismCore \
      -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
      -only-testing:PrismCoreTests/AudioPerformanceTests
    
    # 提取指标
    FIRST_FRAME_P95=$(jq '.first_frame_latency.p95' metrics.json)
    if (( $(echo "$FIRST_FRAME_P95 > 5.0" | bc -l) )); then
      echo "::error::首帧时间超标: ${FIRST_FRAME_P95}s"
      exit 1
    fi
```

#### 真机验证
- **设备档位**:
  - 高端: iPhone 15 Pro / M3 MacBook Pro
  - 中端: iPhone 13 / M1 MacBook Air
  - 低端: iPhone SE 3rd / Intel MacBook Pro 2019

- **测试场景**:
  - 短视频（10–30s）：首帧时间分布
  - 长视频（60min+）：内存压力响应
  - 后台切换：缓存恢复与预加载暂停

---

## 7. 风险与未决

### 风险 A: 首帧时间目标无法在低端设备满足

- **描述**: P95 < 5s 目标可能在 iPhone SE 3rd 无法达成（实测 ~8s）
- **缓解措施**:
  1. 降级策略：低端设备默认使用 `conservative` 预加载策略（5s 快速窗）
  2. UI 提示：首帧超过 8s 时提示用户"设备性能受限，建议使用更小模型"
  3. 模型自动降级：检测设备性能分级，自动选择 tiny 模型
  4. 后续优化：Sprint 3 优化音频抽取（Metal 加速 PCM 转换）
- **负责人**: @架构
- **截止时间**: 2025-11-06（风险评估完成，决定是否调整 KPI）

### 风险 B: 内存压力频繁触发导致卡顿

- **描述**: 长视频播放时频繁触发 Level 2/3 清理，导致重复抽取卡顿
- **缓解措施**:
  1. 增加内存阈值监控（避免"抖动"：连续 3 次警告才触发 Level 3）
  2. 优先级保护：当前播放 ±15s 永不清理
  3. 后台预加载降速：检测内存压力时暂停预加载队列
  4. 测试覆盖：集成测试模拟连续内存警告场景
- **负责人**: @工程
- **截止时间**: 2025-11-08（集成测试通过）

### 未决问题 C: macOS App Nap 影响后台预加载

- **描述**: macOS 进入 App Nap 时后台预加载可能被暂停
- **解决方案**:
  - 本 Sprint：仅确保前台预加载正常（macOS 暂不处理 App Nap）
  - Sprint 2：使用 `NSProcessInfo.beginActivity` 防止 App Nap
  - 文档标记：HLD 补充 macOS 后台策略
- **负责人**: @架构
- **截止时间**: Sprint 2 启动前

---

## 定义完成（DoD）

- [ ] **CI 通过**（构建/测试/SwiftLint 严格模式）
  - [ ] 构建矩阵：iOS 17+, macOS 14+
  - [ ] 单元测试覆盖率 ≥ 80%（AudioExtractor, AudioCache, PreloadQueue）
  - [ ] SwiftLint 无 error，warning < 5

- [ ] **无硬编码字符串**（国际化）
  - [ ] 所有错误消息使用 `NSLocalizedString`
  - [ ] 日志消息使用英文（便于调试）
  - [ ] UI 相关文本（如有）已国际化

- [ ] **文档更新**
  - [ ] README 更新：新增 AudioExtractor 使用说明
  - [ ] CHANGELOG 记录：Task-102 新增功能
  - [ ] HLD 同步：补充双路并行首帧策略、三级内存清理策略
  - [ ] API 文档：AudioExtractor 协议完整注释

- [ ] **关键路径测试覆盖**
  - [ ] 首帧 E2E 测试通过（P95 < 5s）
  - [ ] 内存压力测试通过（不影响播放）
  - [ ] 并发安全测试通过（无死锁/竞态）

- [ ] **性能测试通过**
  - [ ] 首帧时间：高端 ≤ 5s, 中端 ≤ 8s, 低端 ≤ 12s
  - [ ] 音频抽取耗时：10s 音频 P95 < 200ms
  - [ ] 内存峰值：≤ 15MB（10 个 30s 缓存）
  - [ ] 性能基线已记录（至少 3 个设备档位）

- [ ] **可观测埋点到位**
  - [ ] 首帧时间指标正确记录
  - [ ] RTF 分布数据已采样
  - [ ] 内存压力事件已记录
  - [ ] OSLog 分类清晰（subsystem + category）

- [ ] **Code Review 通过**
  - [ ] 至少 1 位 reviewer 批准
  - [ ] 无遗留 TODO/FIXME（或已转为新 Issue）
  - [ ] 代码符合 Swift 最佳实践

- [ ] **已合并到主分支**
  - [ ] 所有 PR 已合并（PR1, PR2, PR3）
  - [ ] Git 提交消息清晰（遵循 Conventional Commits）

---

**模板版本**: v1.1  
**文档版本**: v1.1  
**最后更新**: 2025-10-30  
**变更记录**:
- v1.1 (2025-10-30): 新增 §2 音频格式技术说明（PCM、采样率、位深度、声道详解），新增文档导航，更新协议注释
- v1.0 (2025-10-30): 初始版本，基于模板创建
