# Task-103 PR3 执行指南（快速参考）

**文档**: Task-103 PR3 - WhisperCppBackend 实现  
**详细设计**: [task-103-pr3-whisper-backend-implementation.md](./task-103-pr3-whisper-backend-implementation.md)  
**预计时间**: 1.5 天（12 小时）  
**日期**: 2025-11-13

---

## 🎯 核心目标

实现 `WhisperCppBackend.transcribe()` 方法，完成从音频数据到文本片段的完整转写流程。

---

## 📝 实施步骤（5 步）

### Step 1: 类型统一与准备（2h）

```bash
# 任务清单
□ 删除 WhisperContext.swift 中的临时 AsrSegment 定义（~line 180）
□ 更新所有引用为 PrismCore.AsrSegment
□ 升级 C API: whisper_init_from_file → whisper_init_from_file_with_params
□ 编译验证
```

**关键代码位置**:
- `PrismASR/Sources/PrismASR/Backends/WhisperContext.swift:180-196`
- `PrismASR/Tests/PrismASRTests/AsrEngineProtocolTests.swift:23`

---

### Step 2: WhisperContext.transcribe() 实现（5h）

```bash
# 任务清单
□ 音频数据转换（Data → [Float]）
□ 配置 whisper_full_params（语言/温度/时间戳）
□ 调用 whisper_full() C API
□ 解析结果（遍历 segments）
□ 实现取消检查（每 N 个片段）
□ 错误处理与日志埋点
```

**核心代码结构**:

```swift
public func transcribe(
    audioData: Data,
    options: AsrOptions
) async throws -> [AsrSegment] {
    guard isInitialized else {
        throw AsrError.modelNotLoaded
    }
    
    // 1. 音频转换
    let samples = AudioConverter.dataToFloatArray(audioData)
    
    // 2. 配置参数
    var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
    params.language = options.language?.code.cString(using: .utf8)
    params.temperature = options.temperature
    params.n_threads = ProcessInfo.processInfo.activeProcessorCount
    params.no_timestamps = !options.enableTimestamps
    params.print_realtime = false
    params.print_progress = false
    
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
        try Task.checkCancellation() // 取消检查
        
        let text = String(cString: whisper_full_get_segment_text(context, i))
        let t0 = whisper_full_get_segment_t0(context, i) // 百分之一秒
        let t1 = whisper_full_get_segment_t1(context, i)
        
        let segment = AsrSegment(
            mediaId: "unknown", // 由调用方设置
            startTime: Double(t0) / 100.0,
            endTime: Double(t1) / 100.0,
            text: text
        )
        segments.append(segment)
    }
    
    return segments
}
```

**日志埋点**（6 处）:
1. `.info` - transcribe 开始（audioSize, language）
2. `.info` - transcribe 成功（segmentCount, duration, rtf）
3. `.error` - transcribe 失败（error）
4. `.warning` - transcribe 取消
5. `.error` - C API 调用失败（returnCode）
6. `.debug` - 片段解析（每个片段）

---

### Step 3: WhisperCppBackend 实现（2h）

```bash
# 任务清单
□ 实现 transcribe() 方法（委托给 WhisperContext）
□ 实现 cancelAll() 方法
□ 自动模型加载逻辑（首次调用时）
□ 日志埋点
```

**核心代码结构**:

```swift
public final class WhisperCppBackend: AsrEngine {
    private let context: WhisperContext
    private var modelPath: URL?
    
    public init(modelPath: URL? = nil) {
        self.context = WhisperContext()
        self.modelPath = modelPath
    }
    
    public func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment] {
        // 自动加载模型（首次调用）
        if let path = options.modelPath ?? modelPath {
            try await context.loadModel(at: path)
        }
        
        // 委托给 WhisperContext
        return try await context.transcribe(audioData: audioData, options: options)
    }
    
    public func cancelAll() async {
        await context.cancel()
    }
}
```

---

### Step 4: 单元测试（3h）

```bash
# 测试清单（11 个测试）
□ WhisperContextTests (4 个)
  □ testTranscribeWithMockAudio
  □ testTranscribeWithCancellation
  □ testTranscribeWithInvalidAudio
  □ testTranscribeWithoutModel

□ WhisperCppBackendTests (5 个 - 新建文件)
  □ testTranscribeSuccess
  □ testTranscribeWithLanguageOption
  □ testTranscribeWithTemperature
  □ testCancelAll
  □ testAutoModelLoading

□ 集成测试 (2 个)
  □ testEndToEndTranscription
  □ testCancellationDuringTranscription
```

**Mock 音频生成函数**:

```swift
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
        samples.append(Float(sample * 0.5))
    }
    
    return AudioConverter.floatArrayToData(samples)
}
```

---

### Step 5: 文档与 Review（2h）

```bash
# 文档清单
□ PrismASR/README.md - 新增使用示例
□ CHANGELOG.md - 记录 PR3 变更
□ Code Review 自查
□ 提交 PR
```

