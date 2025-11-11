# ADR-0004: 日志与性能指标方案

## 状态
**接受（Accepted）**

- 提出日期: 2025-10-24
- 决策日期: 2025-10-24
- 实施状态: Sprint 0 - Task-007

## 上下文

Prism Player 需要建立完善的可观测性体系，以支持：

1. **开发调试**: 快速定位问题，理解应用运行状态
2. **性能监控**: 跟踪关键性能指标（首帧时间、RTF、内存等）
3. **问题诊断**: 收集用户反馈时的上下文信息
4. **质量保障**: 验证性能目标是否达标（P95 阈值）

### 关键需求

根据 PRD v0.2 和 Sprint Plan v0.2，需要监控的关键指标包括：

**性能指标（KPI）**:
- 首帧字幕可见时间（P95）
- RTF（Real-Time Factor）: 推理耗时 / 音频时长
- 时间同步偏差: |字幕时间 - 播放器时间| ≤ 200ms（P95）
- 导出成功率 ≥ 99%

**资源指标**:
- 内存使用（峰值/平均/趋势）
- 音频缓存大小（≤10MB 目标）
- 模型文件大小
- 电量消耗（后台识别场景）

**质量指标**:
- ASR 置信度分布
- 段识别成功/失败率
- 用户操作流程完成率

### 技术约束

1. **平台原生**: 优先使用 Apple 原生框架，减少第三方依赖
2. **隐私优先**: 不上传用户数据，本地处理为主
3. **性能开销**: 日志和指标采集不能显著影响应用性能
4. **离线可用**: 无网络时也能正常记录和查询
5. **跨平台**: iOS 17+ 和 macOS 14+ 统一方案

## 决策

采用 **Apple OSLog + 本地指标存储** 的混合方案：

### 1. 日志框架：OSLog（统一日志系统）

**选择理由**:
- ✅ Apple 原生，与系统深度集成
- ✅ 高性能，异步写入，低开销
- ✅ 支持日志级别过滤（debug/info/notice/error/fault）
- ✅ Console.app 和 Instruments 原生支持
- ✅ 隐私保护机制（自动脱敏）
- ✅ 支持结构化日志和元数据

**日志分类体系**:

```swift
// 子系统标识
private let subsystem = "com.prismplayer.app"

// 核心业务分类
- Player        // 播放器相关
- ASR           // 语音识别
- Subtitle      // 字幕渲染与同步
- Storage       // 数据存储
- Network       // 网络操作
- UI            // 用户交互

// 系统级分类
- Performance   // 性能指标
- Lifecycle     // 应用生命周期
- Error         // 错误和异常
```

**使用规范**:

| 级别 | 使用场景 | 示例 |
|-----|---------|------|
| **debug** | 详细调试信息（仅 Debug 构建） | "Audio chunk extracted: 512KB" |
| **info** | 关键流程节点 | "Playback started: video.mp4" |
| **notice** | 重要状态变化 | "Model loaded: whisper-base (74MB)" |
| **error** | 可恢复错误 | "Failed to load subtitle, retrying..." |
| **fault** | 严重错误（不应发生） | "Database corruption detected" |

### 2. 性能指标：本地采集 + MetricKit 集成

**架构设计**:

```
┌─────────────────────────────────────────────┐
│         Application Code                    │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│      MetricsCollector Protocol              │
│  - recordTiming()                           │
│  - recordCount()                            │
│  - recordDistribution()                     │
└────────┬────────────────────────────────────┘
         │
    ┌────┴─────┐
    │          │
    ▼          ▼
┌────────┐  ┌──────────────┐
│ Local  │  │  MetricKit   │
│Storage │  │  (System)    │
└────────┘  └──────────────┘
```

**LocalMetricsCollector 实现**:

```swift
actor LocalMetricsCollector: MetricsCollector {
    // 存储策略
    private var timingMetrics: [String: [TimingMetric]] = [:]
    private var countMetrics: [String: Int] = [:]
    private var distributionMetrics: [String: [Double]] = [:]
    
    // 持久化：定期写入 UserDefaults/SQLite
    // 查询：支持按时间范围、分类过滤
    // 清理：保留最近 7 天数据
}
```

**MetricKit 集成**:
- 系统级性能数据（CPU、内存、电量）
- 应用启动时间、挂起次数
- 崩溃和诊断报告
- 仅作为补充数据源

### 3. 诊断包：结构化导出

**DiagnosticReport 结构**:

