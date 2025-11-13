# Task-103 PR3 详细设计：WhisperCppBackend 实现与 transcribe() 方法

- **Sprint**: S1
- **Task**: Task-103 PR3 - WhisperCppBackend 实现与 transcribe() 方法
- **PBI**: Sprint 1 核心功能 - ASR 引擎集成
- **Owner**: @jiang
- **状态**: Todo
- **创建日期**: 2025-11-13
- **预估**: 1.5 天（12 小时）

---

## 相关 TDD

- [HLD §6.1 统一接口](../../../1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md#61-统一接口设计)
  - **关键约束**: AsrEngine 协议，统一 Swift 接口，支持取消与进度回调
- [HLD §6.2 whisper.cpp 集成](../../../1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md#62-whispercpp-集成方案)
  - **关键约束**: GGUF 模型格式，Metal/Accelerate 加速，Actor 线程安全

## 相关 ADR

- [ADR-0007 Whisper.cpp 集成策略](../../../1_design/architecture/adr/iOS-macOS/0007-whisper-cpp-integration.md)
  - **影响**: 使用官方 XCFramework，基于 WhisperContext Actor 封装

---

## 1. 目标与范围

### 1.1 目标（可量化）

1. **实现 WhisperCppBackend**：完成 `transcribe()` 方法，调用 whisper.cpp C API 进行音频转写
2. **支持基础配置**：语言选择（en/zh/auto）、温度参数、时间戳启用
3. **取消机制**：支持通过 Task.checkCancellation() 取消转写任务
4. **错误处理**：覆盖 5 种错误场景（模型未加载、音频格式错误、转写失败、取消、内部错误）
5. **测试覆盖率**：
   - 单元测试覆盖率 ≥ 80%
   - 集成测试通过（使用 Mock 音频数据）
   - 准备金样本测试框架（PR4 执行）

### 1.2 范围 / 非目标

#### ✅ 范围内

- 实现 `WhisperCppBackend.transcribe()` 方法
- 调用 whisper.cpp C API (`whisper_full`, `whisper_full_get_segment_*`)
- 配置 `whisper_full_params` 结构体（语言、温度、时间戳）
- 解析 whisper.cpp 输出并转换为 `PrismCore.AsrSegment` 数组
- 实现 `cancelAll()` 方法（设置取消标志）
- 音频格式验证（16kHz mono PCM Float32）
- 基础日志埋点（OSLog）
- 单元测试与集成测试

#### ❌ 非目标（后续迭代）

- 金样本回归测试（PR4 完成）
- 进度回调（Sprint 2）
- 流式识别（Sprint 2+）
- VAD 集成（Sprint 2+）
- 模型下载/管理（ModelManager，Sprint 2）
- Metal/Accelerate 性能调优（使用默认配置）
- 说话人分离
- 多轨字幕

---

## 2. 方案要点（引用为主）

### 2.1 采用的接口/约束/契约

#### 来自 HLD §6.1 统一接口

```swift
public protocol AsrEngine: Sendable {
    func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment]
    
    func cancelAll() async
}
```

#### 来自 PR2 WhisperContext Actor

```swift
public actor WhisperContext {
    func loadModel(at modelPath: URL) async throws
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment]
    func cancel() async
    func unloadModel() async
}
```

### 2.2 与 TDD 差异的本地实现细节

#### 差异 1: AsrSegment 类型统一

- **HLD 原设计**: 未明确指定 AsrSegment 的位置
- **实际实现**: 
  - PR2 临时在 `PrismASR/Backends/WhisperContext.swift` 定义了 `PrismASR.AsrSegment`
  - 实际应使用 `PrismCore.AsrSegment`（数据库模型）
- **原因**: 避免类型重复，统一数据模型
- **影响**: 需要删除 PR2 临时定义，所有引用改为 `PrismCore.AsrSegment`
- **后续**: PR3 完成统一，PR2 代码需更新 ✅

#### 差异 2: 取消机制实现

- **HLD 原设计**: 未详细说明取消实现
- **实际实现**: 使用 Actor 的 `isCancelled` 属性 + Task.checkCancellation()
- **原因**: Swift Concurrency 原生支持，Actor 线程安全
- **影响**: 无
- **后续**: 无需更新 HLD ❌

---

## 3. 改动清单

### 3.1 影响模块/文件

#### 修改文件

1. **`PrismASR/Sources/PrismASR/Backends/WhisperCppBackend.swift`**
   - 实现 `transcribe()` 方法
   - 实现 `cancelAll()` 方法
   - 添加模型管理逻辑
   - 添加日志埋点

2. **`PrismASR/Sources/PrismASR/Backends/WhisperContext.swift`**
   - 实现 `transcribe()` 方法（调用 whisper.cpp C API）
   - 删除临时 `AsrSegment` 定义
   - 添加取消机制
   - 升级 `whisper_init_from_file` 到 `whisper_init_from_file_with_params`

3. **`PrismASR/Tests/PrismASRTests/WhisperCppBackendTests.swift`** （新建）
   - 单元测试覆盖所有场景
   - Mock 音频数据测试

4. **`PrismASR/Tests/PrismASRTests/WhisperContextTests.swift`**
   - 启用 `testBasicTranscription` 测试
   - 添加更多边界测试

### 3.2 接口/协议变更

**无新增协议变更**，仅实现已定义的 `AsrEngine` 协议。

### 3.3 数据/迁移

**无数据迁移需求**，PR3 不涉及持久化存储。

---

## 4. 实施计划

### 4.1 PR 拆分与步骤

**单个 PR**，预计 1.5 天完成：

#### 第 1 步：类型统一与准备工作（2 小时）

- [ ] 删除 `WhisperContext.swift` 中的临时 `AsrSegment` 定义
- [ ] 更新所有引用为 `PrismCore.AsrSegment`
- [ ] 升级 C API 调用：`whisper_init_from_file` → `whisper_init_from_file_with_params`
- [ ] 编译验证

#### 第 2 步：实现 WhisperContext.transcribe()（5 小时）

- [ ] 实现音频数据转换（`Data` → `[Float]`）
- [ ] 实现 `whisper_full_params` 配置
  - [ ] 语言设置（en/zh/auto）
  - [ ] 温度参数
  - [ ] 时间戳启用
  - [ ] 线程数配置（Metal/CPU）
- [ ] 调用 `whisper_full()` C API
- [ ] 解析结果：
  - [ ] 获取片段数量 `whisper_full_n_segments()`
  - [ ] 遍历片段并提取：
    - [ ] 文本 `whisper_full_get_segment_text()`
    - [ ] 开始时间 `whisper_full_get_segment_t0()`
    - [ ] 结束时间 `whisper_full_get_segment_t1()`
  - [ ] 转换为 `AsrSegment` 数组
- [ ] 实现取消检查（每 N 个片段检查一次）
- [ ] 错误处理与日志埋点

#### 第 3 步：实现 WhisperCppBackend（2 小时）

- [ ] 实现 `transcribe()` 方法（委托给 WhisperContext）
- [ ] 实现 `cancelAll()` 方法
- [ ] 模型加载逻辑（初次调用时自动加载）
- [ ] 日志埋点

#### 第 4 步：单元测试（3 小时）

- [ ] `WhisperContextTests.swift`:
  - [ ] `testTranscribeWithMockAudio` - 基础转写流程
  - [ ] `testTranscribeWithCancellation` - 取消机制
  - [ ] `testTranscribeWithInvalidAudio` - 音频格式错误
  - [ ] `testTranscribeWithoutModel` - 模型未加载错误
- [ ] `WhisperCppBackendTests.swift` (新建):
  - [ ] `testTranscribeSuccess` - 完整转写流程
  - [ ] `testTranscribeWithLanguageOption` - 语言选择
  - [ ] `testTranscribeWithTemperature` - 温度参数
  - [ ] `testCancelAll` - 取消所有任务
  - [ ] `testAutoModelLoading` - 自动模型加载

#### 第 5 步：集成测试与文档（2 小时）

- [ ] 创建 Mock 音频数据（Tests/Fixtures/audio/mock-1s.wav）
- [ ] 集成测试：端到端流程
- [ ] 更新 README 文档
- [ ] 更新 CHANGELOG
- [ ] Code Review 自查

### 4.2 特性开关/灰度

**无需特性开关**，PR3 是内部实现，外部接口在 PR1 已定义。

---

## 5. 测试与验收

### 5.1 单元测试

#### 测试用例

| 测试类 | 测试方法 | 场景 | 断言 |
|--------|----------|------|------|
| `WhisperContextTests` | `testTranscribeWithMockAudio` | 正常转写 | 返回 ≥ 1 个 Segment |
| `WhisperContextTests` | `testTranscribeWithCancellation` | 任务取消 | 抛出 `AsrError.cancelled` |
| `WhisperContextTests` | `testTranscribeWithInvalidAudio` | 无效音频 | 抛出 `AsrError.invalidAudioFormat` |
| `WhisperContextTests` | `testTranscribeWithoutModel` | 模型未加载 | 抛出 `AsrError.modelNotLoaded` |
| `WhisperCppBackendTests` | `testTranscribeSuccess` | 完整流程 | 返回有效 Segment 数组 |
| `WhisperCppBackendTests` | `testTranscribeWithLanguageOption` | 语言选择（en/zh） | Segment 文本语言正确 |
| `WhisperCppBackendTests` | `testTranscribeWithTemperature` | 温度参数（0.0/0.5） | 不抛出异常 |
| `WhisperCppBackendTests` | `testCancelAll` | 取消任务 | 抛出 `AsrError.cancelled` |
| `WhisperCppBackendTests` | `testAutoModelLoading` | 自动加载模型 | 首次转写自动加载 |

#### 测试夹具

- **Mock 音频数据**（PR3 创建）:
  - `Tests/Fixtures/audio/mock-1s-silence.data` - 1秒静音（16kHz Float32）
  - 使用代码生成，无需真实文件

- **真实模型文件**（PR4 准备）:
  - `Tests/Fixtures/models/ggml-tiny.bin` - Whisper Tiny 模型（~75MB）
  - PR4 下载并添加到 Git LFS

#### 覆盖率目标

- **核心逻辑**: ≥ 80%（WhisperContext.transcribe, WhisperCppBackend.transcribe）
- **错误处理**: 100%（所有 AsrError 分支）
- **边界条件**: ≥ 70%（空数据、取消、超时）

### 5.2 集成/E2E 测试

#### 场景 1: 端到端转写流程

```swift
func testEndToEndTranscription() async throws {
    // Given: 准备后端和音频数据
    let backend = WhisperCppBackend()
    let audioData = generateMockAudio(duration: 1.0) // 1秒静音
    let options = AsrOptions(language: .english, temperature: 0.0)
    
    // When: 执行转写
    let segments = try await backend.transcribe(audioData: audioData, options: options)
    
    // Then: 验证结果
    XCTAssertGreaterThanOrEqual(segments.count, 0) // 静音可能返回空
    for segment in segments {
        XCTAssertGreaterThanOrEqual(segment.endTime, segment.startTime)
        XCTAssertFalse(segment.text.isEmpty)
    }
}
```

#### 场景 2: 取消机制验证

```swift
func testCancellationDuringTranscription() async throws {
    // Given: 准备后端和长音频
    let backend = WhisperCppBackend()
    let audioData = generateMockAudio(duration: 10.0) // 10秒音频
    let options = AsrOptions()
    
    // When: 启动转写并立即取消
    let task = Task {
        try await backend.transcribe(audioData: audioData, options: options)
    }
    
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    await backend.cancelAll()
    task.cancel()
    
    // Then: 应抛出取消错误
    do {
        _ = try await task.value
        XCTFail("应该抛出取消错误")
    } catch AsrError.cancelled {
        // 预期行为
    }
}
```

### 5.3 验收标准

- [x] 所有单元测试通过（覆盖率 ≥ 80%）
- [x] 集成测试通过（2 个场景）
- [x] 性能要求：
  - [ ] Mock 音频转写延迟 < 1s（无实际推理）
  - [ ] 内存占用 < 100MB（不含模型加载）
- [x] 错误处理完整（5 种 AsrError 覆盖）
- [x] 日志埋点完整（关键路径 + 错误场景）

---

## 6. 观测与验证

### 6.1 日志埋点

| 埋点位置 | 日志级别 | 字段 | 频率 |
|----------|----------|------|------|
| `transcribe()` 开始 | `.info` | audioSize, language, temperature | 每次调用 |
| `transcribe()` 成功 | `.info` | segmentCount, duration, rtf | 每次调用 |
| `transcribe()` 失败 | `.error` | error, audioSize | 每次错误 |
| `transcribe()` 取消 | `.warning` | duration | 每次取消 |
| C API 调用失败 | `.error` | apiName, returnCode | 每次失败 |
| 片段解析 | `.debug` | segmentIndex, text, startTime, endTime | 每个片段 |

### 6.2 指标埋点

**PR3 不包含指标系统**，仅记录日志。Task-107（指标与诊断）将实现：

- RTF（Real-Time Factor）计算
- 首帧时间
- 段识别耗时分布

### 6.3 验证方法

#### 本地验证

```bash
# 1. 编译
cd Prism-xOS/packages/PrismASR
swift build -c debug

# 2. 运行测试
swift test --filter WhisperCppBackendTests
swift test --filter WhisperContextTests

# 3. 查看日志
log show --predicate 'subsystem == "com.prismplayer.asr"' --last 5m
```

#### CI 验证

- GitHub Actions 自动运行所有测试
- 覆盖率报告上传到 Codecov（Task-108）

#### 真机验证（可选）

- 使用 PrismPlayer App 加载测试音频
- 查看 Console.app 日志

---

## 7. 风险与未决

### 7.1 风险

#### 风险 A: whisper.cpp C API 兼容性

- **描述**: whisper.cpp 版本更新可能导致 API 破坏性变化
- **概率**: 低（PR2 已锁定版本）
- **影响**: 高（编译失败）
- **缓解措施**:
  1. PR2 使用官方 XCFramework，锁定版本
  2. 更新前检查 whisper.cpp CHANGELOG
  3. 保留旧版本 XCFramework 作为回退
- **负责人**: @jiang
- **截止日期**: N/A（预防性措施）

#### 风险 B: Mock 音频无法触发转写逻辑

- **描述**: 1秒静音可能导致 whisper.cpp 返回空结果，无法验证解析逻辑
- **概率**: 中（whisper.cpp 对静音敏感）
- **影响**: 中（测试覆盖不足）
- **缓解措施**:
  1. 生成含正弦波的 Mock 音频（模拟语音频率）
  2. 使用更长的 Mock 音频（3-5秒）
  3. PR4 使用真实音频金样本
- **负责人**: @jiang
- **截止日期**: PR3 实施期间

#### 风险 C: Actor 并发性能问题

- **描述**: WhisperContext Actor 可能成为瓶颈（串行执行）
- **概率**: 低（当前单任务场景）
- **影响**: 中（并发转写性能）
- **缓解措施**:
  1. Sprint 1 仅单任务，无性能问题
  2. Sprint 2 引入任务队列优化
  3. 长期方案：使用多个 WhisperContext 实例池
- **负责人**: @架构
- **截止日期**: Sprint 2（如需要）

### 7.2 未决问题

| 问题 | 状态 | 负责人 | 预期解决 |
|------|------|--------|----------|
| 是否需要进度回调？ | 🟡 讨论中 | @产品 | Sprint 1 Review |
| Mock 音频生成策略（静音 vs 正弦波） | 🟢 已决策：正弦波 | @jiang | PR3 实施 |
| 是否需要 C API 错误码映射表？ | 🔴 待讨论 | @架构 | PR3 Code Review |

---

## 8. 定义完成（DoD）

### 8.1 代码质量

- [ ] CI 通过（构建/测试/SwiftLint 严格模式）
- [ ] 无编译警告（除已知的 whisper.cpp 弃用警告）
- [ ] 无硬编码字符串（所有文本使用 NSLocalizedString）
- [ ] 代码覆盖率 ≥ 80%（核心逻辑）
- [ ] 所有 TODO/FIXME 已处理或转为 Issue

### 8.2 测试

- [ ] 所有单元测试通过（9 个测试用例）
- [ ] 集成测试通过（2 个场景）
- [ ] Mock 数据生成函数完成
- [ ] 测试夹具准备完成（PR4 真实模型）

### 8.3 文档

- [ ] **README 更新**:
  - [ ] PrismASR/README.md - 新增使用示例
  - [ ] 新增 API 文档链接
- [ ] **CHANGELOG 更新**:
  - [ ] 记录 PR3 变更（实现 transcribe 方法）
  - [ ] 记录 API 升级（whisper_init_from_file_with_params）
- [ ] **HLD 同步**:
  - [ ] 确认无设计偏差（PR3 无需更新 HLD）
- [ ] **代码注释**:
  - [ ] 所有 public API 有完整文档注释
  - [ ] 复杂算法有中文说明

### 8.4 Code Review

- [ ] 至少 1 位 reviewer 批准
- [ ] 所有 review comments 已解决
- [ ] 无遗留的 "Request Changes"

### 8.5 性能与日志

- [ ] 关键路径日志埋点到位（6 个埋点）
- [ ] 性能基线记录（Mock 音频延迟 < 1s）
- [ ] 无内存泄漏（Instruments Leaks 检查）

---

## 9. 实施检查清单

### Phase 1: 准备（2 小时）

- [ ] 删除临时 `AsrSegment` 定义
- [ ] 更新所有类型引用为 `PrismCore.AsrSegment`
- [ ] 升级 C API 到 `whisper_init_from_file_with_params`
- [ ] 编译验证通过

### Phase 2: WhisperContext 实现（5 小时）

- [ ] 音频数据转换（Data → [Float]）
- [ ] whisper_full_params 配置（语言/温度/时间戳）
- [ ] whisper_full() C API 调用
- [ ] 结果解析（text/t0/t1）
- [ ] 取消检查机制
- [ ] 错误处理与日志

### Phase 3: WhisperCppBackend 实现（2 小时）

- [ ] transcribe() 方法实现
- [ ] cancelAll() 方法实现
- [ ] 自动模型加载逻辑
- [ ] 日志埋点

### Phase 4: 测试（3 小时）

- [ ] WhisperContextTests - 4 个测试用例
- [ ] WhisperCppBackendTests - 5 个测试用例
- [ ] 集成测试 - 2 个场景
- [ ] Mock 数据生成函数

### Phase 5: 文档与 Review（2 小时）

- [ ] README 更新
- [ ] CHANGELOG 更新
- [ ] Code Review 自查
- [ ] 提交 PR

---

## 10. 参考资料

### 10.1 whisper.cpp C API

- **官方文档**: [whisper.h](https://github.com/ggerganov/whisper.cpp/blob/master/include/whisper.h)
- **关键函数**:
  - `whisper_init_from_file_with_params()` - 加载模型
  - `whisper_full_default_params()` - 获取默认参数
  - `whisper_full()` - 执行转写
  - `whisper_full_n_segments()` - 获取片段数量
  - `whisper_full_get_segment_text()` - 获取片段文本
  - `whisper_full_get_segment_t0()` - 获取开始时间
  - `whisper_full_get_segment_t1()` - 获取结束时间
  - `whisper_free()` - 释放资源

### 10.2 示例代码（C API 使用）

```swift
// 1. 初始化参数
var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
params.language = "en".cString(using: .utf8)
params.temperature = 0.0
params.n_threads = 4
params.print_realtime = false
params.print_progress = false

// 2. 准备音频数据
let samples: [Float] = AudioConverter.dataToFloatArray(audioData)

// 3. 执行转写
let result = samples.withUnsafeBufferPointer { buffer in
    whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
}

guard result == 0 else {
    throw AsrError.transcriptionFailed("whisper_full returned \(result)")
}

// 4. 解析结果
let nSegments = whisper_full_n_segments(context)
var segments: [AsrSegment] = []

for i in 0..<nSegments {
    let text = String(cString: whisper_full_get_segment_text(context, i))
    let t0 = whisper_full_get_segment_t0(context, i) // 百分之一秒
    let t1 = whisper_full_get_segment_t1(context, i)
    
    let segment = AsrSegment(
        mediaId: "mock",
        startTime: Double(t0) / 100.0,
        endTime: Double(t1) / 100.0,
        text: text
    )
    segments.append(segment)
}
```

### 10.3 相关文档

- [Task-103 总体设计](./task-103-asr-engine-protocol-whisper-backend.md)
- [Task-103 PR2 完成报告](./task-103-pr2-completion.md)
- [ADR-0007 Whisper.cpp 集成策略](../../../1_design/architecture/adr/iOS-macOS/0007-whisper-cpp-integration.md)
- [HLD §6 ASR 引擎集成](../../../1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md#6-asr-引擎集成whisper.cpp-优先)

---

**文档版本**: v1.0  
**最后更新**: 2025-11-13  
**变更记录**:
- v1.0 (2025-11-13): 初始版本，基于 PR2 完成状态

---

## 附录 A: whisper_full_params 关键字段

| 字段名 | 类型 | 说明 | 默认值 | PR3 使用 |
|--------|------|------|--------|---------|
| `language` | `const char*` | 语言代码（"en"/"zh"/NULL=auto） | NULL | ✅ 根据 AsrOptions |
| `temperature` | `float` | 采样温度（0.0-1.0） | 0.0 | ✅ 根据 AsrOptions |
| `n_threads` | `int` | 线程数 | 4 | ✅ 使用系统核心数 |
| `max_len` | `int` | 最大片段长度（token） | 0（无限制） | ❌ 使用默认 |
| `token_timestamps` | `bool` | 启用 token 级时间戳 | false | ❌ 使用默认 |
| `print_realtime` | `bool` | 实时打印到 stdout | false | ✅ 设为 false |
| `print_progress` | `bool` | 打印进度到 stderr | false | ✅ 设为 false |
| `no_timestamps` | `bool` | 禁用时间戳 | false | ✅ 根据 enableTimestamps 反转 |

---

## 附录 B: Mock 音频生成代码

```swift
/// 生成 Mock 音频数据（正弦波）
///
/// - Parameters:
///   - duration: 音频时长（秒）
///   - frequency: 正弦波频率（Hz），默认 440Hz（A4 音符）
///   - sampleRate: 采样率，默认 16000Hz
/// - Returns: PCM Float32 Data（16kHz mono）
func generateMockAudio(
    duration: TimeInterval,
    frequency: Double = 440.0,
    sampleRate: Int = 16000
) -> Data {
    let sampleCount = Int(duration * Double(sampleRate))
    var samples: [Float] = []
    
    for i in 0..<sampleCount {
        let t = Double(i) / Double(sampleRate)
        let sample = sin(2.0 * .pi * frequency * t)
        samples.append(Float(sample * 0.5)) // 振幅 0.5
    }
    
    return AudioConverter.floatArrayToData(samples)
}
```

---

**🎯 PR3 目标**: 让 WhisperCppBackend 真正"说话" - 完成从音频到文本的完整转写流程！
