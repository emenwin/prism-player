# Task-007: 指标与日志占位实现

## 任务概述

**类型**: 基础设施  
**故事点**: 2 SP  
**优先级**: P1（高）  
**负责人**: 待分配

## 背景

建立完善的日志和性能指标体系是保障应用质量和问题诊断的基础。本任务创建：
- 统一的日志框架（基于 OSLog）
- 性能指标采集协议和占位实现
- 为后续功能开发提供可观测性基础

根据 Sprint Plan 要求，需要建立：
- 首帧字幕可见时间（P95）
- RTF（Real-Time Factor）处理率
- 时间同步偏差测量
- 内存和能耗监控基础

## 任务目标

创建日志分类、性能指标协议和基础实现，为 Sprint 1 及后续开发提供可观测性支持。

## 详细需求

### 1. OSLog 日志框架

基于 Apple 原生的 OSLog（统一日志系统）创建分类化日志：

#### 日志分类（Categories）

```swift
// 核心业务日志
- Player: 播放器相关（播放/暂停/seek/状态变化）
- ASR: 语音识别相关（模型加载/推理/结果）
- Subtitle: 字幕相关（渲染/同步/样式）
- Storage: 数据存储相关（数据库操作/缓存）
- Network: 网络相关（模型下载/检查更新）
- UI: UI 交互相关（用户操作/页面导航）

// 系统级日志
- Performance: 性能指标（首帧时间/RTF/内存）
- Lifecycle: 应用生命周期（启动/后台/前台）
- Error: 错误和异常（崩溃前兆/降级触发）
```

#### 日志级别（Levels）

遵循 OSLog 标准级别：
- **debug**: 调试信息（仅 Debug 构建）
- **info**: 一般信息（关键流程节点）
- **notice**: 重要通知（状态变化）
- **error**: 错误但可恢复
- **fault**: 严重错误（不应发生）

### 2. 性能指标协议（Metrics Protocol）

定义统一的性能指标采集接口：

#### 关键指标

**首帧指标（First Frame Metrics）**:
- 媒体选择到首个字幕显示的耗时
- 预加载音频提取耗时
- 首次 ASR 推理耗时

**实时性能指标（Runtime Metrics）**:
- RTF（Real-Time Factor）: 推理耗时 / 音频时长
- 时间同步偏差: |字幕时间 - 播放器时间|
- 内存使用: 峰值、平均值、趋势

**资源指标（Resource Metrics）**:
- 音频缓存大小
- 模型文件大小
- 数据库大小
- 磁盘可用空间

**质量指标（Quality Metrics）**:
- ASR 置信度分布
- 段识别成功率
- 导出成功率

### 3. 指标采集器实现

创建轻量级指标采集器：

```swift
protocol MetricsCollector {
    // 记录性能指标
    func recordTiming(_ name: String, duration: TimeInterval, metadata: [String: Any]?)
    
    // 记录计数指标
    func recordCount(_ name: String, value: Int, metadata: [String: Any]?)
    
    // 记录分布指标
    func recordDistribution(_ name: String, value: Double, metadata: [String: Any]?)
    
    // 查询指标（本地查看）
    func getMetrics(category: String?) -> [Metric]
}
```

**实现策略**:
- Sprint 0: 仅记录到本地（UserDefaults/文件）
- Sprint 2+: 可选集成第三方分析（如 Firebase Analytics/自建）

### 4. 问题诊断包基础

为问题反馈建立基础：

**诊断信息收集**:
- 设备信息（型号/OS 版本/芯片类型）
- 应用版本和构建号
- 关键日志片段（最近 100 条）
- 性能指标摘要
- 配置快照（不含敏感信息）

**隐私保护**:
- 不包含媒体文件内容
- 不包含用户个人信息
- 字幕内容脱敏处理
- 文件路径仅保留文件名

## 完成标准

