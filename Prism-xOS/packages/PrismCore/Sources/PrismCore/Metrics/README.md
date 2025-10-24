# 性能指标框架使用指南 / Metrics Framework Guide

本文档说明 Prism Player 的性能指标框架使用方法和最佳实践。

This document explains the metrics framework usage and best practices for Prism Player.

## 概述 / Overview

Prism Player 使用自定义的指标采集框架，用于监控关键性能指标（KPI）：
- 首帧字幕可见时间（P95）
- RTF（Real-Time Factor）处理率
- 时间同步偏差
- 内存和资源使用

Prism Player uses a custom metrics collection framework to monitor key performance indicators (KPIs):
- First frame subtitle visibility time (P95)
- RTF (Real-Time Factor) processing rate
- Time synchronization deviation
- Memory and resource usage

## 快速开始 / Quick Start

### 基础使用 / Basic Usage

```swift
import PrismCore

// 获取共享采集器
let collector = await SharedMetricsCollector.shared

// 记录首帧时间
let startTime = Date()
// ... 执行首帧渲染
let duration = Date().timeIntervalSince(startTime)
await collector.recordTiming(
    Metric.FirstFrame.total,
    duration: duration,
    metadata: ["model": "whisper-base", "device": "iPhone15Pro"]
)

// 记录 RTF
await collector.recordDistribution(
    Metric.RTF.overall,
    value: 0.45,
    metadata: ["segment_duration": "30.0"]
)

// 记录时间偏差
let offset = abs(subtitleTime - playerTime)
await collector.recordDistribution(
    Metric.TimeSync.absoluteOffset,
    value: offset
)
```

## 指标类型 / Metric Types

### 1. 计时指标（Timing Metrics）

**用途**: 记录操作耗时

```swift
// 方式 1: 手动计时
let startTime = Date()
// ... 执行操作
let duration = Date().timeIntervalSince(startTime)
await collector.recordTiming("operation.name", duration: duration)

// 方式 2: 使用闭包（推荐）
func measure<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
    let start = Date()
    defer {
        let duration = Date().timeIntervalSince(start)
        Task {
            await collector.recordTiming(name, duration: duration)
        }
    }
    return try await operation()
}

// 使用示例
let result = await measure("audio.extraction") {
    try await extractAudio()
}
```

### 2. 计数指标（Count Metrics）

**用途**: 记录事件发生次数

```swift
// 成功次数
await collector.recordCount(
    Metric.Quality.segmentSuccess,
    value: 1
)

// 失败次数
await collector.recordCount(
    Metric.Quality.segmentFailure,
    value: 1,
    metadata: ["error": "timeout"]
)

// 导出成功
await collector.recordCount(
    Metric.Quality.exportSuccess,
    value: 1,
    metadata: ["format": "srt"]
)
```

### 3. 分布指标（Distribution Metrics）

**用途**: 记录数值分布，用于计算 P50/P95/P99

```swift
// RTF 分布
await collector.recordDistribution(
    Metric.RTF.perSegment,
    value: rtf,
    metadata: [
        "model": modelName,
        "segment_index": "\(index)",
        "duration": "\(duration)"
    ]
)

// 置信度分布
await collector.recordDistribution(
    Metric.Quality.confidence,
    value: confidence,
    metadata: ["language": "en"]
)

// 内存使用
let memoryMB = Double(memoryBytes) / 1024 / 1024
await collector.recordDistribution(
    Metric.Resource.memoryAverage,
    value: memoryMB
)
```

## 预定义指标常量 / Predefined Metric Constants

### 首帧指标 / First Frame Metrics

```swift
Metric.FirstFrame.total                  // 总首帧时间
Metric.FirstFrame.audioExtraction        // 音频提取耗时
Metric.FirstFrame.asrInference           // ASR 推理耗时
Metric.FirstFrame.rendering              // 渲染耗时
```

### RTF 指标 / RTF Metrics

