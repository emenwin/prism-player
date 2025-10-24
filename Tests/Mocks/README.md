# 共享 Mock 实现

本目录包含跨包共享的 Mock/Stub/Fake 测试替身实现。

## 命名约定

### Mock（模拟对象）
**用途**: 可验证交互的测试替身，记录方法调用信息。

**命名**: `Mock<InterfaceName>`

**示例**: `MockAsrEngine`、`MockPlayerService`

**特性**:
- 记录方法调用次数
- 记录调用参数
- 支持验证调用顺序
- 可配置返回值或抛出错误

### Stub（桩对象）
**用途**: 提供预设响应的测试替身，不验证交互。

**命名**: `Stub<InterfaceName>`

**示例**: `StubAsrEngine`

**特性**:
- 简单返回预设值
- 不记录调用信息
- 用于提供测试数据

### Fake（伪对象）
**用途**: 简化实现的测试替身，有实际逻辑但比真实实现简单。

**命名**: `Fake<InterfaceName>`

**示例**: `FakeAsrSegmentStore`（内存数据库）

**特性**:
- 包含简化的业务逻辑
- 通常使用内存存储
- 可用于集成测试

### Spy（间谍对象）
**用途**: 记录调用信息的测试替身，用于验证调用顺序。

**命名**: `Spy<InterfaceName>`

**示例**: `SpyMetricsCollector`

**特性**:
- 记录所有调用及顺序
- 可验证调用链
- 用于行为验证

## 使用指南

### 1. 导入 Mock

```swift
import XCTest
@testable import PrismCore

// 从共享目录导入
// 注意：需要在测试目标中添加文件引用

final class MyServiceTests: XCTestCase {
    var mockEngine: MockAsrEngine!
    
    override func setUp() {
        mockEngine = MockAsrEngine()
    }
}
```

### 2. 配置 Mock 行为

```swift
// 配置返回值
await mockEngine.setTranscribeResult(.success([
    AsrSegment(startTime: 0, endTime: 1, text: "Hello")
]))

// 配置延迟（模拟异步操作）
await mockEngine.setTranscribeDelay(0.5)

// 配置错误
await mockEngine.setTranscribeResult(.failure(.modelLoadFailed))
```

### 3. 验证交互

```swift
// 验证方法被调用
let called = await mockEngine.transcribeCalled
XCTAssertTrue(called)

// 验证调用次数
let count = await mockEngine.transcribeCallCount
XCTAssertEqual(count, 2)

// 验证调用参数
let lastAudio = await mockEngine.lastAudioData
XCTAssertEqual(lastAudio?.count, 1024)
```

## 最佳实践

### 1. 使用 Actor 隔离

所有 Mock 实现应使用 `actor` 确保线程安全：

```swift
actor MockAsrEngine: AsrEngine {
    private(set) var transcribeCalled = false
    // ...
}
```

### 2. 提供 Reset 方法

每个 Mock 应提供重置状态的方法：

```swift
func reset() {
    transcribeCalled = false
    transcribeCallCount = 0
    lastAudioData = nil
}
```

### 3. 使用 Result 类型

配置返回值时使用 `Result` 类型统一处理成功和失败：

```swift
var transcribeResult: Result<[AsrSegment], AsrError> = .success([])
```

### 4. 记录完整上下文

记录足够的调用信息用于断言：

```swift
private(set) var transcribeHistory: [(audioData: Data, options: AsrOptions)] = []

func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment] {
    transcribeHistory.append((audioData, options))
    // ...
}
```

## 可用的 Mock 实现

### MockAsrEngine
ASR 引擎的 Mock 实现，支持：
- 配置转写结果
- 记录调用参数
- 模拟延迟和错误

**文件**: `MockAsrEngine.swift`

### MockPlayerService
播放器服务的 Mock 实现，支持：
- 模拟播放状态
- 控制时间进度
- 触发回调

**文件**: `MockPlayerService.swift`

### MockMetricsCollector
指标采集器的 Mock 实现，支持：
- 记录所有指标
- 验证指标名称和值
- 导出指标历史

**文件**: `MockMetricsCollector.swift`

## 扩展指南

添加新的 Mock 实现时：

1. **创建文件**: `Mock<InterfaceName>.swift`
2. **遵循协议**: 实现目标协议的所有方法
3. **添加记录**: 记录方法调用信息
4. **配置行为**: 提供配置返回值的方法
5. **提供重置**: 实现 `reset()` 方法
6. **编写文档**: 在本 README 中添加说明

## 参考资料

- [ADR-0005: 测试架构与 DI 策略](../../docs/adr/0005-testing-di-strategy.md)
- [Test Doubles in Swift](https://www.vadimbulavin.com/swift-mocks-stubs-spies/)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)

---

**维护者**: Prism Player Team  
**最后更新**: 2025-10-24