---

## 🔑 关键 API 参考

### whisper.cpp C API

| 函数名 | 说明 | 返回值 |
|--------|------|--------|
| `whisper_init_from_file_with_params()` | 加载模型（新版） | `OpaquePointer?` |
| `whisper_full_default_params()` | 获取默认参数 | `whisper_full_params` |
| `whisper_full()` | 执行转写 | `Int32` (0=成功) |
| `whisper_full_n_segments()` | 获取片段数量 | `Int32` |
| `whisper_full_get_segment_text()` | 获取片段文本 | `const char*` |
| `whisper_full_get_segment_t0()` | 获取开始时间 | `Int64` (百分之一秒) |
| `whisper_full_get_segment_t1()` | 获取结束时间 | `Int64` (百分之一秒) |
| `whisper_free()` | 释放资源 | `void` |

### Swift API

```swift
// AsrEngine 协议
public protocol AsrEngine: Sendable {
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment]
    func cancelAll() async
}

// AsrOptions 配置
public struct AsrOptions: Sendable {
    public let language: AsrLanguage?      // en/zh/auto
    public let modelPath: URL?
    public let temperature: Float          // 0.0-1.0
    public let enableTimestamps: Bool
    public let prompt: String?
}

// AsrSegment 数据模型（PrismCore）
public struct AsrSegment: Identifiable, Codable, Sendable {
    public let id: UUID
    public var mediaId: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let confidence: Double?
}
```

---

## ⚠️ 注意事项

### 类型统一（重要！）

- **删除**: `PrismASR.AsrSegment`（临时定义，PR2 遗留）
- **使用**: `PrismCore.AsrSegment`（数据库模型）
- **影响文件**: 
  - `WhisperContext.swift`（删除定义）
  - `AsrEngineProtocolTests.swift`（更新引用）

### C API 升级

**旧版（PR2）**:
```swift
let ctx = whisper_init_from_file(cPath) // ⚠️ 已弃用
```

**新版（PR3）**:
```swift
var params = whisper_context_default_params()
let ctx = whisper_init_from_file_with_params(cPath, params) // ✅ 推荐
```

### 时间戳转换

whisper.cpp 返回的时间戳单位是 **百分之一秒**，需要除以 100：

```swift
let startTime = Double(whisper_full_get_segment_t0(ctx, i)) / 100.0  // 秒
let endTime = Double(whisper_full_get_segment_t1(ctx, i)) / 100.0    // 秒
```

### 线程数配置

```swift
params.n_threads = ProcessInfo.processInfo.activeProcessorCount
// 或者手动指定（Metal 可能不需要多线程）
params.n_threads = 1  // Metal 加速时
```

---

## ✅ 完成检查清单（DoD）

### 代码质量
- [ ] 编译通过（零警告）
- [ ] SwiftLint 通过（严格模式）
- [ ] 无硬编码字符串
- [ ] 覆盖率 ≥ 80%

### 测试
- [ ] 11 个单元测试通过
- [ ] Mock 音频生成函数完成
- [ ] 集成测试通过

### 文档
- [ ] README 更新
- [ ] CHANGELOG 更新
- [ ] 代码注释完整

### Review
- [ ] 自查通过
- [ ] 至少 1 位 reviewer 批准

---

## 📚 参考文档

- **详细设计**: [task-103-pr3-whisper-backend-implementation.md](./task-103-pr3-whisper-backend-implementation.md)
- **总体设计**: [task-103-asr-engine-protocol-whisper-backend.md](./task-103-asr-engine-protocol-whisper-backend.md)
- **PR2 完成**: [task-103-pr2-completion.md](./task-103-pr2-completion.md)
- **ADR-0007**: Whisper.cpp 集成策略
- **HLD §6**: ASR 引擎集成

---

## 🐛 常见问题

### Q1: 编译错误 "Cannot find type 'AsrSegment'"

**原因**: 未导入 PrismCore 或仍在使用临时定义

**解决**:
```swift
import PrismCore  // 确保导入

// 使用完整类型名（如有歧义）
let segment: PrismCore.AsrSegment = ...
```

### Q2: 运行时错误 "Model not loaded"

**原因**: 未调用 `loadModel(at:)` 或模型路径错误

**解决**:
```swift
// 确保在 transcribe 前加载模型
let backend = WhisperCppBackend()
let options = AsrOptions(modelPath: modelURL)
let segments = try await backend.transcribe(audioData: data, options: options)
```

### Q3: whisper_full() 返回 -1

**原因**: 音频格式错误或内存不足

**解决**:
- 验证音频格式（16kHz mono Float32）
- 检查音频数据长度（至少 0.1s，1600 samples）
- 查看 OSLog 日志获取详细错误

---

**版本**: v1.0  
**最后更新**: 2025-11-13  
**状态**: ✅ 准备就绪，可以开始实施！