```swift
Metric.RTF.overall                       // 整体 RTF
Metric.RTF.perSegment                    // 每段 RTF
```

### 时间同步指标 / Time Sync Metrics

```swift
Metric.TimeSync.offset                   // 时间偏差（带符号）
Metric.TimeSync.absoluteOffset           // 绝对时间偏差
```

### 资源指标 / Resource Metrics

```swift
Metric.Resource.memoryPeak               // 内存峰值
Metric.Resource.memoryAverage            // 平均内存
Metric.Resource.cacheSize                // 缓存大小
Metric.Resource.diskSpace                // 可用磁盘空间
```

### 质量指标 / Quality Metrics

```swift
Metric.Quality.confidence                // ASR 置信度
Metric.Quality.segmentSuccess            // 段识别成功次数
Metric.Quality.segmentFailure            // 段识别失败次数
Metric.Quality.exportSuccess             // 导出成功次数
Metric.Quality.exportFailure             // 导出失败次数
```

## 查询指标 / Querying Metrics

### 基础查询 / Basic Queries

```swift
// 查询所有指标
let allMetrics = await collector.getAllMetrics()

// 查询指定名称的指标
let firstFrameMetrics = await collector.getMetrics(
    name: Metric.FirstFrame.total
)

// 按时间范围查询
let recentMetrics = await collector.getMetrics(
    name: nil,
    startDate: Date().addingTimeInterval(-3600),  // 最近 1 小时
    endDate: Date()
)
```

### 统计信息 / Statistics

```swift
// 获取统计信息
if let stats = await collector.getStatistics(for: Metric.FirstFrame.total) {
    print("首帧时间统计:")
    print("  样本数: \(stats.count)")
    print("  最小值: \(stats.min)ms")
    print("  最大值: \(stats.max)ms")
    print("  平均值: \(stats.mean)ms")
    print("  中位数: \(stats.p50)ms")
    print("  P95: \(stats.p95)ms")
    print("  P99: \(stats.p99)ms")
}
```

### 导出 JSON / Export JSON

```swift
// 导出所有指标
let jsonData = try await collector.exportJSON()
let jsonString = String(data: jsonData, encoding: .utf8)

// 导出最近 24 小时的指标
let startDate = Date().addingTimeInterval(-24 * 3600)
let recentData = try await collector.exportJSON(
    startDate: startDate,
    endDate: Date()
)
```

## 最佳实践 / Best Practices

### 1. 使用元数据标注上下文

```swift
// ✅ 推荐：包含足够上下文
await collector.recordTiming(
    Metric.FirstFrame.total,
    duration: duration,
    metadata: [
        "model": "whisper-base",
        "device": "iPhone15,2",
        "os_version": "iOS 17.0",
        "media_duration": "120.5"
    ]
)

// ❌ 避免：缺少上下文
await collector.recordTiming(
    Metric.FirstFrame.total,
    duration: duration
)
```

### 2. 异步记录避免阻塞

```swift
// ✅ 推荐：使用 Task 异步记录
Task {
    await collector.recordTiming(
        "operation.name",
        duration: duration
    )
}

// 主线程继续执行
continueWork()
```

### 3. 批量操作减少调用

```swift
// ✅ 推荐：批量记录相关指标
let metrics = [
    Metric.timing(Metric.FirstFrame.audioExtraction, duration: extractTime),
    Metric.timing(Metric.FirstFrame.asrInference, duration: inferenceTime),
    Metric.timing(Metric.FirstFrame.rendering, duration: renderTime)
]

for metric in metrics {
    // 内部会批量优化
    await addMetric(metric)
}
```

### 4. 定期清理旧数据

```swift
// 保留最近 7 天的数据
let cutoffDate = Date().addingTimeInterval(-7 * 24 * 3600)
await collector.cleanupMetrics(olderThan: cutoffDate)
```

## 性能监控示例 / Performance Monitoring Examples

### 监控首帧时间

