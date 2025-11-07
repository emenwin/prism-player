// TestPlayerService.swift
// PrismCoreTests
//
// Mock PlayerService - 用于状态机集成测试
// 提供可控的播放器行为模拟
//
// Created: 2025-11-07
// Sprint: S1, Task-104, PR4

import Foundation

@testable import PrismCore

/// Mock 播放器服务（测试桩）
///
/// 模拟真实 PlayerService 的行为，用于状态机集成测试
/// 支持可控的媒体加载、播放、暂停、seek 等操作
public actor TestPlayerService {
    // MARK: - Properties

    /// 当前媒体 URL
    public private(set) var currentMediaURL: URL?

    /// 当前播放进度（秒）
    public private(set) var currentProgress: TimeInterval = 0

    /// 是否正在播放
    public private(set) var isPlaying: Bool = false

    /// 是否已暂停
    public private(set) var isPaused: Bool = false

    /// 模拟的媒体时长（秒）
    public var mediaDuration: TimeInterval = 300  // 默认 5 分钟

    /// 加载延迟（模拟真实加载时间，秒）
    public var loadingDelay: TimeInterval = 0.1

    /// seek 延迟（秒）
    public var seekDelay: TimeInterval = 0.05

    /// 是否模拟加载失败
    public var shouldFailLoading: Bool = false

    /// 设置是否模拟加载失败
    public func setShouldFailLoading(_ shouldFail: Bool) {
        shouldFailLoading = shouldFail
    }

    /// 模拟的加载错误
    public var loadingError: PlayerError?
    /// 播放历史（用于验证）
    public private(set) var playHistory: [PlayerAction] = []

    // MARK: - Types

    /// 播放器操作记录
    public enum PlayerAction: Equatable {
        case loadMedia(URL)
        case play
        case pause
        case seek(to: TimeInterval)
        case stop
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// 加载媒体
    /// - Parameter url: 媒体 URL
    /// - Throws: PlayerError 如果加载失败
    public func loadMedia(_ url: URL) async throws {
        playHistory.append(.loadMedia(url))

        // 模拟加载延迟
        try? await Task.sleep(nanoseconds: UInt64(loadingDelay * 1_000_000_000))

        // 检查是否模拟失败
        if shouldFailLoading {
            let error = loadingError ?? .loadFailed("Simulated loading failure")
            throw error
        }

        currentMediaURL = url
        currentProgress = 0
        isPlaying = false
        isPaused = false
    }

    /// 开始播放
    public func play() {
        playHistory.append(.play)
        isPlaying = true
        isPaused = false
    }

    /// 暂停播放
    public func pause() {
        playHistory.append(.pause)
        isPlaying = false
        isPaused = true
    }

    /// 跳转到指定时间
    /// - Parameter time: 目标时间（秒）
    public func seek(to time: TimeInterval) async {
        playHistory.append(.seek(to: time))

        // 模拟 seek 延迟
        try? await Task.sleep(nanoseconds: UInt64(seekDelay * 1_000_000_000))

        currentProgress = min(max(0, time), mediaDuration)
    }

    /// 停止播放
    public func stop() {
        playHistory.append(.stop)
        isPlaying = false
        isPaused = false
        currentProgress = 0
        currentMediaURL = nil
    }

    /// 重置服务状态（测试用）
    public func reset() {
        currentMediaURL = nil
        currentProgress = 0
        isPlaying = false
        isPaused = false
        playHistory.removeAll()
        shouldFailLoading = false
        loadingError = nil
    }

    /// 模拟播放进度更新
    /// - Parameter progress: 新进度（秒）
    public func updateProgress(_ progress: TimeInterval) {
        currentProgress = min(max(0, progress), mediaDuration)
    }

    // MARK: - Verification Helpers

    /// 验证是否执行了指定操作
    /// - Parameter action: 要检查的操作
    /// - Returns: 如果执行过返回 true
    public func didPerform(_ action: PlayerAction) -> Bool {
        return playHistory.contains(action)
    }

    /// 获取指定操作的执行次数
    /// - Parameter action: 要检查的操作
    /// - Returns: 执行次数
    public func countOfAction(_ action: PlayerAction) -> Int {
        return playHistory.filter { $0 == action }.count
    }

    /// 获取最后一个操作
    public func lastAction() -> PlayerAction? {
        return playHistory.last
    }
}
