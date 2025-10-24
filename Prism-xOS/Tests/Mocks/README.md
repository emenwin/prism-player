# Mocks

共享 Mock 对象目录，用于跨 Package 的测试复用。

## 使用规范

- Mock 对象应实现原有协议
- 提供可预测的行为与状态记录
- 命名采用 `Mock<ProtocolName>` 格式

## 示例

```swift
public final class MockAsrEngine: AsrEngine {
    public var transcribeResult: [AsrSegment] = []
    public var transcribeCalled = false
    
    public func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment] {
        transcribeCalled = true
        return transcribeResult
    }
}
```
