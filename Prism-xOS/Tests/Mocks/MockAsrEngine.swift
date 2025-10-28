import Foundation

@testable import PrismCore

/// Mock ASR 引擎用于单元测试
/// Mock ASR Engine for unit testing
///
/// 特性 / Features:
/// - 记录所有方法调用 / Records all method calls
/// - 可配置返回值和错误 / Configurable return values and errors
/// - 支持模拟延迟 / Supports simulated delays
/// - Actor 隔离确保线程安全 / Actor isolation for thread safety
///
/// 使用示例 / Usage Example:
/// ```swift
/// let mockEngine = MockAsrEngine()
/// await mockEngine.setTranscribeResult(.success([
///     AsrSegment(startTime: 0, endTime: 1, text: "Hello")
/// ]))
///
/// let result = try await mockEngine.transcribe(audioData: testData, options: .default)
///
/// let called = await mockEngine.transcribeCalled
/// XCTAssertTrue(called)
/// ```
///
/// - Created: Sprint 0, Task-009
/// - Last Updated: 2025-10-24
public actor MockAsrEngine: AsrEngine {
    // MARK: - Call Recording

    /// 是否调用过 transcribe 方法
    public private(set) var transcribeCalled = false

    /// transcribe 方法调用次数
    public private(set) var transcribeCallCount = 0

    /// 是否调用过 cancel 方法
    public private(set) var cancelCalled = false

    /// cancel 方法调用次数
    public private(set) var cancelCallCount = 0

    /// 最后一次调用的音频数据
    public private(set) var lastAudioData: Data?

    /// 最后一次调用的选项
    public private(set) var lastOptions: AsrOptions?

    /// 调用历史（按时间顺序）
    public private(set) var transcribeHistory:
        [(audioData: Data, options: AsrOptions, timestamp: Date)] = []

    // MARK: - Configuration

    /// transcribe 方法的返回结果
    public var transcribeResult: Result<[AsrSegment], AsrError> = .success([])

    /// 模拟的处理延迟（秒）
    public var transcribeDelay: TimeInterval = 0

    /// 是否在取消后立即失败
    public var shouldFailOnCancel = true

    // MARK: - State

    private var isCancelled = false

    // MARK: - Initialization

    public init() {}

    // MARK: - AsrEngine Protocol

    public func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment] {
        // 记录调用
        transcribeCalled = true
        transcribeCallCount += 1
        lastAudioData = audioData
        lastOptions = options
        transcribeHistory.append((audioData, options, Date()))

        // 重置取消标志
        isCancelled = false

        // 模拟延迟
        if transcribeDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(transcribeDelay * 1_000_000_000))
        }

        // 检查是否被取消
        if isCancelled && shouldFailOnCancel {
            throw AsrError.cancelled
        }

        // 返回配置的结果
        switch transcribeResult {
        case .success(let segments):
            return segments
        case .failure(let error):
            throw error
        }
    }

    public func cancel() async {
        cancelCalled = true
        cancelCallCount += 1
        isCancelled = true
    }

    // MARK: - Configuration Helpers

    /// 设置 transcribe 返回结果
    public func setTranscribeResult(_ result: Result<[AsrSegment], AsrError>) {
        self.transcribeResult = result
    }

    /// 设置成功返回的段列表
    public func setSegments(_ segments: [AsrSegment]) {
        self.transcribeResult = .success(segments)
    }

    /// 设置失败返回的错误
    public func setError(_ error: AsrError) {
        self.transcribeResult = .failure(error)
    }

    /// 设置模拟延迟
    public func setTranscribeDelay(_ delay: TimeInterval) {
        self.transcribeDelay = delay
    }

    // MARK: - Reset

    /// 重置所有状态和记录
    public func reset() {
        transcribeCalled = false
        transcribeCallCount = 0
        cancelCalled = false
        cancelCallCount = 0
        lastAudioData = nil
        lastOptions = nil
        transcribeHistory.removeAll()
        transcribeResult = .success([])
        transcribeDelay = 0
        shouldFailOnCancel = true
        isCancelled = false
    }

    // MARK: - Verification Helpers

    /// 验证是否使用指定语言调用
    public func wasCalledWith(language: AsrLanguage?) -> Bool {
        return transcribeHistory.contains { $0.options.language == language }
    }

    /// 验证音频数据大小
    public func wasCalledWithAudioSize(_ size: Int) -> Bool {
        return transcribeHistory.contains { $0.audioData.count == size }
    }

    /// 获取指定索引的调用记录
    public func getCall(at index: Int) -> (audioData: Data, options: AsrOptions, timestamp: Date)? {
        guard index >= 0 && index < transcribeHistory.count else { return nil }
        return transcribeHistory[index]
    }
}

// MARK: - Factory Method

extension AsrEngine where Self == MockAsrEngine {
    /// 创建测试用的 Mock 引擎
    /// - Parameter segments: 预设的识别结果段
    /// - Returns: MockAsrEngine 实例
    public static func mock(segments: [AsrSegment] = []) -> MockAsrEngine {
        let mock = MockAsrEngine()
        mock.setSegments(segments)
        return mock
    }

    /// 创建会失败的 Mock 引擎
    /// - Parameter error: 要抛出的错误
    /// - Returns: MockAsrEngine 实例
    public static func mockFailure(error: AsrError = .transcriptionFailed("Mock error"))
        -> MockAsrEngine
    {
        let mock = MockAsrEngine()
        mock.setError(error)
        return mock
    }
}