- ✅ OSLog 分类定义完成（8+ 分类）
- ✅ 日志级别和最佳实践文档
- ✅ MetricsCollector 协议定义
- ✅ 基础指标采集器实现（本地存储）
- ✅ 诊断包框架占位（数据结构定义）
- ✅ 示例代码和使用文档
- ✅ ADR 文档（日志和指标方案选择）

## 交付物清单

### 1. 日志框架

```
PrismCore/Sources/PrismCore/Logging/
├── Logger.swift               # OSLog 封装和分类定义
├── LogCategory.swift          # 日志分类枚举
└── README.md                  # 日志使用指南
```

### 2. 指标框架

```
PrismCore/Sources/PrismCore/Metrics/
├── MetricsCollector.swift     # 指标协议定义
├── LocalMetricsCollector.swift # 本地实现
├── Metric.swift               # 指标数据结构
└── README.md                  # 指标使用指南
```

### 3. 诊断框架

```
PrismCore/Sources/PrismCore/Diagnostics/
├── DiagnosticsCollector.swift # 诊断信息收集
├── DiagnosticReport.swift     # 诊断报告结构
└── README.md                  # 诊断包说明
```

### 4. 文档

```
docs/adr/
└── 0004-logging-metrics-strategy.md  # ADR: 日志和指标方案
```

## 技术细节

### OSLog 使用示例

```swift
import OSLog

// 定义子系统
private let subsystem = "com.prismplayer.app"

// 定义日志分类
extension Logger {
    static let player = Logger(subsystem: subsystem, category: "Player")
    static let asr = Logger(subsystem: subsystem, category: "ASR")
    static let performance = Logger(subsystem: subsystem, category: "Performance")
}

// 使用示例
Logger.player.info("▶️ Playback started: \(mediaURL.lastPathComponent)")
Logger.asr.debug("Loading model: \(modelName)")
Logger.performance.notice("First frame rendered in \(duration)ms")
```

### 性能指标示例

```swift
// 记录首帧时间
MetricsCollector.shared.recordTiming(
    "subtitle.first_frame",
    duration: 1.23,
    metadata: ["model": "whisper-base", "device": "iPhone15Pro"]
)

// 记录 RTF
MetricsCollector.shared.recordDistribution(
    "asr.rtf",
    value: 0.45,
    metadata: ["segment_duration": 30.0]
)

// 记录时间偏差
MetricsCollector.shared.recordDistribution(
    "subtitle.time_offset",
    value: abs(subtitleTime - playerTime),
    metadata: ["segment_index": 5]
)
```

### 诊断报告示例

```swift
struct DiagnosticReport: Codable {
    let timestamp: Date
    let appVersion: String
    let deviceInfo: DeviceInfo
    let logs: [LogEntry]  // 最近 100 条
    let metrics: MetricsSummary
    let configuration: ConfigSnapshot
}
```

## 验收标准

### 功能验收

1. ✅ **日志框架可用**
   - 所有分类定义清晰
   - 日志级别正确使用
   - Console.app 可过滤查看

2. ✅ **指标采集正常**
   - 协议定义完整
   - 本地存储可查询
   - 示例代码可运行

3. ✅ **诊断包结构完整**
   - 数据结构定义清晰
   - 隐私保护到位
   - 可序列化为 JSON

### 质量验收

1. ✅ **性能开销低**
   - 日志不阻塞主线程
   - 指标采集异步化（Actor）
   - 内存占用最小化

2. ✅ **文档完善**
   - 每个模块有 README
   - 包含使用示例
   - 最佳实践说明

3. ✅ **ADR 完整**
   - 方案选择理由
   - 替代方案对比
   - 实施计划

## 实施总结

### 已完成交付物

✅ **日志框架** (完成于 2025-10-24)
- `PrismCore/Sources/PrismCore/Logging/Logger.swift` - OSLog 封装，9个日志分类
- `PrismCore/Sources/PrismCore/Logging/README.md` - 完整使用指南和最佳实践

