// TimeRange.swift
// PrismCore
//
// 时间范围数据结构
// 用于表示音频/视频的时间区间，支持识别窗口、缓存区间等场景
//
// Created: 2025-11-07

import Foundation

/// 时间范围（时间区间）
///
/// 用于表示媒体文件中的时间片段，例如：
/// - 识别窗口（当前正在识别的音频段）
/// - 缓存区间（已缓存的音频数据）
/// - 播放区间（用户选择的播放范围）
public struct TimeRange: Equatable, Sendable, Hashable {
    /// 起始时间（秒）
    public let start: TimeInterval

    /// 结束时间（秒）
    public let end: TimeInterval

    /// 创建时间范围
    /// - Parameters:
    ///   - start: 起始时间（秒）
    ///   - end: 结束时间（秒）
    /// - Note: end 必须大于或等于 start，否则会调整为相同值
    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = max(start, end)  // 确保 end >= start
    }

    /// 时间范围的长度（秒）
    public var duration: TimeInterval {
        return end - start
    }

    /// 时间范围的中点（秒）
    public var midpoint: TimeInterval {
        return (start + end) / 2.0
    }

    /// 检查是否包含指定时间点
    /// - Parameter time: 待检查的时间点（秒）
    /// - Returns: true 如果时间点在范围内（包含边界）
    public func contains(_ time: TimeInterval) -> Bool {
        return time >= start && time <= end
    }

    /// 检查是否与另一个时间范围重叠
    /// - Parameter other: 另一个时间范围
    /// - Returns: true 如果两个范围有重叠
    public func overlaps(_ other: TimeRange) -> Bool {
        return start < other.end && end > other.start
    }

    /// 计算与另一个时间范围的交集
    /// - Parameter other: 另一个时间范围
    /// - Returns: 交集范围，如果无交集则返回 nil
    public func intersection(_ other: TimeRange) -> TimeRange? {
        let newStart = max(start, other.start)
        let newEnd = min(end, other.end)

        guard newStart < newEnd else {
            return nil
        }

        return TimeRange(start: newStart, end: newEnd)
    }

    /// 计算与另一个时间范围的并集（仅当有重叠或相邻时）
    /// - Parameter other: 另一个时间范围
    /// - Returns: 并集范围，如果无法合并则返回 nil
    public func union(_ other: TimeRange) -> TimeRange? {
        // 检查是否重叠或相邻（容差 0.1 秒）
        guard overlaps(other) || abs(end - other.start) < 0.1 || abs(other.end - start) < 0.1 else {
            return nil
        }

        return TimeRange(
            start: min(start, other.start),
            end: max(end, other.end)
        )
    }
}

// MARK: - CustomStringConvertible

extension TimeRange: CustomStringConvertible {
    public var description: String {
        return String(format: "[%.1f-%.1f]s", start, end)
    }
}

// MARK: - Convenience Initializers

extension TimeRange {
    /// 创建从 0 开始的时间范围
    /// - Parameter duration: 时长（秒）
    /// - Returns: [0, duration] 的时间范围
    public static func fromZero(duration: TimeInterval) -> TimeRange {
        return TimeRange(start: 0, end: duration)
    }

    /// 创建以指定时间点为中心的时间范围
    /// - Parameters:
    ///   - center: 中心时间点（秒）
    ///   - duration: 总时长（秒）
    /// - Returns: 时间范围
    public static func centered(at center: TimeInterval, duration: TimeInterval) -> TimeRange {
        let halfDuration = duration / 2.0
        return TimeRange(
            start: max(0, center - halfDuration),
            end: center + halfDuration
        )
    }
}
