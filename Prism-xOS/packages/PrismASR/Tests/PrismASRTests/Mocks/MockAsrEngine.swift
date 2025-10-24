import Foundation
import PrismCore

@testable import PrismASR

/// Mock ASR 引擎（用于测试）
///
/// 提供可控的 ASR 行为，用于单元测试和集成测试。
public final class MockAsrEngine: AsrEngine {
    /// 预设的转写结果
    public var transcribeResult: [AsrSegment] = []

    /// 是否被调用的标记
    public var transcribeCalled = false

    /// 最后一次调用的参数
    public var lastAudioData: Data?
    public var lastOptions: AsrOptions?

    /// 模拟抛出的错误
    public var errorToThrow: Error?

    public init() {}

    public func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment] {
        transcribeCalled = true
        lastAudioData = audioData
        lastOptions = options

        if let error = errorToThrow {
            throw error
        }

        return transcribeResult
    }
}
