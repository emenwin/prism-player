# 日志框架使用指南 / Logging Framework Guide

本文档说明 Prism Player 的日志框架使用方法和最佳实践。

This document explains the logging framework usage and best practices for Prism Player.

## 概述 / Overview

Prism Player 使用 Apple 的 **OSLog（统一日志系统）** 作为日志框架，提供：
- 高性能异步日志写入
- 结构化日志和元数据支持
- 自动隐私保护
- Console.app 和 Instruments 集成

Prism Player uses Apple's **OSLog (Unified Logging System)** as the logging framework, providing:
- High-performance asynchronous log writing
- Structured logging and metadata support
- Automatic privacy protection
- Console.app and Instruments integration

## 快速开始 / Quick Start

### 基础使用 / Basic Usage

```swift
import OSLog

// 播放器日志
Logger.player.info("▶️ Playback started: video.mp4")
Logger.player.debug("Current time: \(player.currentTime)")

// ASR 日志
Logger.asr.notice("Model loaded: whisper-base (74MB)")
Logger.asr.info("Processing segment: 0.0s - 30.0s")

// 字幕日志
Logger.subtitle.info("Rendered subtitle at \(timestamp)s")
Logger.subtitle.debug("Active subtitle count: \(count)")
```

### 日志级别选择 / Log Level Selection

| 级别 | 使用场景 | 示例 |
|-----|---------|------|
| **debug** | 详细调试信息（仅 Debug 构建） | `"Audio chunk extracted: 512KB"` |
| **info** | 关键流程节点 | `"Playback started: video.mp4"` |
| **notice** | 重要状态变化 | `"Model loaded: whisper-base"` |
| **error** | 可恢复错误 | `"Failed to load subtitle, retrying..."` |
| **fault** | 严重错误（不应发生） | `"Database corruption detected!"` |

**选择指南**:
- ✅ **info**: 用户操作、关键流程开始/结束
- ✅ **notice**: 状态机转换、模型加载、首帧渲染
- ✅ **error**: 网络失败、文件读写错误、ASR 推理失败
- ✅ **fault**: 数据库损坏、关键组件初始化失败

## 日志分类 / Log Categories

### 核心业务分类 / Core Business Categories

#### 1. Player（播放器）

**用途**: 播放器相关操作和状态变化

```swift
// 播放控制
Logger.player.info("▶️ Playback started")
Logger.player.info("⏸️ Playback paused")
Logger.player.info("⏹️ Playback stopped")

// Seek 操作
Logger.player.notice("Seeking to \(time)s")

// 状态变化
Logger.player.debug("Playback rate changed: \(rate)x")
Logger.player.notice("Playback finished")
```

#### 2. ASR（语音识别）

**用途**: ASR 模型加载、推理过程和结果

```swift
// 模型加载
Logger.asr.notice("Loading model: \(modelName)")
Logger.asr.info("Model loaded in \(duration)ms")

// 推理过程
Logger.asr.info("Processing segment [\(start)s - \(end)s]")
Logger.asr.debug("Inference took \(duration)ms, RTF: \(rtf)")

// 结果
Logger.asr.info("Recognized \(segmentCount) segments")
Logger.asr.error("Inference failed: \(error)")
```

#### 3. Subtitle（字幕）

**用途**: 字幕渲染、同步和样式

```swift
// 渲染
Logger.subtitle.info("Rendered subtitle: '\(text)'")
Logger.subtitle.debug("Active subtitles: \(count)")

// 同步
Logger.subtitle.notice("Time offset: \(offset)ms")

// 样式
Logger.subtitle.debug("Font size changed: \(size)pt")
```

#### 4. Storage（存储）

**用途**: 数据库操作、缓存管理

```swift
// 数据库操作
Logger.storage.info("Saved \(count) segments to database")
Logger.storage.debug("Query returned \(results) records")
Logger.storage.error("Database write failed: \(error)")

// 缓存管理
Logger.storage.info("Cache cleared: \(size) bytes freed")
Logger.storage.notice("Cache size: \(size) MB")
```

#### 5. Network（网络）

**用途**: 模型下载、网络请求

```swift
// 下载
Logger.network.info("Downloading model: \(modelName)")
Logger.network.notice("Download progress: \(progress)%")
Logger.network.info("Download completed: \(size) MB")

// 错误
Logger.network.error("Download failed: \(error)")
Logger.network.notice("Retrying download (\(attempt)/3)")
```

#### 6. UI（用户界面）

**用途**: 用户交互、页面导航

```swift
// 用户操作
Logger.ui.info("User tapped play button")
Logger.ui.info("User selected model: \(modelName)")

// 页面导航
Logger.ui.debug("Navigated to settings")
Logger.ui.debug("Presented model picker")
```

### 系统级分类 / System Categories

#### 7. Performance（性能指标）

**用途**: 性能指标记录

```swift
// 首帧时间
Logger.performance.notice("First frame time: \(duration)ms")

// RTF
Logger.performance.info("RTF: \(rtf, format: .fixed(precision: 2))")

// 内存
Logger.performance.debug("Memory usage: \(memory) MB")
```

#### 8. Lifecycle（生命周期）

**用途**: 应用启动、前后台切换

```swift
// 启动
Logger.lifecycle.info("App launched in \(launchTime)ms")

// 前后台
Logger.lifecycle.notice("Entering background")
Logger.lifecycle.notice("Entering foreground")

// 终止
Logger.lifecycle.info("App will terminate")
```

