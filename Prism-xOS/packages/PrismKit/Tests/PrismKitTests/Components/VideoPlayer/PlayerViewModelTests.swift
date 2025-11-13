//
//  PlayerViewModelTests.swift
//  PrismKitTests
//
//  Created by Prism Player on 2025-11-13.
//

import XCTest
import AVFoundation
import Combine
@testable import PrismKit

/// PlayerViewModel 单元测试
@MainActor
final class PlayerViewModelTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var viewModel: PlayerViewModel!
    private var player: AVPlayer!
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 创建测试用的 AVPlayer
        player = AVPlayer()
        viewModel = PlayerViewModel(player: player)
        cancellables.removeAll()
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        viewModel = nil
        player = nil
        
        try await super.tearDown()
    }
    
    // MARK: - 初始化测试
    
    /// 测试初始状态
    func testInitialState() {
        XCTAssertFalse(viewModel.isPlaying, "初始状态应为未播放")
        XCTAssertEqual(viewModel.currentTime, 0, "初始播放时间应为 0")
        XCTAssertEqual(viewModel.rate, 1.0, "初始播放速度应为 1.0x")
        XCTAssertEqual(viewModel.volume, 1.0, "初始音量应为 1.0")
        XCTAssertFalse(viewModel.isMuted, "初始状态应为非静音")
        XCTAssertFalse(viewModel.isFullScreen, "初始状态应为非全屏")
        XCTAssertFalse(viewModel.isPipActive, "初始状态应为非画中画")
        XCTAssertNil(viewModel.error, "初始状态应无错误")
    }
    
    // MARK: - 播放控制测试
    
    /// 测试播放/暂停切换
    func testPlayPauseToggle() {
        // When: 播放
        viewModel.play()
        
        // Then: 状态应为播放中
        XCTAssertTrue(viewModel.isPlaying, "播放后状态应为 true")
        
        // When: 暂停
        viewModel.pause()
        
        // Then: 状态应为暂停
        XCTAssertFalse(viewModel.isPlaying, "暂停后状态应为 false")
    }
    
    /// 测试切换播放/暂停
    func testTogglePlayPause() {
        // Given: 初始状态为暂停
        XCTAssertFalse(viewModel.isPlaying)
        
        // When: 切换
        viewModel.togglePlayPause()
        
        // Then: 应为播放
        XCTAssertTrue(viewModel.isPlaying)
        
        // When: 再次切换
        viewModel.togglePlayPause()
        
        // Then: 应为暂停
        XCTAssertFalse(viewModel.isPlaying)
    }
    
    // MARK: - 进度跳转测试
    
    /// 测试跳转到有效时间
    func testSeekToValidTime() {
        // Given: 设置一个假的时长
        let duration: TimeInterval = 100
        
        // When: 跳转到 50 秒
        viewModel.seek(to: 50)
        
        // Then: currentTime 应立即更新（UI 反馈）
        XCTAssertEqual(viewModel.currentTime, 50, accuracy: 0.1, "跳转后应立即更新 currentTime")
    }
    
    /// 测试跳转到负数时间（应限制到 0）
    func testSeekToNegativeTime() {
        // When: 跳转到负数
        viewModel.seek(to: -10)
        
        // Then: 应被限制到 0
        XCTAssertEqual(viewModel.currentTime, 0, "负数时间应被限制到 0")
    }
    
    /// 测试跳转超过总时长（应限制到 duration）
    func testSeekBeyondDuration() {
        // Given: 假设时长为 100 秒（需要等待 player 加载完成）
        // 这里我们直接测试边界逻辑
        
        // When: 跳转到超过时长的时间
        viewModel.seek(to: 200)
        
        // Then: 应被限制到 duration（如果 duration 为 0，则为 0）
        XCTAssertLessThanOrEqual(viewModel.currentTime, viewModel.duration, "超出时长应被限制")
    }
    
    // MARK: - 播放速度测试
    
    /// 测试设置有效播放速度
    func testSetPlaybackRate() {
        // When: 设置为 1.5x
        viewModel.setRate(1.5)
        
        // Then: 速度应更新
        XCTAssertEqual(viewModel.rate, 1.5, "播放速度应更新为 1.5x")
        
        // When: 设置为 0.5x
        viewModel.setRate(0.5)
        
        // Then: 速度应更新
        XCTAssertEqual(viewModel.rate, 0.5, "播放速度应更新为 0.5x")
    }
    
    /// 测试设置超出范围的播放速度
    func testSetRateOutOfRange() {
        // When: 设置为过低的速度
        viewModel.setRate(0.1)
        
        // Then: 应被限制到最小值 0.5
        XCTAssertEqual(viewModel.rate, 0.5, "速度应被限制到最小值 0.5x")
        
        // When: 设置为过高的速度
        viewModel.setRate(3.0)
        
        // Then: 应被限制到最大值 2.0
        XCTAssertEqual(viewModel.rate, 2.0, "速度应被限制到最大值 2.0x")
    }
    
    // MARK: - 音量控制测试
    
    /// 测试设置音量
    func testVolumeControl() {
        // When: 设置音量为 0.5
        viewModel.setVolume(0.5)
        
        // Then: 音量应更新
        XCTAssertEqual(viewModel.volume, 0.5, accuracy: 0.01, "音量应更新为 0.5")
        
        // When: 设置音量为 0
        viewModel.setVolume(0)
        
        // Then: 音量应为 0
        XCTAssertEqual(viewModel.volume, 0, "音量应更新为 0")
    }
    
    /// 测试音量超出范围
    func testVolumeOutOfRange() {
        // When: 设置为负数
        viewModel.setVolume(-0.1)
        
        // Then: 应被限制到 0
        XCTAssertEqual(viewModel.volume, 0, "音量应被限制到最小值 0")
        
        // When: 设置为超过 1.0
        viewModel.setVolume(1.5)
        
        // Then: 应被限制到 1.0
        XCTAssertEqual(viewModel.volume, 1.0, accuracy: 0.01, "音量应被限制到最大值 1.0")
    }
    
    /// 测试静音切换
    func testToggleMute() {
        // Given: 初始状态为非静音
        XCTAssertFalse(viewModel.isMuted)
        
        // When: 切换静音
        viewModel.toggleMute()
        
        // Then: 应为静音
        XCTAssertTrue(viewModel.isMuted, "切换后应为静音")
        
        // When: 再次切换
        viewModel.toggleMute()
        
        // Then: 应取消静音
        XCTAssertFalse(viewModel.isMuted, "再次切换应取消静音")
    }
    
    /// 测试调高音量时自动取消静音
    func testVolumeUpUnmutes() {
        // Given: 静音状态
        viewModel.toggleMute()
        XCTAssertTrue(viewModel.isMuted)
        
        // When: 调高音量
        viewModel.setVolume(0.5)
        
        // Then: 应自动取消静音
        XCTAssertFalse(viewModel.isMuted, "调高音量应自动取消静音")
    }
    
    // MARK: - 进度条拖拽测试
    
    /// 测试进度条拖拽状态管理
    func testTimelineDragging() {
        // When: 开始拖拽
        viewModel.beginDraggingTimeline()
        
        // Then: 拖拽状态应生效（内部状态，无法直接验证，但不应崩溃）
        
        // When: 结束拖拽
        viewModel.endDraggingTimeline()
        
        // Then: 应恢复正常（内部状态）
    }
    
    // MARK: - 全屏模式测试
    
    /// 测试全屏切换
    func testToggleFullScreen() {
        // Given: 初始为非全屏
        XCTAssertFalse(viewModel.isFullScreen)
        
        // When: 切换全屏
        viewModel.toggleFullScreen()
        
        // Then: 应为全屏
        XCTAssertTrue(viewModel.isFullScreen, "切换后应为全屏")
        
        // When: 再次切换
        viewModel.toggleFullScreen()
        
        // Then: 应退出全屏
        XCTAssertFalse(viewModel.isFullScreen, "再次切换应退出全屏")
    }
    
    // MARK: - Combine 发布测试
    
    /// 测试播放状态变化是否发布
    func testPlayingStatePublishes() async throws {
        // Given: 期望值
        var receivedStates: [Bool] = []
        
        viewModel.$isPlaying
            .sink { state in
                receivedStates.append(state)
            }
            .store(in: &cancellables)
        
        // When: 改变播放状态
        viewModel.play()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        viewModel.pause()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: 应收到状态变化通知
        XCTAssertTrue(receivedStates.contains(true), "应发布播放状态")
        XCTAssertTrue(receivedStates.contains(false), "应发布暂停状态")
    }
}
