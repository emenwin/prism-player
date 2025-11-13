import Testing
import XCTest

@testable import PrismCore

/// SubtitleViewModel 单元测试套件
///
/// 测试覆盖：
/// - 基础功能（初始化、设置字幕、重置）
/// - 时间对齐算法（精确匹配、容差匹配、越界）
/// - 字幕切换逻辑
/// - 性能指标（查找延迟、批量操作）
/// - 状态管理（加载、错误）
@Suite("SubtitleViewModel Tests")
struct SubtitleViewModelTests {

    // MARK: - 基础功能测试

    @Test("初始状态为空")
    @MainActor
    func testInitialState() async throws {
        let viewModel = SubtitleViewModel()

        #expect(viewModel.currentSubtitle == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("设置字幕列表后自动排序")
    @MainActor
    func testSetSubtitles() async throws {
        let viewModel = SubtitleViewModel()
        let subtitles = [
            Subtitle(id: UUID(), text: "Third", startTime: 20, endTime: 25),
            Subtitle(id: UUID(), text: "First", startTime: 0, endTime: 5),
            Subtitle(id: UUID(), text: "Second", startTime: 10, endTime: 15),
        ]

        viewModel.setSubtitles(subtitles)

        // 验证按 startTime 排序
        viewModel.updateCurrentTime(0)
        try await Task.sleep(for: .milliseconds(20))  // 等待去抖
        #expect(viewModel.currentSubtitle?.text == "First")
    }

    // MARK: - 时间对齐测试

    @Test("精确匹配字幕时间")
    @MainActor
    func testExactTimeMatch() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "Hello", startTime: 5, endTime: 10)
        viewModel.setSubtitles([subtitle])

        // 在字幕时间范围内
        viewModel.updateCurrentTime(7.5)
        try await Task.sleep(for: .milliseconds(20))

