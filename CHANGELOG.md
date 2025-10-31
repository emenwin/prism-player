# Changelog

All notable changes to the PrismPlayer project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
