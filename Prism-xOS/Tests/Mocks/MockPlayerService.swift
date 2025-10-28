import Combine
import Foundation

@testable import PrismCore

/// Mock 播放器服务用于单元测试
/// Mock Player Service for unit testing
///
/// 特性 / Features:
/// - 记录所有方法调用 / Records all method calls
/// - 可手动控制播放状态和时间 / Manual control of state and time
/// - 支持模拟播放进度 / Simulates playback progress
/// - 可配置错误 / Configurable errors
///
/// 使用示例 / Usage Example:
/// ```swift
/// let mockPlayer = MockPlayerService()
/// mockPlayer.setDuration(120.0)
///
/// try await mockPlayer.load(url: testURL)
/// await mockPlayer.play()
///
/// XCTAssertTrue(mockPlayer.playCalled)
/// XCTAssertTrue(mockPlayer.isPlaying)
/// ```
///
/// - Created: Sprint 0, Task-009
/// - Last Updated: 2025-10-24
public class MockPlayerService: PlayerService {
    // MARK: - Call Recording

    public private(set) var loadCalled = false
    public private(set) var loadCallCount = 0
    public private(set) var playCalled = false
    public private(set) var playCallCount = 0
    public private(set) var pauseCalled = false
    public private(set) var pauseCallCount = 0
    public private(set) var seekCalled = false
    public private(set) var seekCallCount = 0
    public private(set) var stopCalled = false
    public private(set) var stopCallCount = 0

    public private(set) var lastLoadURL: URL?
    public private(set) var lastSeekTime: TimeInterval?
    public private(set) var seekHistory: [TimeInterval] = []

    // MARK: - Configuration

    private var _currentTime: TimeInterval = 0
    private var _duration: TimeInterval = 0
    private var _playbackRate: Float = 1.0
    private var _isPlaying = false
    private var _state: PlayerState = .idle

    public var shouldFailOnLoad = false
    public var loadError: PlayerError?
    public var shouldFailOnSeek = false

    // MARK: - Publishers

    private let timeSubject = PassthroughSubject<TimeInterval, Never>()
    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)

    public var timePublisher: AnyPublisher<TimeInterval, Never> {
        timeSubject.eraseToAnyPublisher()
    }

    public var statePublisher: AnyPublisher<PlayerState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // MARK: - PlayerService Properties

    public var currentTime: TimeInterval {
        _currentTime
    }

    public var duration: TimeInterval {
        _duration
    }

    public var playbackRate: Float {
        get { _playbackRate }
        set { _playbackRate = newValue }
    }

    public var isPlaying: Bool {
        _isPlaying
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - PlayerService Methods

    public func load(url: URL) async throws {
        loadCalled = true
        loadCallCount += 1
        lastLoadURL = url

        if shouldFailOnLoad {
            let error = loadError ?? .loadFailed("Mock load error")
            setState(.error(error.localizedDescription))
            throw error
        }

        setState(.loading)
        // 模拟加载延迟
        try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        setState(.ready)
    }

    public func play() async {
        playCalled = true
        playCallCount += 1
        _isPlaying = true
        setState(.playing)
    }

    public func pause() async {
        pauseCalled = true
        pauseCallCount += 1
        _isPlaying = false
        setState(.paused)
    }

    public func seek(to time: TimeInterval) async {
        seekCalled = true
        seekCallCount += 1
        lastSeekTime = time
        seekHistory.append(time)

        guard !shouldFailOnSeek else {
            setState(.error("Seek failed"))
            return
        }

        setState(.seeking)
        _currentTime = time
        timeSubject.send(time)

        // 模拟 seek 延迟
        try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms

        if _isPlaying {
            setState(.playing)
        } else {
            setState(.paused)
        }
    }

    public func stop() async {
        stopCalled = true
        stopCallCount += 1
        _isPlaying = false
        _currentTime = 0
        setState(.stopped)
    }

    // MARK: - Manual Control (Test Helpers)

    /// 手动设置当前时间
    public func setCurrentTime(_ time: TimeInterval) {
        _currentTime = time
        timeSubject.send(time)
    }

    /// 手动设置总时长
    public func setDuration(_ duration: TimeInterval) {
        _duration = duration
    }

    /// 手动设置播放状态
    public func setState(_ state: PlayerState) {
        _state = state
        stateSubject.send(state)
    }

    /// 模拟播放进度（每次调用增加指定时长）
    public func simulateProgress(delta: TimeInterval) {
        guard _isPlaying else { return }
        _currentTime = min(_currentTime + delta, _duration)
        timeSubject.send(_currentTime)
    }

    /// 模拟播放到指定时间
    public func simulatePlayTo(time: TimeInterval) {
        guard time >= 0 && time <= _duration else { return }
        _currentTime = time
        timeSubject.send(time)
    }

    // MARK: - Reset

    /// 重置所有状态和记录
    public func reset() {
        loadCalled = false
        loadCallCount = 0
        playCalled = false
        playCallCount = 0
        pauseCalled = false
        pauseCallCount = 0
        seekCalled = false
        seekCallCount = 0
        stopCalled = false
        stopCallCount = 0

        lastLoadURL = nil
        lastSeekTime = nil
        seekHistory.removeAll()

        _currentTime = 0
        _duration = 0
        _playbackRate = 1.0
        _isPlaying = false
        _state = .idle

        shouldFailOnLoad = false
        loadError = nil
        shouldFailOnSeek = false
    }

    // MARK: - Verification Helpers

    /// 验证是否播放过
    public var hasPlayed: Bool {
        playCalled && playCallCount > 0
    }

    /// 验证是否暂停过
    public var hasPaused: Bool {
        pauseCalled && pauseCallCount > 0
    }

    /// 验证是否 seek 过
    public var hasSeeked: Bool {
        seekCalled && seekCallCount > 0
    }

    /// 验证是否 seek 到指定时间
    public func didSeek(to time: TimeInterval, tolerance: TimeInterval = 0.01) -> Bool {
        return seekHistory.contains { abs($0 - time) <= tolerance }
    }
}
