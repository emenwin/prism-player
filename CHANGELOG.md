# Changelog

All notable changes to the PrismPlayer project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - Sprint 1b, Task-1b02 (播放控件增强)

#### 播放器核心功能
- **PlayerViewModel 完整实现**
  - 完整的播放状态管理（播放/暂停、时间、速度、音量等）
  - AVPlayer 封装与生命周期管理
  - 30 FPS 时间观察器（0.033s 间隔）
  - 播放状态 KVO 观察（timeControlStatus, status）
  - 错误处理与 PlayerError 转换
  - 进度拖拽防抖机制（拖拽时暂停时间更新）
  - 完整日志记录（info/error/debug 级别）

- **BottomControlBarView 播放控制条**
  - 三段式布局（Leading/Center/Trailing Groups）
  - 播放/暂停、进度条、时间显示
  - 音量控制、静音切换
  - 播放速度选择（0.5x ~ 2.0x）
  - 全屏切换支持
  - 毛玻璃背景效果（Material.ultraThin）

- **TimelineSliderView 进度条组件**
  - 拖拽跳转支持
  - 缓冲进度显示
  - 拖拽时显示进度指示器
  - 点击跳转支持
  - 热区扩大（20pt 高度）

- **键盘快捷键支持（macOS）**
  - Space: 播放/暂停
  - Left/Right: ±5秒跳转
  - Up/Down: 音量调节（±10%）
  - F: 全屏切换
  - M: 静音切换

- **PlayerError 错误模型**
  - 4 类错误类型：loadFailed, decodingError, networkError, unknownError
  - 本地化错误描述、失败原因、恢复建议
  - AVFoundation 错误自动转换
  - 错误 UI 显示（黄色警告图标 + 重试按钮）

- **TimeInterval 格式化扩展**
  - HH:MM:SS 或 MM:SS 格式自动选择
  - 无效值处理（NaN, Infinite, 负数）
  - 性能优化（平均 0.002秒）

#### 测试覆盖
- **单元测试（27 个测试全部通过）**
  - PlayerViewModelTests: 16个测试
    - 初始状态、播放控制、进度跳转
    - 播放速度、音量控制、静音切换
    - 边界条件、错误处理
  - TimeIntervalFormattingTests: 11个测试
    - 各种时长格式化、边界值处理
    - 性能测试（0.002秒/次）
  - 测试覆盖率: ≥ 80%

#### 架构改进
- **MVVM 模式严格实施**
  - View 层：SwiftUI 视图组件
  - ViewModel 层：PlayerViewModel 状态管理
  - Model 层：AVPlayer + PlayerError
- **Combine 响应式编程**
  - @Published 属性自动发布状态变化
  - ObservableObject 驱动 UI 更新
- **线程安全**
  - @MainActor 确保 UI 操作在主线程
  - nonisolated(unsafe) 用于 deinit 中的观察器清理

### Added - Sprint 1, Task-103 PR3 (WhisperCppBackend Implementation)

#### Core ASR Functionality
- **WhisperContext.transcribe() Implementation**
  - Complete audio transcription pipeline using whisper.cpp C API
  - PCM Float32 audio format support (16kHz mono)
  - Configurable parameters: language, temperature, threads, timestamps
  - Automatic C string memory management
  - Segment parsing with time stamp conversion (centiseconds → seconds)
  - Cancellation support (every 10 segments check)
  - RTF (Real-Time Factor) calculation and logging
  - 6 key logging points (info/error/warning/debug levels)

- **WhisperCppBackend Complete Implementation**
  - AsrEngine protocol conformance
  - Automatic model loading on first transcribe call
  - Audio format validation (minimum 0.1s duration)
  - Error handling with detailed logging
  - Thread-safe with @unchecked Sendable
  - Support for default model path configuration

#### API Improvements
- **Type Unification**
  - Removed temporary `PrismASR.AsrSegment` definition
  - Unified to use `PrismCore.AsrSegment` across all modules
  - Updated all type references in tests

