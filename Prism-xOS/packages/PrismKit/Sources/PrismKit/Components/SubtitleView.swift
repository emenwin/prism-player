import PrismCore
import SwiftUI

/// 字幕显示视图
///
/// 职责：
/// - 显示当前字幕文本
/// - 处理空状态/加载状态/错误状态
/// - 提供无障碍支持
///
/// # 设计规范
/// - 基础样式：白字黑底，底部居中，圆角 8pt
/// - 字体：系统字体 18pt，中等粗细
/// - 最多显示 3 行，自动换行
/// - 淡入淡出动画：0.2s
/// - 阴影：黑色 30% 透明度，模糊半径 4pt
///
/// # 无障碍支持
/// - VoiceOver 支持，正确朗读字幕内容
/// - 动态字体大小支持（未来）
/// - 高对比度模式支持（未来）
///
/// # 示例
/// ```swift
/// struct PlayerView: View {
///     @StateObject private var subtitleVM = SubtitleViewModel()
///
///     var body: some View {
///         ZStack {
///             VideoPlayer(...)
///             SubtitleView(viewModel: subtitleVM)
///         }
///     }
/// }
/// ```
public struct SubtitleView: View {
    // MARK: - Properties

    @ObservedObject private var viewModel: SubtitleViewModel

    // MARK: - Initialization

    /// 创建字幕视图
    ///
    /// - Parameter viewModel: 字幕视图模型
    public init(viewModel: SubtitleViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        VStack {
            Spacer()

            contentView
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.2), value: viewModel.currentSubtitle?.id)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Content Views

    /// 根据状态显示不同内容
    @ViewBuilder
    private var contentView: some View {
        if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else if viewModel.isLoading {
            loadingView
        } else if let subtitle = viewModel.currentSubtitle {
            subtitleView(subtitle: subtitle)
        }
        // 无字幕时不显示任何内容
    }

    /// 字幕文本视图
    private func subtitleView(subtitle: Subtitle) -> some View {
        Text(subtitle.text)
            .font(.system(size: 18, weight: .medium, design: .default))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)  // 最多 3 行
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("subtitle_current")
            .accessibilityValue(subtitle.text)
            .accessibilityAddTraits(.isStaticText)
    }

    /// 加载状态视图
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)

            Text("subtitle_loading")
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("subtitle_loading_accessibility")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// 错误状态视图
    private func errorView(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)

            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.8))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("subtitle_error_accessibility")
        .accessibilityValue(message)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Preview Provider

#Preview("正常显示字幕") {
    let viewModel = SubtitleViewModel()
    viewModel.setSubtitles([
        Subtitle(id: UUID(), text: "这是一段测试字幕文本", startTime: 0, endTime: 5)
    ])
    Task { @MainActor in
        viewModel.updateCurrentTime(2)
    }

    return ZStack {
        Color.gray
        SubtitleView(viewModel: viewModel)
    }
    .ignoresSafeArea()
}

#Preview("加载状态") {
    let viewModel = SubtitleViewModel()
    viewModel.setLoadingState(true)

    return ZStack {
        Color.gray
        SubtitleView(viewModel: viewModel)
    }
    .ignoresSafeArea()
}

#Preview("错误状态") {
    let viewModel = SubtitleViewModel()
    viewModel.setError("识别失败：网络错误")

    return ZStack {
        Color.gray
        SubtitleView(viewModel: viewModel)
    }
    .ignoresSafeArea()
}

#Preview("长文本换行") {
    let viewModel = SubtitleViewModel()
    viewModel.setSubtitles([
        Subtitle(
            id: UUID(),
            text: "这是一段很长的字幕文本，用于测试多行显示效果和文本换行功能，确保在各种设备上都能正常显示",
            startTime: 0,
            endTime: 10
        )
    ])
    Task { @MainActor in
        viewModel.updateCurrentTime(5)
    }

    return ZStack {
        Color.gray
        SubtitleView(viewModel: viewModel)
    }
    .ignoresSafeArea()
}
