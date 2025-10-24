# PrismCore

核心业务层 Package，提供通用模型、协议与服务。

## 职责

- 定义领域模型（Domain Models）
- 定义核心协议（Core Protocols）
- 提供基础服务（Base Services）
- 无平台特定依赖，可跨 iOS/macOS 共享

## 模块结构

```
PrismCore/
├── Models/          # 领域模型（AsrSegment, MediaInfo 等）
├── Protocols/       # 核心协议（AsrEngine, PlayerService 等）
└── Services/        # 基础服务（存储、日志等）
```

## 依赖关系

- **依赖**: 无外部依赖
- **被依赖**: PrismASR, PrismKit

## 使用示例

```swift
import PrismCore

let segment = AsrSegment(
    startTime: 0.0,
    endTime: 5.0,
    text: "Hello, world!",
    confidence: 0.95
)
```

## 开发规范

- 所有公开类型必须添加文档注释
- 遵循 SwiftLint 严格模式
- 单元测试覆盖率 ≥ 70%