        #expect(viewModel.currentSubtitle?.id == subtitle.id)
    }

    @Test("容差内匹配字幕（±50ms）")
    @MainActor
    func testToleranceMatch() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "World", startTime: 10, endTime: 15)
        viewModel.setSubtitles([subtitle])

        // startTime - 40ms (在容差内)
        viewModel.updateCurrentTime(9.96)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == subtitle.id)

        // endTime + 40ms (在容差内)
        viewModel.updateCurrentTime(15.04)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == subtitle.id)
    }

    @Test("超出容差不匹配字幕")
    @MainActor
    func testOutOfToleranceNoMatch() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "Test", startTime: 20, endTime: 25)
        viewModel.setSubtitles([subtitle])

        // startTime - 60ms (超出容差)
        viewModel.updateCurrentTime(19.94)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle == nil)
    }

    @Test("字幕边界精确处理")
    @MainActor
    func testSubtitleBoundaries() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "Boundary Test", startTime: 10.0, endTime: 15.0)
        viewModel.setSubtitles([subtitle])

        // 精确 startTime
        viewModel.updateCurrentTime(10.0)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == subtitle.id)

        // 精确 endTime - 1ms (仍在范围内)
        viewModel.updateCurrentTime(14.999)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == subtitle.id)

        // 精确 endTime (半开区间，不包含)
        viewModel.updateCurrentTime(15.0)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == subtitle.id)  // 在容差内仍匹配
    }

    @Test("字幕切换时 ID 变化")
    @MainActor
    func testSubtitleTransition() async throws {
        let viewModel = SubtitleViewModel()
        let sub1 = Subtitle(id: UUID(), text: "First", startTime: 0, endTime: 5)
        let sub2 = Subtitle(id: UUID(), text: "Second", startTime: 10, endTime: 15)
        viewModel.setSubtitles([sub1, sub2])

        // 显示第一个字幕
        viewModel.updateCurrentTime(2)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == sub1.id)

        // 切换到第二个字幕
        viewModel.updateCurrentTime(12)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == sub2.id)

        // 字幕间隙，无显示
        viewModel.updateCurrentTime(7)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle == nil)
    }

    @Test("连续字幕无缝切换")
    @MainActor
    func testContinuousSubtitles() async throws {
        let viewModel = SubtitleViewModel()
        let sub1 = Subtitle(id: UUID(), text: "One", startTime: 0, endTime: 3)
        let sub2 = Subtitle(id: UUID(), text: "Two", startTime: 3, endTime: 6)
        let sub3 = Subtitle(id: UUID(), text: "Three", startTime: 6, endTime: 9)
        viewModel.setSubtitles([sub1, sub2, sub3])

        // 第一段
        viewModel.updateCurrentTime(1.5)
        try await Task.sleep(for: .milliseconds(30))
        #expect(viewModel.currentSubtitle?.text == "One")

        // 切换到第二段（边界 + 小偏移）
        viewModel.updateCurrentTime(3.1)
        try await Task.sleep(for: .milliseconds(30))
        #expect(viewModel.currentSubtitle?.text == "Two")

        // 切换到第三段（边界 + 小偏移）
        viewModel.updateCurrentTime(6.1)
        try await Task.sleep(for: .milliseconds(30))
        #expect(viewModel.currentSubtitle?.text == "Three")
    }  // MARK: - 性能测试

    @Test("100 个字幕查找性能 < 500ms")
    @MainActor
    func testLookupPerformance() async throws {
        let viewModel = SubtitleViewModel()
        let subtitles = (0..<100).map { i in
            Subtitle(
                id: UUID(),
                text: "Subtitle \(i)",
                startTime: TimeInterval(i * 5),
                endTime: TimeInterval(i * 5 + 4)
            )
        }
        viewModel.setSubtitles(subtitles)

        let startTime = CFAbsoluteTimeGetCurrent()

        // 模拟 100 次时间更新
        for i in 0..<100 {
            viewModel.updateCurrentTime(TimeInterval(i * 2))
        }

        try await Task.sleep(for: .milliseconds(200))  // 等待所有去抖完成

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        #expect(elapsed < 500, "100 次更新应 < 500ms (实际: \(elapsed)ms)")
    }

    @Test("顺序播放优化（线性扫描）")
    @MainActor
    func testSequentialPlaybackOptimization() async throws {
        let viewModel = SubtitleViewModel()
        var subtitles: [Subtitle] = []
        for i in 0..<50 {
            let subtitle = Subtitle(
                id: UUID(),
                text: "Subtitle \(i)",
                startTime: TimeInterval(i * 2),
                endTime: TimeInterval(i * 2) + 1.5
            )
            subtitles.append(subtitle)
        }
        viewModel.setSubtitles(subtitles)

        // 顺序播放（应使用线性扫描优化）
        for i in 0..<50 {
            let time = Double(i * 2) + 0.5
            viewModel.updateCurrentTime(time)
            try await Task.sleep(for: .milliseconds(25))
        }

        // 验证最后一个字幕
        #expect(viewModel.currentSubtitle?.text == "Subtitle 49")
    }

    @Test("随机 seek 性能（二分查找）")
    @MainActor
    func testRandomSeekPerformance() async throws {
        let viewModel = SubtitleViewModel()
        let subtitles = (0..<100).map { i in
            Subtitle(
                id: UUID(),
                text: "Subtitle \(i)",
                startTime: TimeInterval(i * 5),
                endTime: TimeInterval(i * 5 + 4)
            )
        }
        viewModel.setSubtitles(subtitles)

        let startTime = CFAbsoluteTimeGetCurrent()

        // 随机 seek（应使用二分查找）
        let seekTimes: [TimeInterval] = [250, 50, 400, 10, 300, 150, 450, 100, 350, 200]
        for time in seekTimes {
            viewModel.updateCurrentTime(time)
            try await Task.sleep(for: .milliseconds(20))
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        #expect(elapsed < 300, "10 次随机 seek 应 < 300ms (实际: \(elapsed)ms)")
    }

    // MARK: - 状态管理测试

    @Test("加载状态切换")
    @MainActor
    func testLoadingState() {
        let viewModel = SubtitleViewModel()

        viewModel.setLoadingState(true)
        #expect(viewModel.isLoading == true)
        #expect(viewModel.errorMessage == nil)

        viewModel.setLoadingState(false)
        #expect(viewModel.isLoading == false)
    }

    @Test("错误状态设置")
    @MainActor
    func testErrorState() {
        let viewModel = SubtitleViewModel()

        viewModel.setError("识别失败")
        #expect(viewModel.errorMessage == "识别失败")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.currentSubtitle == nil)
    }

    @Test("重置状态清空所有数据")
    @MainActor
    func testReset() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "Test", startTime: 0, endTime: 5)
        viewModel.setSubtitles([subtitle])
        viewModel.updateCurrentTime(2)
        try await Task.sleep(for: .milliseconds(20))

        viewModel.reset()

        #expect(viewModel.currentSubtitle == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - 边界情况测试

    @Test("空字幕列表")
    @MainActor
    func testEmptySubtitles() async throws {
        let viewModel = SubtitleViewModel()
        viewModel.setSubtitles([])

        viewModel.updateCurrentTime(10.0)
        try await Task.sleep(for: .milliseconds(20))

        #expect(viewModel.currentSubtitle == nil)
    }

    @Test("单个字幕")
    @MainActor
    func testSingleSubtitle() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "Only One", startTime: 5, endTime: 10)
        viewModel.setSubtitles([subtitle])

        // 在范围内
        viewModel.updateCurrentTime(7)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == subtitle.id)

        // 在范围外
        viewModel.updateCurrentTime(15)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle == nil)
    }

    @Test("快速路径优化（当前字幕仍有效）")
    @MainActor
    func testFastPathOptimization() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "Long Subtitle", startTime: 10, endTime: 20)
        viewModel.setSubtitles([subtitle])

        // 首次更新
        viewModel.updateCurrentTime(15.0)
        try await Task.sleep(for: .milliseconds(20))
        let firstSubtitle = viewModel.currentSubtitle
        #expect(firstSubtitle?.id == subtitle.id)

        // 多次更新相同字幕范围内的时间（应使用快速路径）
        for time in [15.1, 15.2, 15.3, 15.4, 15.5] {
            viewModel.updateCurrentTime(time)
            try await Task.sleep(for: .milliseconds(5))
        }

        // 字幕 ID 不应改变
        #expect(viewModel.currentSubtitle?.id == firstSubtitle?.id)
    }
}
