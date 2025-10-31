import AVFoundation
import Foundation
import OSLog

/// 音频缓存管理器
///
/// 职责：
/// - 管理音频缓冲区的内存缓存
/// - 实现 LRU（Least Recently Used）淘汰策略
/// - 响应内存压力，按三级策略清理
///
/// 核心算法：
/// 1. **LRU 淘汰**：
///    - 记录每个缓存项的最后访问时间
///    - 容量超限时，淘汰最久未使用的项
/// 2. **三级内存压力响应**：
///    - Level 1（Warning）：清理 ±60s 外的缓存
///    - Level 2（Urgent）：清理 ±30s 外的缓存
///    - Level 3（Critical）：仅保留 ±15s
/// 3. **容量限制**：
///    - 按内存大小（MB）限制
///    - 按缓存项数量限制
///
/// 使用示例：
/// ```swift
/// let cache = AudioCache(maxSizeMB: 10, maxItems: 100)
///
/// // 存储
/// await cache.set(key: "0-5000", buffer: audioBuffer)
///
/// // 读取
/// if let buffer = await cache.get(key: "0-5000") {
///     print("Cache hit")
/// }
///
/// // 内存压力
/// await cache.handleMemoryPressure(level: .urgent, currentTime: CMTime(seconds: 50, preferredTimescale: 600))
/// ```
///
/// 参考：
/// - Task-102 §3.2 差异 2: 内存压力响应策略
/// - Task-102 §4 实施计划 PR3
/// - Task-102 §5.3 AudioCache 测试用例
public actor AudioCache {
    private let logger = Logger(subsystem: "com.prismplayer.core", category: "audio.cache")

    /// 缓存项
    private struct CacheItem {
        let buffer: AudioBuffer
        var lastAccessTime: Date
    }

    /// 缓存存储（key: "startMs-endMs"）
    private var storage: [String: CacheItem] = [:]

    /// 最大缓存大小（字节）
    private let maxSizeBytes: Int

    /// 最大缓存项数量
    private let maxItems: Int

    /// 当前缓存大小（字节）
    private var currentSizeBytes: Int = 0

    /// 初始化
    /// - Parameters:
    ///   - maxSizeMB: 最大缓存大小（MB），默认 10 MB
    ///   - maxItems: 最大缓存项数量，默认 100
    public init(maxSizeMB: Int = 10, maxItems: Int = 100) {
        self.maxSizeBytes = maxSizeMB * 1024 * 1024
        self.maxItems = maxItems
    }

    /// 存储音频缓冲区
    /// - Parameters:
    ///   - key: 缓存 key（格式："\(startMs)-\(endMs)"）
    ///   - buffer: 音频缓冲区
    public func set(key: String, buffer: AudioBuffer) {
        let item = CacheItem(buffer: buffer, lastAccessTime: Date())

        // 如果已存在，先减去旧的大小
        if let oldItem = storage[key] {
            currentSizeBytes -= oldItem.buffer.sizeInBytes
        }

        // 存储新项
        storage[key] = item
        currentSizeBytes += buffer.sizeInBytes

        logger.debug(
            "缓存存储: key=\(key, privacy: .public), size=\(buffer.sizeInBytes, privacy: .public) bytes"
        )

        // 检查容量限制
        evictIfNeeded()
    }

    /// 获取音频缓冲区
    /// - Parameter key: 缓存 key
    /// - Returns: 音频缓冲区（如果存在）
    public func get(key: String) -> AudioBuffer? {
        guard var item = storage[key] else {
            logger.debug("缓存未命中: key=\(key, privacy: .public)")
            return nil
        }

        // 更新访问时间（LRU）
        item.lastAccessTime = Date()
        storage[key] = item

        logger.debug("缓存命中: key=\(key, privacy: .public)")
        return item.buffer
    }

    /// 删除指定缓存
    /// - Parameter key: 缓存 key
    public func remove(key: String) {
        if let item = storage.removeValue(forKey: key) {
            currentSizeBytes -= item.buffer.sizeInBytes
            logger.debug("缓存删除: key=\(key, privacy: .public)")
        }
    }

    /// 清空所有缓存
    public func removeAll() {
        storage.removeAll()
        currentSizeBytes = 0
        logger.notice("缓存已清空")
    }

    /// 处理内存压力
    ///
    /// 三级清理策略：
    /// - warning: 清理 ±60s 外的缓存
    /// - urgent: 清理 ±30s 外的缓存
    /// - critical: 仅保留 ±15s
    ///
    /// - Parameters:
    ///   - level: 内存压力等级
    ///   - currentTime: 当前播放时间
    public func handleMemoryPressure(level: MemoryPressureLevel, currentTime: CMTime) {
        guard level > .normal else { return }

        let retentionRange = level.retentionRange
        let currentSeconds = currentTime.seconds

        logger.notice(
            "处理内存压力: level=\(level.rawValue, privacy: .public), 保留范围=±\(retentionRange, privacy: .public)s"
        )

        var removedCount = 0
        var removedBytes = 0

        // 筛选需要保留的项
        let keysToRemove = storage.keys.filter { key in
            guard let timeRange = parseTimeRange(from: key) else { return false }

            let distance = min(
                abs(timeRange.start.seconds - currentSeconds),
                abs(timeRange.end.seconds - currentSeconds)
            )

            return distance > retentionRange
        }

        // 删除超出保留范围的项
        for key in keysToRemove {
            if let item = storage.removeValue(forKey: key) {
                removedBytes += item.buffer.sizeInBytes
                removedCount += 1
            }
        }

        currentSizeBytes -= removedBytes

        logger.notice(
            "内存压力清理完成: 删除 \(removedCount, privacy: .public) 项, 释放 \(removedBytes / 1024, privacy: .public) KB"
        )
    }

    /// 获取缓存项数量
    public var itemCount: Int {
        storage.count
    }

    /// 获取当前缓存大小（MB）
    public var currentSizeMB: Double {
        Double(currentSizeBytes) / 1024.0 / 1024.0
    }

    // MARK: - Private Methods

    /// LRU 淘汰（容量超限时）
    private func evictIfNeeded() {
        // 检查项数限制
        while storage.count > maxItems {
            evictLRUItem()
        }

        // 检查大小限制
        while currentSizeBytes > maxSizeBytes {
            evictLRUItem()
        }
    }

    /// 淘汰最久未使用的项
    private func evictLRUItem() {
        guard
            let lruKey = storage.min(by: { $0.value.lastAccessTime < $1.value.lastAccessTime })?.key
        else {
            return
        }

        if let item = storage.removeValue(forKey: lruKey) {
            currentSizeBytes -= item.buffer.sizeInBytes
            logger.debug("LRU 淘汰: key=\(lruKey, privacy: .public)")
        }
    }

    /// 解析时间范围（从 key）
    /// - Parameter key: 缓存 key（格式："\(startMs)-\(endMs)"）
    /// - Returns: CMTimeRange
    private func parseTimeRange(from key: String) -> CMTimeRange? {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
            let startMs = Int(parts[0]),
            let endMs = Int(parts[1])
        else {
            return nil
        }

        let start = CMTime(value: CMTimeValue(startMs), timescale: 1000)
        let end = CMTime(value: CMTimeValue(endMs), timescale: 1000)
        return CMTimeRange(start: start, end: end)
    }
}
