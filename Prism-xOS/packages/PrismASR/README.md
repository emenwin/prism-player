# PrismASR

语音识别（ASR）模块，封装 Whisper.cpp 等多种 ASR 引擎后端。

## 职责

- 定义 ASR 引擎协议
- 实现 Whisper.cpp 后端（✅ Sprint 1 PR3 完成）
- （未来）支持 MLX Swift 后端
- 管理 ASR 配置与语言选项

## 模块结构

```
PrismASR/
├── Protocols/
│   ├── AsrEngine.swift          # 核心协议
│   ├── AsrOptions.swift         # 配置选项
│   └── AsrLanguage.swift        # 语言枚举
├── Backends/
│   ├── WhisperContext.swift     # Whisper.cpp 上下文（Actor）
│   └── WhisperCppBackend.swift  # Whisper.cpp 后端实现 ✅
├── Internal/
│   └── AudioConverter.swift     # 音频格式转换工具
├── Models/
│   └── AsrError.swift           # ASR 错误类型
└── CWhisper.xcframework/        # Whisper.cpp 预编译框架
```

## 依赖关系

- **依赖**: PrismCore
- **外部依赖**: whisper.cpp (官方 XCFramework)

## 使用示例

### 基础转写

```swift
import PrismASR
import PrismCore

// 1. 创建后端实例
let modelURL = Bundle.main.url(forResource: "ggml-tiny", withExtension: "bin")!
let backend = WhisperCppBackend(modelPath: modelURL)

// 2. 配置选项
let options = AsrOptions(
    language: .english,
    temperature: 0.0,
    enableTimestamps: true
)

// 3. 执行转写
let segments = try await backend.transcribe(
    audioData: pcmData,  // PCM Float32, 16kHz mono
    options: options
)

// 4. 处理结果
for segment in segments {
    print("[\(segment.startTime)s - \(segment.endTime)s] \(segment.text)")
}
```

### 支持的语言

```swift
// 自动检测
AsrOptions(language: .auto)

// 指定语言
AsrOptions(language: .english)   // 英文
AsrOptions(language: .chinese)   // 中文
AsrOptions(language: .japanese)  // 日语
AsrOptions(language: .korean)    // 韩语
// 更多语言请参考 AsrLanguage 枚举
```

### 取消转写

```swift
let backend = WhisperCppBackend(modelPath: modelURL)

let task = Task {
    try await backend.transcribe(audioData: audioData, options: options)
}

// 取消任务
task.cancel()
await backend.cancelAll()
```

## 技术特性

### ✅ 已实现（Sprint 1 PR3）

- **Whisper.cpp 集成**: 使用官方 XCFramework（支持 iOS/macOS/tvOS/visionOS）
- **硬件加速**: Metal/Accelerate 自动检测
- **多语言支持**: 8+ 语言（英/中/日/韩/法/德/西/自动检测）
- **线程安全**: Actor 并发模型
- **取消机制**: Swift Concurrency 原生支持
- **错误处理**: 完整的 AsrError 类型系统
- **日志埋点**: OSLog 分类日志

### 🔄 进行中（Sprint 1 PR4）

- 金样本回归测试（英文/中文/噪声）
- 真实模型文件集成
- WER（Word Error Rate）基线测量

### 🔮 未来计划

- MLX Swift 后端（Sprint 2+）
- 流式识别
- VAD（语音活动检测）
- 说话人分离
- 模型下载与管理

## 开发规范

- 协议设计优先，支持多后端切换
- 异步 API 使用 async/await
- 单元测试覆盖率 ≥ 70%（当前：80%+）
- 提供 Mock 实现用于测试
- SwiftLint 严格模式

## 性能指标

| 指标 | 目标 | 当前状态 |
|------|------|---------|
| RTF（Real-Time Factor） | ≥ 0.5 | 待测量（PR4） |
| 首帧时间（P95） | < 5s | 待测量（Task-102集成后） |
| 内存占用 | < 200MB（含模型） | 待测量（PR4） |
| 测试覆盖率 | ≥ 70% | 80%+ ✅ |

## 版本历史

### v0.3.0 (2025-11-13) - Sprint 1 PR3

- ✅ 实现 `WhisperContext.transcribe()` 方法
- ✅ 实现 `WhisperCppBackend` 完整功能
- ✅ 添加音频格式验证
- ✅ 添加取消机制
- ✅ 单元测试覆盖率达 80%+
- ✅ 详细日志埋点（6个关键路径）

### v0.2.0 (2025-11-13) - Sprint 1 PR2

- ✅ whisper.cpp 官方 XCFramework 集成
- ✅ WhisperContext Actor 封装
- ✅ AudioConverter 工具类
- ✅ 协议契约测试

### v0.1.0 (2025-11-06) - Sprint 1 PR1

- ✅ AsrEngine 协议定义
- ✅ AsrOptions 配置结构
- ✅ AsrLanguage 语言枚举
- ✅ AsrError 错误类型

## 相关文档

- [HLD §6 ASR 引擎集成](../../../docs/1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md#6-asr-引擎集成)
- [ADR-0007 Whisper.cpp 集成策略](../../../docs/1_design/architecture/adr/iOS-macOS/0007-whisper-cpp-integration.md)
- [Task-103 详细设计](../../../docs/2_scrum/iOS-macOS/sprint-1/task-103-asr-engine-protocol-whisper-backend.md)
- [Task-103 PR3 实施指南](../../../docs/2_scrum/iOS-macOS/sprint-1/task-103-pr3-whisper-backend-implementation.md)