#### 9. Error（错误）

**用途**: 集中错误日志

```swift
// 一般错误
Logger.error.error("Failed to decode audio: \(error)")

// 严重错误
Logger.error.fault("Database corruption detected!")
Logger.error.fault("Critical component initialization failed!")
```

## 隐私保护 / Privacy Protection

### 自动脱敏 / Automatic Redaction

OSLog 默认对字符串参数进行脱敏，使用 `privacy` 参数控制：

```swift
// 私有数据（默认，显示为 <private>）
Logger.storage.info("User ID: \(userID)")  // "User ID: <private>"

// 显式私有
Logger.network.info("URL: \(url, privacy: .private)")

// 公开数据
Logger.asr.info("Model: \(modelName, privacy: .public)")

// 敏感数据（更强保护，显示为 <mask.hash>）
Logger.error.error("Password: \(password, privacy: .sensitive)")
```

### 最佳实践 / Best Practices

**✅ 应该公开**:
- 应用版本号
- 模型名称（非自定义）
- 通用错误码
- 文件扩展名

**❌ 必须私有**:
- 用户 ID
- 文件完整路径
- 字幕内容
- 媒体文件名（可能含敏感信息）

## 性能优化 / Performance Optimization

### 条件日志 / Conditional Logging

```swift
// Debug 日志仅在 Debug 构建中启用
#if DEBUG
Logger.player.debug("Detailed playback state: \(state)")
#endif

// 使用条件避免不必要的计算
if Logger.performance.logLevel <= .debug {
    let expensiveMetrics = calculateMetrics()
    Logger.performance.debug("Metrics: \(expensiveMetrics)")
}
```

### 字符串插值优化 / String Interpolation Optimization

```swift
// ❌ 避免：总是计算
Logger.asr.debug("Model details: \(expensiveModelDescription())")

// ✅ 推荐：惰性计算
Logger.asr.debug("Model details: \(expensiveModelDescription(), privacy: .public)")
```

## 查看日志 / Viewing Logs

### Console.app（macOS）

1. 打开 Console.app
2. 选择设备（iPhone/Mac）
3. 过滤 `subsystem:com.prismplayer.app`
4. 按分类过滤：`category:Player`

### Instruments

1. 打开 Instruments > Logging
2. 选择 Prism Player 进程
3. 按时间轴查看日志
4. 导出日志用于分析

### 命令行（开发调试）

```bash
# 实时查看日志
log stream --predicate 'subsystem == "com.prismplayer.app"' --level debug

# 按分类过滤
log stream --predicate 'subsystem == "com.prismplayer.app" && category == "Player"'

# 导出历史日志
log show --predicate 'subsystem == "com.prismplayer.app"' --last 1h > prism.log
```

## 常见模式 / Common Patterns

### 耗时操作日志 / Timing Operations

```swift
let startTime = Date()
// ... 执行操作
let duration = Date().timeIntervalSince(startTime) * 1000
Logger.performance.notice("Operation completed in \(duration, format: .fixed(precision: 1))ms")
```

### 错误处理日志 / Error Handling

```swift
do {
    try performOperation()
    Logger.asr.info("Operation succeeded")
} catch {
    Logger.error.error("Operation failed: \(error.localizedDescription)")
    // 恢复逻辑
}
```

### 状态机转换 / State Machine Transitions

```swift
Logger.player.notice("State transition: \(oldState) → \(newState)")
```

## 注意事项 / Notes

### ⚠️ 避免的做法

1. **过度日志**: 不要在循环中大量打印
2. **敏感信息**: 不要记录密码、密钥
3. **阻塞操作**: 日志本身很快，但避免在日志中调用耗时函数
4. **硬编码字符串**: 使用本地化字符串（如适用）

### ✅ 推荐的做法

1. **描述性消息**: 包含足够上下文
2. **使用 emoji**: 播放器用 ▶️⏸️⏹️，便于快速识别
3. **统一格式**: 同类操作使用相同格式
4. **关键路径**: 重要流程必须有日志

## 示例：完整流程 / Example: Complete Flow

```swift
// 用户选择媒体文件
Logger.ui.info("User selected media: \(filename, privacy: .public)")

// 开始播放
Logger.player.info("▶️ Playback started")
Logger.lifecycle.notice("Entering active state")

// 加载 ASR 模型
let modelStart = Date()
Logger.asr.notice("Loading model: whisper-base")
// ... 加载逻辑
Logger.asr.info("Model loaded in \(Date().timeIntervalSince(modelStart) * 1000)ms")

// 首次推理
Logger.performance.notice("First segment inference started")
let inferenceStart = Date()
// ... 推理逻辑
let duration = Date().timeIntervalSince(inferenceStart)
Logger.performance.notice("First frame time: \(duration * 1000, format: .fixed(precision: 1))ms")

// 渲染字幕
Logger.subtitle.info("Rendered first subtitle")

// 错误处理
if let error = error {
    Logger.error.error("Playback error: \(error)")
}
```

## 参考资料 / References

- [OSLog Documentation](https://developer.apple.com/documentation/oslog)
- [Generating Log Messages](https://developer.apple.com/documentation/os/logging/generating_log_messages_from_your_code)
- [WWDC21: Explore logging in Swift](https://developer.apple.com/videos/play/wwdc2020/10168/)

---

**维护者**: Prism Player Team  
**最后更新**: 2025-10-24
