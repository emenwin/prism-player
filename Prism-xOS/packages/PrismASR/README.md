# PrismASR

语音识别（ASR）模块，封装 Whisper.cpp 等多种 ASR 引擎后端。

## 职责

- 定义 ASR 引擎协议
- 实现 Whisper.cpp 后端
- （未来）支持 MLX Swift 后端
- 管理 ASR 配置与语言选项

## 模块结构

```
PrismASR/
├── AsrEngine.swift          # 核心协议
├── AsrOptions.swift         # 配置选项
├── WhisperCppBackend.swift  # Whisper.cpp 实现
└── (未来) MlxBackend.swift  # MLX Swift 实现
```

## 依赖关系

- **依赖**: PrismCore
- **外部依赖**: whisper.cpp (后续 Sprint 1 集成)

## 使用示例

```swift
import PrismASR
import PrismCore

let engine = WhisperCppBackend()
let options = AsrOptions(language: "en", enableTimestamps: true)

let segments = try await engine.transcribe(
    audioData: audioData,
    options: options
)
```

## 开发规范

- 协议设计优先，支持多后端切换
- 异步 API 使用 async/await
- 单元测试覆盖率 ≥ 70%
- 提供 Mock 实现用于测试