```swift
struct DiagnosticReport: Codable {
    // 元信息
    let timestamp: Date
    let reportID: UUID
    let appVersion: String
    let buildNumber: String
    
    // 设备信息
    let deviceInfo: DeviceInfo
    struct DeviceInfo: Codable {
        let model: String           // "iPhone15,2"
        let osVersion: String       // "iOS 17.0"
        let chipType: String        // "Apple A16"
        let totalMemory: UInt64
        let diskSpace: UInt64
    }
    
    // 日志片段（最近 100 条）
    let logs: [LogEntry]
    struct LogEntry: Codable {
        let timestamp: Date
        let category: String
        let level: String
        let message: String  // 已脱敏
    }
    
    // 指标摘要
    let metrics: MetricsSummary
    struct MetricsSummary: Codable {
        let firstFrameP95: TimeInterval?
        let rtfDistribution: [Double]
        let timeOffsetP95: TimeInterval?
        let memoryPeak: UInt64
        let failedSegments: Int
    }
    
    // 配置快照
    let configuration: ConfigSnapshot
    struct ConfigSnapshot: Codable {
        let selectedModel: String
        let preloadDuration: TimeInterval
        let cacheSize: UInt64
        // 不含敏感信息
    }
}
```

**导出格式**:
- JSON 文件（便于解析）
- 压缩为 ZIP（减少体积）
- 命名规范: `prism_diagnostics_<timestamp>.zip`

**隐私保护**:
- ✅ 不包含媒体文件内容
- ✅ 不包含字幕文本（或仅前 10 字脱敏）
- ✅ 文件路径仅保留文件名
- ✅ 用户明确同意后才导出

## 替代方案

### 方案 A: swift-log + 第三方分析平台