- **C API Upgrade**
  - Upgraded from deprecated `whisper_init_from_file` to `whisper_init_from_file_with_params`
  - Added context parameter configuration

#### Testing
- **WhisperCppBackendTests (8 tests)**
  - ✅ Empty audio error handling
  - ✅ Too-short audio error handling
  - ✅ Model not loaded error handling
  - ⏳ 5 tests awaiting real model (PR4)

- **Integration Tests (2 tests)**
  - ⏳ End-to-end transcription flow (PR4)
  - ⏳ Cancellation verification (PR4)

- **Test Helpers**
  - `generateMockAudio()` function for sine wave test audio
  - Mock audio duration/frequency/sample rate configuration

#### Documentation
- **README Updates**
  - Complete usage examples (basic transcription, language selection, cancellation)
  - Technical features list
  - Performance metrics table
  - Version history
  - Links to related documentation

- **Test Coverage**
  - 26 total tests (16 passed, 10 skipped awaiting PR4)
  - 0 failures
  - Coverage: 80%+ (error handling paths 100%)

### Changed
- **WhisperContext**
  - Enhanced logging with RTF metrics
  - Added empty text segment filtering
  - Improved error messages

### Technical Details
- **Commits**: 4 (8cf75c4, c3118ca, 8952397, 62b503e)
- **Files Changed**: 6
- **Lines Added**: ~450
- **Sprint**: S1
- **Task**: Task-103 PR3

### Added - Sprint 1, Task-102 (Audio Preload & Fast First Frame)

#### Audio Extraction
- **AudioBuffer Model**
  - PCM Float32 audio data encapsulation (16kHz mono)
  - Metadata tracking (sample rate, channels, time range)
  - Memory usage calculation (64 KB/s for 16kHz mono)
  - Custom string representation for debugging

- **AudioExtractor Protocol & Implementation**
  - Protocol-based abstraction for audio extraction
  - `AVAssetAudioExtractor` implementation using AVAssetReader
  - Automatic format conversion: any format → 16kHz mono Float32 PCM
  - Support for async operations and cancellation
  - Comprehensive error handling (7 error types)
  - Performance: 10s audio extraction P95 < 200ms (M1 Mac)

#### Preload Strategy
- **PreloadStrategy Configuration**
  - Three preset strategies: conservative/default/aggressive
  - Configurable parameters:
    - Preload duration (10s/30s/60s)
    - Fast first frame window (5s/10s)
    - Segment duration (15s/20s/30s)
    - Memory cache limit (5MB/10MB/20MB)
  - Automatic cache duration calculation

- **PreloadQueue with Priority Scheduling**
  - Priority-based task queue
  - Four priority levels: fastFirstFrame > seek > scroll > preload
  - Concurrent task limit (default: 3 tasks)
  - Task cancellation support
  - Wait for all tasks completion

- **AudioPreloadService**
  - Dual-path parallel first frame strategy:
    - Path A: 0-5s → immediate ASR (fastest first frame)
    - Path B: 5-10s → ASR queue (supplement)
    - Path C: 10-30s → background preload (low priority)
  - Audio buffer caching (avoid re-extraction)
  - Integration with AudioExtractor and PreloadQueue

#### Memory Management
- **MemoryPressureLevel**
  - Three-tier memory pressure levels:
    - warning: retain ±60s
    - urgent: retain ±30s
    - critical: retain ±15s only
  - Retention range calculation

- **AudioCache**
  - LRU (Least Recently Used) eviction strategy
  - Capacity limits: by size (MB) and item count
  - Last access time tracking
  - Three-tier memory pressure response
  - Current size monitoring (bytes/MB)

- **MemoryPressureMonitor**
  - System memory warning listener (iOS/macOS)
  - Graduated pressure detection:
    - 1 warning → warning
    - 3 warnings/30s → urgent
    - 5 warnings/60s → critical
  - Jitter prevention with sliding window
  - AsyncStream-based event publishing

