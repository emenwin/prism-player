# PrismCore

核心业务层 Package，提供通用模型、协议与服务。

## 职责

- 定义领域模型（Domain Models）
- 定义核心协议（Core Protocols）
- 提供基础服务（Base Services）
- 音频处理与预加载
- 无平台特定依赖，可跨 iOS/macOS 共享

## 模块结构

```
PrismCore/
├── Models/          # 领域模型（AsrSegment, MediaInfo 等）
├── Protocols/       # 核心协议（AsrEngine, PlayerService 等）
├── Services/        # 基础服务（存储、日志等）
├── Audio/           # 音频处理模块
│   ├── AudioBuffer.swift            # 音频缓冲区模型
│   ├── AudioExtractor.swift         # 音频抽取协议
│   ├── AVAssetAudioExtractor.swift  # AVAssetReader 实现
│   ├── AudioPreloadService.swift    # 音频预加载服务
│   ├── AudioCache.swift             # 音频缓存管理
│   ├── PreloadStrategy.swift        # 预加载策略配置
│   └── MemoryPressureLevel.swift    # 内存压力等级
├── Scheduling/      # 调度模块
│   ├── PreloadQueue.swift           # 优先级调度队列
│   └── MemoryPressureMonitor.swift  # 内存压力监控
├── Storage/         # 存储模块
├── Logging/         # 日志模块
└── Metrics/         # 指标采集模块
```

## 核心功能

### 音频预加载与极速首帧

提供音频预加载服务，实现双路并行首帧策略，支持 LRU 缓存和三级内存压力响应。

#### 使用示例

```swift
import PrismCore
import AVFoundation

// 1. 初始化服务
let extractor = AVAssetAudioExtractor()
let preloadService = AudioPreloadService(
    extractor: extractor,
    strategy: .default,
    maxConcurrentTasks: 3
)

// 2. 开始预加载
let asset = AVAsset(url: mediaURL)
try await preloadService.startPreload(for: asset)

// 3. 获取首帧音频（0-10s）
let firstFrameBuffer = try await preloadService.getFirstFrameBuffer()

// 首帧缓冲区包含：
// - samples: [Float] 音频 PCM 数据（16kHz mono）
// - duration: TimeInterval 音频时长
// - sizeInBytes: Int 内存占用（64 KB/s）
```

#### 核心特性

**双路并行首帧策略**：
- 路径 A：抽取前 5s → 极速返回首帧
- 路径 B：抽取 5-10s → 补充首屏字幕
- 路径 C：抽取 10-30s → 后台预加载

**性能目标**：
- 短视频（<5min）高端设备：P95 < 5s
- 中端设备：P95 < 8s
- 低端设备：P95 < 12s

**三级内存压力响应**：
- Normal：保留全部缓存
- Warning（1次警告）：清理远端缓存（保留 ±60s）
- Urgent（3次/30s）：清理更多缓存（保留 ±30s）
- Critical（5次/60s）：仅保留播放附近（保留 ±15s）

**优先级调度**：
- fastFirstFrame > seek > scroll > preload
- 最多 3 个并发任务

### 音频格式转换

自动将任意音频格式转换为 ASR 友好格式：

```
原始音频          转换             目标格式
─────────────  → ────────────  →  ──────────────
AAC/MP3/FLAC    AVAssetReader     PCM Float32
48kHz/44.1kHz   重采样            16 kHz
Stereo (2ch)    声道混合          Mono (1ch)
16-bit Int      位深度转换        32-bit Float

数据量减少：67%
处理速度提升：3×
```

## 依赖关系

- **依赖**: 
  - AVFoundation（音频抽取）
  - OSLog（日志）
- **被依赖**: PrismASR, PrismKit

## 测试覆盖

### 单元测试
- AudioBufferTests: 8 个用例
- AVAssetAudioExtractorTests: 7 个用例
- PreloadQueueTests: 13 个用例
- AudioCacheTests: 18 个用例
- MemoryPressureMonitorTests: 9 个用例

### 集成测试
- FirstFrameE2ETests: 13 个用例（首帧端到端测试）

### 性能测试
- 音频抽取：10s 音频 < 200ms
- 首帧时间：P95 < 15s（测试环境）
- 内存占用：1s = 64KB, 30s = 1.92MB

## 开发规范

- 所有公开类型必须添加文档注释
- 遵循 SwiftLint 严格模式
- 单元测试覆盖率 ≥ 70%
- 性能关键路径需要性能测试

## 参考文档

- [Task-102: 音频预加载与极速首帧](../../../docs/scrum/iOS-macOS/tasks/sprint-1/task-102-audio-preload-fast-first-frame.md)
- [HLD v0.2](../../../docs/tdd/iOS-macOS/hld-ios-macos-v0.2.md)
- [ADR-0004: 日志与指标策略](../../../docs/adr/iOS-macOS/0004-logging-metrics-strategy.md)