✅ **指标框架** (完成于 2025-10-24)
- `PrismCore/Sources/PrismCore/Metrics/Metric.swift` - 指标数据结构和统计计算
- `PrismCore/Sources/PrismCore/Metrics/MetricsCollector.swift` - 协议定义
- `PrismCore/Sources/PrismCore/Metrics/LocalMetricsCollector.swift` - Actor实现，UserDefaults持久化
- `PrismCore/Sources/PrismCore/Metrics/README.md` - 完整使用文档和示例

✅ **诊断框架** (完成于 2025-10-24)
- `PrismCore/Sources/PrismCore/Diagnostics/DiagnosticReport.swift` - 诊断报告数据结构
- `PrismCore/Sources/PrismCore/Diagnostics/DiagnosticsCollector.swift` - Actor实现，自动收集系统信息

✅ **架构决策文档** (完成于 2025-10-24)
- `docs/adr/0004-logging-metrics-strategy.md` - 日志和指标方案 ADR
- 更新 `docs/adr/README.md`

### 技术实现亮点

1. **OSLog 深度集成**
   - 9个业务日志分类（Player, ASR, Subtitle, Storage, Network, UI, Performance, Lifecycle, Error）
   - 5个日志级别（debug, info, notice, error, fault）
   - 子系统标识：`com.prismplayer.app`

2. **Actor-based 指标采集**
   - 使用 Swift Actor 确保线程安全
   - UserDefaults 轻量级持久化
   - 7天自动清理机制
   - 支持 P50/P95/P99 统计

3. **预定义指标常量**
   - 首帧指标（total, audioExtraction, asrInference, rendering）
   - RTF 指标（overall, perSegment）
   - 时间同步指标（offset, absoluteOffset）
   - 资源指标（memory, cache, diskSpace）
   - 质量指标（confidence, success/failure counts）

4. **完善的诊断框架**
   - 自动收集设备信息（iOS/macOS 适配）
   - 系统信息（CPU核心数、物理内存、磁盘空间、系统运行时间）
   - 集成指标摘要
   - JSON 导出功能
   - 隐私保护设计

### 代码质量

- ✅ 所有代码通过 SwiftLint strict mode 检查
- ✅ 完整的文档注释（中英文双语）
- ✅ Actor 并发安全设计
- ✅ Xcode 构建成功（PrismCore 包）

### 问题与解决

1. **文件名冲突**: 发现两个 `AsrSegment.swift`
   - 解决方案: 删除 `Models/AsrSegment.swift`，保留 `Storage/Models/AsrSegment.swift`（GRDB 版本）

2. **Actor 闭包 self 引用**: Swift 并发要求显式 self
   - 解决方案: 在异步闭包中使用 `self.metrics`

3. **min() 函数歧义**: 与 Swift.min() 冲突
   - 解决方案: 使用命名空间 `Swift.min()`

## 依赖关系

### 前置任务

- Task-002: 多平台工程脚手架（需要 PrismCore 包）
- Task-005: 数据存储（指标可选持久化到数据库）

### 后续任务

- Sprint 1 所有任务（使用日志和指标）
- Task-009: 测试架构（性能测试需要指标）

## 参考资料

### Apple 官方文档

- [OSLog and Unified Logging](https://developer.apple.com/documentation/oslog)
- [Generating Log Messages from Your Code](https://developer.apple.com/documentation/os/logging/generating_log_messages_from_your_code)
- [MetricKit](https://developer.apple.com/documentation/metrickit) - 系统级性能指标

### 最佳实践

- [WWDC22: Debug Swift debugging with LLDB](https://developer.apple.com/videos/play/wwdc2022/110370/)
- [WWDC21: Explore structured concurrency in Swift](https://developer.apple.com/videos/play/wwdc2021/10134/)
- [Swift Logging API](https://github.com/apple/swift-log) - 跨平台日志抽象

### 工具

- **Console.app**: macOS 系统日志查看器
- **Instruments**: Time Profiler, Allocations
- **MetricKit**: 系统性能和诊断数据收集

---

**任务状态**: ✅ 已完成  
**创建日期**: 2025-10-24  
**完成日期**: 2025-10-24  
**实际工作量**: 2 SP（符合预估）
