//
//  WelcomeView.swift
//  PrismPlayer
//
//  Created on 2025-11-13.
//  Purpose: 欢迎页面，提供媒体打开入口和最近历史
//

import SwiftUI

/// 欢迎页面视图
///
/// 功能：
/// - 显示应用功能介绍卡片
/// - 提供多种媒体打开方式（文件、URL、光盘、转码器）
/// - 显示最近打开的媒体历史
/// - 支持清空历史记录
///
/// 架构：MVVM，绑定 AppViewModel
struct WelcomeView: View {
    
    // MARK: - Properties
    
    /// 应用视图模型
    @ObservedObject var viewModel: AppViewModel
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            // 主内容区域
            VStack(spacing: 0) {
                // 顶部工具栏
                topBar
                
                // 主内容区域
                ScrollView {
                    VStack(spacing: 40) {
                        Spacer()
                            .frame(height: 40)
                        
                        // 功能卡片与操作卡片（横向布局）
                        HStack(alignment: .top, spacing: 24) {
                            // 左侧：功能简介卡
                            featureCard
                                .frame(maxWidth: 320)
                            
                            // 右侧：操作卡
                            actionCard
                                .frame(maxWidth: 320)
                        }
                        
                        // 最近历史区域
                        if !viewModel.recentItems.isEmpty {
                            historySection
                                .padding(.top, 20)
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 播放列表抽屉（右侧）
            if viewModel.showPlaylistDrawer {
                PlaylistDrawerView(viewModel: viewModel)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showPlaylistDrawer)
    }
    
    // MARK: - Subviews
    
    /// 顶部工具栏
    private var topBar: some View {
        HStack {
            Text(String(localized: "app.name"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            // 播放列表按钮
            Button {
                viewModel.togglePlaylistDrawer()
            } label: {
                Label(
                    String(localized: "playlist.toggle"),
                    systemImage: viewModel.showPlaylistDrawer ? "sidebar.right" : "sidebar.left"
                )
            }
            .buttonStyle(.link)
            .help(String(localized: viewModel.showPlaylistDrawer ? "playlist.hide" : "playlist.show"))
            
            Button {
                // TODO: 打开反馈页面
            } label: {
                Label(String(localized: "welcome.feedback"), systemImage: "envelope")
            }
            .buttonStyle(.link)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    /// 功能简介卡片
    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            Text(String(localized: "welcome.features.title"))
                .font(.headline)
                .foregroundColor(.primary)
            
            // 功能列表
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "camera",
                    text: String(localized: "welcome.features.screenshot")
                )
                FeatureRow(
                    icon: "photo.on.rectangle.angled",
                    text: String(localized: "welcome.features.gif")
                )
                FeatureRow(
                    icon: "airplayvideo",
                    text: String(localized: "welcome.features.cast")
                )
                FeatureRow(
                    icon: "waveform",
                    text: String(localized: "welcome.features.audio_sync")
                )
                FeatureRow(
                    icon: "film",
                    text: String(localized: "welcome.features.transcode")
                )
            }
            
            Spacer()
            
            // 主行动按钮
            Button {
                // TODO: 打开升级页面
            } label: {
                HStack {
                    Image(systemName: "lock.open")
                    Text(String(localized: "welcome.unlock_premium"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    /// 操作卡片
    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            Text(String(localized: "welcome.actions.title"))
                .font(.headline)
                .foregroundColor(.primary)
            
            // 操作按钮列表
            VStack(spacing: 12) {
                ActionButton(
                    icon: "folder",
                    title: String(localized: "welcome.actions.open_file"),
                    action: { viewModel.openFile() }
                )
                
                ActionButton(
                    icon: "opticaldisc",
                    title: String(localized: "welcome.actions.open_disc"),
                    action: { viewModel.openDisc() }
                )
                
                ActionButton(
                    icon: "link",
                    title: String(localized: "welcome.actions.open_url"),
                    action: { viewModel.openURL() }
                )
                
                ActionButton(
                    icon: "arrow.triangle.2.circlepath",
                    title: String(localized: "welcome.actions.open_transcoder"),
                    action: { viewModel.openTranscoder() }
                )
            }
            
            Spacer()
        }
        .padding(24)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    /// 最近历史区域
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(String(localized: "welcome.recent.title"))
                    .font(.headline)
                
                Spacer()
                
                Button(String(localized: "welcome.recent.clear")) {
                    viewModel.clearHistory()
                }
                .buttonStyle(.link)
            }
            
            // 历史项网格
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200, maximum: 300))
            ], spacing: 16) {
                ForEach(viewModel.recentItems) { item in
                    RecentItemCard(item: item) {
                        viewModel.selectRecentItem(item)
                    }
                }
            }
        }
        .padding(24)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

/// 功能行
private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 操作按钮
private struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

/// 最近项目卡片
private struct RecentItemCard: View {
    let item: MediaHistoryItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // 缩略图占位
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Image(systemName: "film")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                }
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(8)
                
                // 文件信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    Text(item.lastOpened, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("欢迎页面") {
    WelcomeView(viewModel: AppViewModel())
        .frame(width: 1024, height: 768)
}

#Preview("欢迎页面 - 有历史") {
    let viewModel = AppViewModel()
    // 添加测试数据
    viewModel.recentItems = [
        MediaHistoryItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/path/to/video1.mp4"),
            title: "测试视频 1.mp4",
            lastOpened: Date()
        ),
        MediaHistoryItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/path/to/video2.mov"),
            title: "测试视频 2.mov",
            lastOpened: Date().addingTimeInterval(-3600)
        )
    ]
    
    return WelcomeView(viewModel: viewModel)
        .frame(width: 1024, height: 768)
}
