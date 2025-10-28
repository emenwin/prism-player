//
//  MockMediaPicker.swift
//  PrismPlayer Tests
//
//  Created on 2025-10-28.
//

import Foundation
import UniformTypeIdentifiers

/// Mock 媒体选择器（用于单元测试）
///
/// 使用方式：
/// ```swift
/// let mockPicker = MockMediaPicker()
/// mockPicker.mockURL = URL(fileURLWithPath: "/path/to/test.mp4")  // 模拟选择成功
/// mockPicker.mockURL = nil  // 模拟用户取消
/// mockPicker.shouldThrow = true  // 模拟错误
/// ```
final class MockMediaPicker: MediaPicker {
    /// 模拟返回的 URL（nil 表示用户取消）
    var mockURL: URL?

    /// 是否抛出错误
    var shouldThrow = false

    /// 模拟的错误
    var mockError: Error = NSError(
        domain: "MockMediaPickerError",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Mock error"]
    )

    /// 记录最后一次调用的参数
    var lastAllowedTypes: [UTType]?

    /// 调用次数
    var selectMediaCallCount = 0

    func selectMedia(allowedTypes: [UTType]) async throws -> URL? {
        selectMediaCallCount += 1
        lastAllowedTypes = allowedTypes

        if shouldThrow {
            throw mockError
        }

        return mockURL
    }
}
