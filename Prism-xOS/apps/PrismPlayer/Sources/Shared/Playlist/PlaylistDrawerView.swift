//
//  PlaylistDrawerView.swift
//  PrismPlayer
//
//  Created on 2025-11-14.
//  Purpose: 播放列表抽屉视图，支持在 Welcome 和 Player 场景中显示
//

import SwiftUI

/// 播放列表抽屉视图
///
/// 功能：
/// - 显示播放列表中的媒体项
/// - 支持搜索、添加、删除媒体
/// - 支持拖拽重排
/// - 可在欢迎页和播放器页面共享使用
///
/// 架构：MVVM，绑定 AppViewModel
struct PlaylistDrawerView: View {
    
    // MARK: - Properties
    
    /// 应用视图模型
    @ObservedObject var viewModel: AppViewModel
    
    /// 搜索关键词
    @State private var searchText: String = ""
    
    /// 抽屉宽度
    @State private var drawerWidth: CGFloat = 280
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerBar
            
            Divider()
            
            // 搜索框
            searchBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider()
            
            // 播放列表内容
            if filteredItems.isEmpty {
                emptyState
            } else {
                playlistContent
            }
            
            Divider()
            
            // 底部工具栏
            bottomToolbar
        }
        .frame(width: drawerWidth)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Subviews
    
    /// 顶部标题栏
    private var headerBar: some View {
        HStack {
            Text(String(localized: "playlist.title"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // 关闭按钮
            Button {
                viewModel.togglePlaylistDrawer()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "playlist.close"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    /// 搜索框
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(String(localized: "playlist.search_placeholder"), text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
    }
    
    /// 播放列表内容
    private var playlistContent: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredItems) { item in
                    PlaylistItemRow(
                        item: item,
                        isSelected: false,
                        onSelect: {
                            viewModel.selectRecentItem(item)
                        },
                        onDelete: {
                            // TODO: 实现删除功能
                        }
                    )
                }
            }
        }
    }
    
    /// 空状态视图
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(String(localized: "playlist.empty_title"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(String(localized: "playlist.empty_message"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 底部工具栏
    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            // 添加文件按钮
            Button {
                viewModel.openFile()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help(String(localized: "playlist.add_file"))
            
            // 添加 URL 按钮
            Button {
                viewModel.openURL()
            } label: {
                Image(systemName: "link")
            }
            .buttonStyle(.borderless)
            .help(String(localized: "playlist.add_url"))
            
            Spacer()
            
            // 清空列表按钮
            Button {
                viewModel.clearHistory()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(String(localized: "playlist.clear_all"))
            .disabled(viewModel.recentItems.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Computed Properties
    
    /// 过滤后的列表项
    private var filteredItems: [MediaHistoryItem] {
        if searchText.isEmpty {
            return viewModel.recentItems
        } else {
            return viewModel.recentItems.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - PlaylistItemRow

/// 播放列表项行视图
private struct PlaylistItemRow: View {
    let item: MediaHistoryItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 播放图标
            Image(systemName: isSelected ? "play.circle.fill" : "play.circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)
            
            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(formatDate(item.lastOpened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 删除按钮（悬停时显示）
            if isHovering {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Color.gray.opacity(0.1) : Color.clear))
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
    
    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview("播放列表抽屉") {
    PlaylistDrawerView(viewModel: AppViewModel())
        .frame(height: 600)
}
