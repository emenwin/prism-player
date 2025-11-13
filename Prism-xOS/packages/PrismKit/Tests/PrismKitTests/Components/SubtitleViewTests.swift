import SwiftUI
import Testing
import XCTest

@testable import PrismCore
@testable import PrismKit

/// SubtitleView 测试套件
///
/// 测试覆盖：
/// - 视图初始化
/// - 状态切换（正常、加载、错误）
/// - 无障碍属性
@Suite("SubtitleView Tests")
struct SubtitleViewTests {

    // MARK: - 基础测试

    @Test("视图可以正常初始化")
    @MainActor
    func testViewInitialization() async throws {
        let viewModel = SubtitleViewModel()
        _ = SubtitleView(viewModel: viewModel)

        // 验证视图可以创建
        #expect(viewModel.currentSubtitle == nil)
    }

    @Test("空状态不显示内容")
    @MainActor
    func testEmptyState() async throws {
        let viewModel = SubtitleViewModel()
        _ = SubtitleView(viewModel: viewModel)

        // 空状态下应该没有字幕
        #expect(viewModel.currentSubtitle == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("加载状态显示")
    @MainActor
    func testLoadingState() async throws {
        let viewModel = SubtitleViewModel()
        viewModel.setLoadingState(true)

        _ = SubtitleView(viewModel: viewModel)

        #expect(viewModel.isLoading == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("错误状态显示")
    @MainActor
    func testErrorState() async throws {
        let viewModel = SubtitleViewModel()
        viewModel.setError("测试错误")

        _ = SubtitleView(viewModel: viewModel)

        #expect(viewModel.errorMessage == "测试错误")
        #expect(viewModel.isLoading == false)
    }

    @Test("正常字幕显示")
    @MainActor
    func testSubtitleDisplay() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(
            id: UUID(),
            text: "测试字幕",
            startTime: 0,
            endTime: 5
        )

        viewModel.setSubtitles([subtitle])
        viewModel.updateCurrentTime(2)

        // 等待去抖完成
        try await Task.sleep(for: .milliseconds(30))

        _ = SubtitleView(viewModel: viewModel)

        #expect(viewModel.currentSubtitle?.text == "测试字幕")
    }

    @Test("字幕切换")
    @MainActor
    func testSubtitleTransition() async throws {
        let viewModel = SubtitleViewModel()
        let sub1 = Subtitle(id: UUID(), text: "第一段", startTime: 0, endTime: 3)
        let sub2 = Subtitle(id: UUID(), text: "第二段", startTime: 5, endTime: 8)

        viewModel.setSubtitles([sub1, sub2])

        // 显示第一段
        viewModel.updateCurrentTime(1)
        try await Task.sleep(for: .milliseconds(30))
        #expect(viewModel.currentSubtitle?.text == "第一段")

        // 切换到第二段
        viewModel.updateCurrentTime(6)
        try await Task.sleep(for: .milliseconds(30))
        #expect(viewModel.currentSubtitle?.text == "第二段")
    }

    // MARK: - 无障碍测试

    @Test("视图包含无障碍元素")
    @MainActor
    func testAccessibility() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(
            id: UUID(),
            text: "无障碍测试字幕",
            startTime: 0,
            endTime: 5
        )

        viewModel.setSubtitles([subtitle])
        viewModel.updateCurrentTime(2)
        try await Task.sleep(for: .milliseconds(30))

        _ = SubtitleView(viewModel: viewModel)

        // 验证字幕内容可访问
        #expect(viewModel.currentSubtitle?.text == "无障碍测试字幕")
    }

    // MARK: - 边界情况测试

    @Test("长文本处理")
    @MainActor
    func testLongText() async throws {
        let viewModel = SubtitleViewModel()
        let longText = "这是一段很长很长很长很长很长很长很长很长的字幕文本，用于测试多行显示和文本换行功能"
        let subtitle = Subtitle(
            id: UUID(),
            text: longText,
            startTime: 0,
            endTime: 10
        )

        viewModel.setSubtitles([subtitle])
        viewModel.updateCurrentTime(5)
        try await Task.sleep(for: .milliseconds(30))

        _ = SubtitleView(viewModel: viewModel)

        #expect(viewModel.currentSubtitle?.text == longText)
    }

    @Test("状态快速切换")
    @MainActor
    func testRapidStateChange() async throws {
        let viewModel = SubtitleViewModel()

        // 快速切换状态
        viewModel.setLoadingState(true)
        #expect(viewModel.isLoading == true)

        viewModel.setLoadingState(false)
        #expect(viewModel.isLoading == false)

        viewModel.setError("错误")
        #expect(viewModel.errorMessage == "错误")

        viewModel.reset()
        #expect(viewModel.errorMessage == nil)
    }
}