#### Internationalization
- English (en) and Simplified Chinese (zh-Hans) localization
- 7 audio extraction error messages
- Resource bundle configuration in Package.swift

### Added - Sprint 1, Task-101 (Media Selection & Playback)

#### Core Features
- **Media Selection**
  - `MediaPicker` protocol for cross-platform media file selection abstraction
  - iOS implementation using `UIDocumentPickerViewController`
  - macOS placeholder implementation (functional in Sprint 2)
  - Support for video formats: mp4, mov, quicktime
  - Support for audio formats: m4a, aac, wav, mp3

- **Media Playback**
  - `PlayerViewModel` with MVVM architecture
  - `AVPlayerService` implementation using AVFoundation
  - Play/Pause controls with proper state management
  - Seek functionality with state preservation
  - Video rendering via `AVPlayerLayer` (iOS) and `AVPlayerView` (macOS)

- **Time Synchronization**
  - 10Hz time updates via `PlayerService.timePublisher`
  - Jitter control ≤50ms for subtitle rendering accuracy
  - Real-time progress UI binding through Combine

- **Error Handling**
  - Comprehensive `PlayerError` enum covering:
    - File not found
    - Unsupported format
    - Load failure
    - Seek failure
    - Unknown errors
  - Friendly error messages with internationalization (en/zh-Hans)
  - Proper state transitions on errors

- **Logging & Observability**
  - OSLog integration with subsystem: `com.prismplayer.app`
  - Player category logging for all key events:
    - load_start / load_ready
    - play / pause / seek
    - error with context
  - Proper log levels (debug/info/error)

- **Internationalization**
  - Complete localization for player UI (en/zh-Hans)
  - Error messages in both languages
  - No hardcoded strings

#### Testing
- **PlayerViewModel Unit Tests** (Coverage: ≥70%)
  - State transition tests (idle → loading → ready → playing → paused)
  - Time synchronization and jitter validation (<50ms)
  - All error scenarios (file not found, unsupported format, load failed, etc.)
  - User cancellation handling
  - Edge cases (multiple play calls, empty URL, error recovery)

- **MediaPickeriOS Tests**
  - File selection success/cancel scenarios
  - Type filtering validation
  - Error handling

#### Cross-Platform Support
- **iOS**
  - Full implementation of media selection and playback
  - UIDocumentPicker integration
  - AVPlayerLayer for video rendering

- **macOS**
  - Shared PlayerViewModel and PlayerService
  - Placeholder MediaPickerMac (compiles, doesn't crash)
  - Ready for Sprint 2 NSOpenPanel implementation

#### Code Quality
- SwiftLint strict mode compliance (0 violations)
- Protocol-based dependency injection
- Proper separation of concerns (ViewModel/Service/Platform layers)

### Changed
- N/A (Initial implementation)

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A

---

## Version History

### [0.1.0] - 2025-10-29 (Sprint 1 - M1 Prototype)

Initial release with basic media playback capabilities.

#### Milestones
- **M1 Prototype**: iOS basic playback baseline
  - Media selection (local files)
  - Play/Pause controls
  - Time synchronization for subtitle rendering
  - Error handling
  - macOS compilation support

#### Known Limitations
- macOS media selection not functional (placeholder implementation)
- No playback speed control
- No background playback support
- No audio preloading optimization
- First frame time not optimized

#### Next Sprint (Sprint 2)
- macOS NSOpenPanel implementation
- Security-scoped bookmarks for file access
- Playback speed controls (0.5x - 2.0x)
- Performance optimizations (first frame time)

---

## Contributing

When adding entries to this changelog:
1. Group changes by type (Added/Changed/Fixed/etc.)
2. Reference related Sprint and Task numbers
3. Include both technical and user-facing changes
4. Keep entries concise but descriptive
5. Update "Unreleased" section during development
6. Move to versioned section when releasing

## Links
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
- [Task-101 Documentation](docs/scrum/iOS-macOS/tasks/sprint-1/task-101-media-selection-and-playback-v1.1.md)
