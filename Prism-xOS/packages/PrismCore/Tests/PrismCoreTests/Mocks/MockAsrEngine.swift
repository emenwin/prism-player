import Foundation
import PrismCore

/// Mock ASR 引擎 - 包内测试版本
/// 用于 PrismCore 包的单元测试
public actor MockAsrEngine: AsrEngine {
    public private(set) var transcribeCalled = false
    public private(set) var transcribeCallCount = 0
    public private(set) var cancelCalled = false
    public private(set) var lastAudioData: Data?
    public private(set) var lastOptions: AsrOptions?

    /// 调用历史（按时间顺序）
    public private(set) var transcribeHistory:
        [(audioData: Data, options: AsrOptions, timestamp: Date)] = []

    public var transcribeResult: Result<[AsrSegment], AsrError> = .success([])
    public var transcribeDelay: TimeInterval = 0
    private var isCancelled = false
    public var shouldFailOnCancel = true

    public init() {}

    public func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment] {
        transcribeCalled = true
        transcribeCallCount += 1
        lastAudioData = audioData
        lastOptions = options
        transcribeHistory.append((audioData, options, Date()))

        // 重置取消标志
        isCancelled = false

        if transcribeDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(transcribeDelay * 1_000_000_000))
        }

        // 检查是否被取消
        if isCancelled && shouldFailOnCancel {
            throw AsrError.cancelled
        }

        switch transcribeResult {
        case .success(let segments):
            return segments
        case .failure(let error):
            throw error
        }
    }

    public func cancel() async {
        cancelCalled = true
        isCancelled = true
    }

    public func setSegments(_ segments: [AsrSegment]) {
        self.transcribeResult = .success(segments)
    }

    public func setError(_ error: AsrError) {
        self.transcribeResult = .failure(error)
    }

    public func setTranscribeDelay(_ delay: TimeInterval) {
        self.transcribeDelay = delay
    }

    public func reset() {
        transcribeCalled = false
        transcribeCallCount = 0
        cancelCalled = false
        lastAudioData = nil
        lastOptions = nil
        transcribeHistory.removeAll()
        transcribeResult = .success([])
        transcribeDelay = 0
        shouldFailOnCancel = true
        isCancelled = false
    }
    
    /// 获取指定索引的调用记录
    public func getCall(at index: Int) -> (audioData: Data, options: AsrOptions, timestamp: Date)? {
        guard index >= 0 && index < transcribeHistory.count else { return nil }
        return transcribeHistory[index]
    }
}
