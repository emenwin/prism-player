//
//  AppViewModel.swift
//  PrismPlayer
//
//  Created on 2025-11-13.
//  Purpose: 应用级视图模型，管理场景路由与全局状态
//

import Foundation
import SwiftUI
import AVFoundation

/// 应用场景枚举
enum AppScene {
    /// 欢迎页/首页
    case welcome
    /// 播放器页面
    case player(url: URL)
}

/// 应用级视图模型
///
/// 职责：
/// - 管理应用级路由状态（Welcome ↔ Player）
/// - 管理媒体选择与加载
/// - 管理最近打开历史
/// - 提供全局设置访问（主题、语言等）
///
/// 架构模式：MVVM
@MainActor
class AppViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前场景
    @Published var currentScene: AppScene = .welcome
    
    /// 最近打开的媒体列表
    @Published var recentItems: [MediaHistoryItem] = []
    
    /// 错误消息
    @Published var errorMessage: String?
    
    /// 是否显示播放列表抽屉
    @Published var showPlaylistDrawer: Bool = false
    
    // MARK: - Private Properties
    
    /// 用户默认设置
    private let userDefaults = UserDefaults.standard
    
    /// 最近历史的存储键
    private let recentItemsKey = "app.recent_items"
    
    // MARK: - Initialization
    
    init() {
        loadRecentItems()
    }
    
    // MARK: - Public Methods
    
    /// 导航到欢迎页
    func navigateToWelcome() {
        currentScene = .welcome
    }
    
    /// 导航到播放器页面
    /// - Parameter url: 媒体文件 URL
    func navigateToPlayer(url: URL) {
        addToRecentItems(url: url)
        currentScene = .player(url: url)
    }
    
    /// 关闭播放器，返回到欢迎页
    /// - Parameter player: 需要停止的 AVPlayer 实例（可选）
    func closePlayer(player: AVPlayer? = nil) {
        // 停止视频播放
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        
        // 返回到欢迎页
        currentScene = .welcome
    }
    
    /// 切换播放列表抽屉的显示状态
    func togglePlaylistDrawer() {
        showPlaylistDrawer.toggle()
    }
    
    /// 打开文件选择器
    func openFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .movie,
            .audio,
            .mpeg4Movie,
            .quickTimeMovie,
            .mpeg2Video,
            .audiovisualContent
        ]
        
        panel.begin { [weak self] response in
            guard let self = self else { return }
            
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    self.navigateToPlayer(url: url)
                }
            }
        }
        #endif
    }
    
    /// 打开 URL 输入对话框
    func openURL() {
        // TODO: 实现 URL 输入对话框
        errorMessage = "URL 输入功能即将推出"
    }
    
    /// 打开光盘
    func openDisc() {
        // TODO: 实现光盘播放功能
        errorMessage = "光盘播放功能即将推出"
    }
    
    /// 打开转码器
    func openTranscoder() {
        // TODO: 实现转码器功能
        errorMessage = "转码器功能即将推出"
    }
    
    /// 清空最近历史
    func clearHistory() {
        recentItems.removeAll()
        saveRecentItems()
    }
    
    /// 从最近历史中选择项目
    /// - Parameter item: 历史项目
    func selectRecentItem(_ item: MediaHistoryItem) {
        navigateToPlayer(url: item.url)
    }
    
    // MARK: - Private Methods
    
    /// 添加到最近历史
    private func addToRecentItems(url: URL) {
        // 移除已存在的相同项
        recentItems.removeAll { $0.url == url }
        
        // 添加到开头
        let item = MediaHistoryItem(
            id: UUID(),
            url: url,
            title: url.lastPathComponent,
            lastOpened: Date()
        )
        recentItems.insert(item, at: 0)
        
        // 限制最多保存 10 个
        if recentItems.count > 10 {
            recentItems = Array(recentItems.prefix(10))
        }
        
        saveRecentItems()
    }
    
    /// 加载最近历史
    private func loadRecentItems() {
        guard let data = userDefaults.data(forKey: recentItemsKey),
              let items = try? JSONDecoder().decode([MediaHistoryItem].self, from: data) else {
            return
        }
        recentItems = items
    }
    
    /// 保存最近历史
    private func saveRecentItems() {
        guard let data = try? JSONEncoder().encode(recentItems) else {
            return
        }
        userDefaults.set(data, forKey: recentItemsKey)
    }
}

// MARK: - MediaHistoryItem

/// 媒体历史记录项
struct MediaHistoryItem: Identifiable, Codable, Equatable {
    /// 唯一标识符
    let id: UUID
    
    /// 媒体文件 URL
    let url: URL
    
    /// 标题（文件名）
    let title: String
    
    /// 最后打开时间
    let lastOpened: Date
    
    /// 缩略图 URL（可选，未来实现）
    var thumbnailURL: URL?
}