**描述**: 使用 Apple 的 [swift-log](https://github.com/apple/swift-log) 抽象层，集成 Firebase Analytics / Sentry。

**优点**:
- ✅ 跨平台统一 API
- ✅ 第三方平台提供可视化仪表盘
- ✅ 支持远程错误追踪和报警

**缺点**:
- ❌ 引入额外依赖（增加包体积）
- ❌ 需要网络连接，离线场景受限
- ❌ 隐私合规复杂（需明确同意上传）
- ❌ 免费额度有限（大规模使用成本高）

**评估**: 不适合离线优先的 Prism Player；可作为可选功能在 Sprint 2+ 评估。

---

### 方案 B: CocoaLumberjack + SQLite

**描述**: 使用第三方日志库 [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack)，指标存储到 SQLite。

**优点**:
- ✅ 功能丰富（文件日志、滚动、压缩）
- ✅ 社区成熟，文档完善
- ✅ 完全离线可用

**缺点**:
- ❌ 第三方依赖，增加维护负担
- ❌ 与 Apple 生态集成不如 OSLog
- ❌ 无法利用 Instruments 和 Console.app
- ❌ 性能不如 OSLog（需手动优化）

**评估**: CocoaLumberjack 功能强大，但 OSLog 已满足需求，且原生集成更优。

---

### 方案 C: 纯文件日志 + CSV 指标

**描述**: 日志写入文本文件，指标保存为 CSV 格式。

**优点**:
- ✅ 实现简单，无依赖
- ✅ 人类可读，易于调试
- ✅ 完全可控

**缺点**:
- ❌ 性能差（文件 I/O 阻塞）
- ❌ 无结构化查询能力
- ❌ 日志文件管理复杂（滚动、清理）
- ❌ 隐私保护需自行实现

**评估**: 过于原始，不适合生产应用。

---

### 方案 D: MetricKit 唯一方案

**描述**: 仅依赖 Apple MetricKit 收集系统级指标。

**优点**:
- ✅ 完全原生，零依赖
- ✅ 系统优化，低开销
- ✅ 自动聚合和上传到 App Store Connect

**缺点**:
- ❌ 仅支持系统级指标（CPU、内存、崩溃）
- ❌ 无法记录业务指标（首帧时间、RTF、时间偏差）
- ❌ 数据延迟（24 小时聚合）
- ❌ 无实时查询能力

**评估**: MetricKit 作为补充数据源，无法满足业务监控需求。

## 后果

### 正面影响

1. **开发效率提升**
   - 统一的日志 API，减少学习成本
   - Console.app 和 Instruments 原生支持，调试便捷
   - 结构化日志便于问题定位

2. **性能监控完善**
   - 覆盖所有 KPI 指标（首帧、RTF、时间偏差）
   - 本地查询实时可用，无网络依赖
   - 支持 P50/P95 分布统计

3. **问题诊断能力**
   - 诊断包包含完整上下文
   - 隐私保护到位，用户信任度高
   - 支持离线问题反馈

4. **隐私合规**
   - 默认本地存储，无数据上传
   - OSLog 自动脱敏机制
   - 用户明确同意后才导出诊断包

### 负面影响

1. **功能限制**
   - 无远程仪表盘（需手动查看）
   - 无实时报警机制（依赖手动检查）
   - 多设备数据聚合需额外开发

2. **存储管理**
   - 需定期清理本地指标数据
   - 长时间运行可能积累大量日志
   - 需实现 LRU 或时间窗口清理策略

3. **可视化缺失**
   - 无图表展示，仅文本和 JSON
   - 需额外开发指标查看界面（可选）

### 风险与缓解

| 风险 | 影响 | 缓解措施 |
|-----|------|---------|
| 本地存储空间不足 | 中 | 定期清理策略（保留 7 天）；用户可手动清空 |
| 日志级别配置错误导致性能下降 | 中 | Release 构建自动禁用 debug 级别；性能测试验证 |
| 指标采集代码侵入业务逻辑 | 低 | Actor 封装异步化；协议抽象便于 Mock |
| 诊断包泄露隐私信息 | 高 | 代码审查 + 自动化测试；用户明确授权 |

## 实施计划

### Phase 1: Sprint 0（当前）

✅ 任务范围：
1. 定义 OSLog 分类和日志级别规范
2. 实现 `MetricsCollector` 协议和 `LocalMetricsCollector`
3. 创建 `DiagnosticReport` 数据结构
4. 编写使用文档和示例代码

📦 交付物：
- `PrismCore/Sources/PrismCore/Logging/`
- `PrismCore/Sources/PrismCore/Metrics/`
- `PrismCore/Sources/PrismCore/Diagnostics/`
- `docs/adr/0004-logging-metrics-strategy.md`

### Phase 2: Sprint 1

📋 计划任务：
1. 在播放器、ASR 引擎中集成日志
2. 记录首帧时间、RTF、时间偏差指标
3. 基础性能基线采集（3 档设备）

### Phase 3: Sprint 2

📋 计划任务：
1. 完善诊断包导出功能（UI 入口）
2. 集成 MetricKit 作为补充数据源
3. 实现指标查看界面（设置页面）
4. 可选：评估第三方分析平台集成

### Phase 4: Sprint 3

📋 计划任务：
1. 性能优化（日志压缩、异步写入）
2. 长时间运行稳定性测试
3. 错误诊断工作流完善
4. 问题反馈包脱敏验证

## 度量标准

### 性能开销

| 指标 | 目标 | 验证方法 |
|-----|------|---------|
| 日志写入延迟 | < 5ms (P95) | Time Profiler |
| 指标采集内存占用 | < 5MB | Instruments Allocations |
| 诊断包生成时间 | < 2s | 单元测试 |
| 存储空间占用 | < 50MB（7 天） | 集成测试 |

### 功能覆盖

- ✅ 所有核心业务模块有对应日志分类
- ✅ 所有 KPI 指标可采集和查询
- ✅ 诊断包包含足够问题定位信息
- ✅ 隐私保护措施验证通过

## 参考资料

### Apple 官方文档
- [OSLog and Unified Logging](https://developer.apple.com/documentation/oslog)
- [MetricKit Framework](https://developer.apple.com/documentation/metrickit)
- [Generating Log Messages from Your Code](https://developer.apple.com/documentation/os/logging/generating_log_messages_from_your_code)

### 最佳实践
- [WWDC19: Getting Started with Instruments](https://developer.apple.com/videos/play/wwdc2019/411/)
- [WWDC21: Diagnose Power and Performance Regressions](https://developer.apple.com/videos/play/wwdc2021/10087/)
- [Swift Logging API Proposal](https://github.com/apple/swift-evolution/blob/main/proposals/0263-swift-log-levels.md)

### 社区经验
- [NSHipster: Logging](https://nshipster.com/swift-log/)
- [Point-Free: Combine Schedulers](https://www.pointfree.co/collections/combine) - 异步日志处理
- [SwiftLee: OSLog Tutorial](https://www.avanderlee.com/debugging/oslog-unified-logging/)

---

**状态**: ✅ 已接受  
**作者**: Prism Player Team  
**审核者**: 待审核  
**最后更新**: 2025-10-24
