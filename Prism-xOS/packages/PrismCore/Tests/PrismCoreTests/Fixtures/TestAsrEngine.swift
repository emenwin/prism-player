// TestAsrEngine.swift
// PrismCoreTests
//
// Mock ASR Engine - 用于状态机集成测试
// 提供可控的语音识别行为模拟
//
// Created: 2025-11-07
// Sprint: S1, Task-104, PR4

import Foundation

@testable import PrismCore

/// Mock ASR 引擎（测试桩）
///
/// 模拟真实 ASR 引擎的行为，用于状态机集成测试
/// 支持可控的识别延迟、成功/失败场景
public actor TestAsrEngine {
    // MARK: - Properties

    /// 识别延迟（秒）
    public var recognitionDelay: TimeInterval = 0.2

    /// 设置识别延迟
    public func setRecognitionDelay(_ delay: TimeInterval) {
        recognitionDelay = delay
    }

    /// 是否模拟识别失败
    public var shouldFailRecognition: Bool = false
    /// 模拟的识别错误
    public var recognitionError: Error?

    /// 识别历史（用于验证）
    public private(set) var recognitionHistory: [RecognitionRequest] = []

    /// 当前正在识别的任务
    private var currentTask: Task<AsrResult, Error>?

    // MARK: - Types

    /// 识别请求记录
    public struct RecognitionRequest: Equatable {
        public let window: TimeRange
        public let mediaURL: URL
        public let timestamp: Date

        public init(window: TimeRange, mediaURL: URL, timestamp: Date = Date()) {
            self.window = window
            self.mediaURL = mediaURL
            self.timestamp = timestamp
        }
    }

    /// ASR 识别结果
    public struct AsrResult: Equatable, Sendable {
        public let text: String
        public let confidence: Double
        public let window: TimeRange

        public init(text: String, confidence: Double, window: TimeRange) {
            self.text = text
            self.confidence = confidence
            self.window = window
        }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// 开始语音识别
    /// - Parameters:
    ///   - window: 要识别的时间窗口
    ///   - mediaURL: 媒体文件 URL
    /// - Returns: 识别结果
    /// - Throws: Error 如果识别失败
    public func recognize(window: TimeRange, mediaURL: URL) async throws -> AsrResult {
        // 记录请求
        let request = RecognitionRequest(window: window, mediaURL: mediaURL)
        recognitionHistory.append(request)

        // 创建识别任务
        let task = Task<AsrResult, Error> {
            // 模拟识别延迟
            try await Task.sleep(nanoseconds: UInt64(recognitionDelay * 1_000_000_000))

            // 检查是否被取消
            try Task.checkCancellation()

            // 检查是否模拟失败
            if shouldFailRecognition {
                let error =
                    recognitionError
                    ?? NSError(
                        domain: "TestAsrEngine",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Simulated recognition failure"]
                    )
                throw error
            }

            // 返回模拟结果
            return AsrResult(
                text: "Mock transcription for \(window.description)",
                confidence: 0.95,
                window: window
            )
        }

        currentTask = task

        do {
            let result = try await task.value
            currentTask = nil
            return result
        } catch {
            currentTask = nil
            throw error
        }
    }

    /// 取消当前识别任务
    public func cancelCurrentRecognition() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// 重置引擎状态（测试用）
    public func reset() {
        currentTask?.cancel()
        currentTask = nil
        recognitionHistory.removeAll()
        shouldFailRecognition = false
        recognitionError = nil
    }

    // MARK: - Verification Helpers

    /// 获取识别请求总数
    public func recognitionCount() -> Int {
        return recognitionHistory.count
    }

    /// 获取指定窗口的识别请求
    /// - Parameter window: 时间窗口
    /// - Returns: 匹配的请求列表
    public func requests(for window: TimeRange) -> [RecognitionRequest] {
        return recognitionHistory.filter { $0.window == window }
    }

    /// 获取最后一个识别请求
    public func lastRequest() -> RecognitionRequest? {
        return recognitionHistory.last
    }

    /// 检查是否有正在进行的识别
    public func isRecognizing() -> Bool {
        return currentTask != nil && !(currentTask?.isCancelled ?? true)
    }
}