```swift
func monitorFirstFrame() async {
    let startTime = Date()
    
    // 1. 音频提取
    let audioStart = Date()
    try await extractAudio()
    let audioTime = Date().timeIntervalSince(audioStart)
    await collector.recordTiming(
        Metric.FirstFrame.audioExtraction,
        duration: audioTime
    )
    
    // 2. ASR 推理
    let asrStart = Date()
    let segments = try await runASR()
    let asrTime = Date().timeIntervalSince(asrStart)
    await collector.recordTiming(
        Metric.FirstFrame.asrInference,
        duration: asrTime
    )
    
    // 3. 渲染字幕
    let renderStart = Date()
    await renderSubtitle(segments.first!)
    let renderTime = Date().timeIntervalSince(renderStart)
    await collector.recordTiming(
        Metric.FirstFrame.rendering,
        duration: renderTime
    )
    
    // 4. 总耗时
    let totalTime = Date().timeIntervalSince(startTime)
    await collector.recordTiming(
        Metric.FirstFrame.total,
        duration: totalTime,
        metadata: [
            "audio_ms": "\(audioTime * 1000)",
            "asr_ms": "\(asrTime * 1000)",
            "render_ms": "\(renderTime * 1000)"
        ]
    )
}
```

### 监控 RTF

```swift
func monitorRTF(segmentDuration: TimeInterval, inferenceTime: TimeInterval) async {
    let rtf = inferenceTime / segmentDuration
    
    await collector.recordDistribution(
        Metric.RTF.perSegment,
        value: rtf,
        metadata: [
            "segment_duration": "\(segmentDuration)",
            "inference_time": "\(inferenceTime)"
        ]
    )
    
    // 记录到日志
    Logger.performance.info("RTF: \(rtf, format: .fixed(precision: 2))")
}
```

### 监控时间同步偏差

```swift
func monitorTimeSync(subtitleTime: TimeInterval, playerTime: TimeInterval) async {
    let offset = subtitleTime - playerTime
    let absoluteOffset = abs(offset)
    
    // 记录带符号偏差
    await collector.recordDistribution(
        Metric.TimeSync.offset,
        value: offset
    )
    
    // 记录绝对偏差（用于 P95 计算）
    await collector.recordDistribution(
        Metric.TimeSync.absoluteOffset,
        value: absoluteOffset
    )
    
    // 如果偏差过大，记录错误
    if absoluteOffset > 0.2 {  // 200ms
        Logger.error.error("Time sync deviation too large: \(absoluteOffset)s")
    }
}
```

## 集成诊断包 / Integration with Diagnostic Reports

```swift
// 获取指标摘要用于诊断包
let summary = await collector.getSummary()

let report = DiagnosticReport(
    // ... 其他字段
    metrics: summary
)
```

## 常见问题 / FAQ

### Q: 指标数据存储在哪里？

A: 目前存储在 `UserDefaults` 中，轻量级持久化。未来可选迁移到 SQLite 数据库以支持更复杂的查询。

### Q: 指标会影响性能吗？

A: 影响极小。指标采集使用 Actor 异步化，不阻塞主线程。单次记录耗时 < 1ms。

### Q: 如何查看历史指标？

A: 使用 `getMetrics(startDate:endDate:)` 查询，或导出 JSON 后用外部工具分析。

### Q: 指标数据会上传吗？

A: 默认不上传。仅本地存储，符合隐私优先原则。未来可选集成第三方分析平台（需用户同意）。

### Q: 如何定义自定义指标？

A: 使用自定义名称字符串即可，推荐使用命名空间前缀，如 `"custom.my_metric"`。

## 参考资料 / References

- [ADR-0004: 日志与性能指标方案](../../../docs/adr/0004-logging-metrics-strategy.md)
- [Sprint Plan v0.2: KPI 定义](../../../docs/scrum/sprint-plan-v0.2-updated.md)
- [MetricKit Documentation](https://developer.apple.com/documentation/metrickit)

---

**维护者**: Prism Player Team  
**最后更新**: 2025-10-24
