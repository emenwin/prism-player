# 测试数据固件（Fixtures）

本目录包含测试用的固定数据文件和辅助工具。

## 目录结构

```
Fixtures/
├── audio/              # 测试音频文件
│   ├── sample-1s.wav   # 1秒测试音频
│   ├── sample-5s.wav   # 5秒测试音频
│   ├── sample-30s.wav  # 30秒测试音频
│   └── README.md       # 音频文件说明
├── subtitles/          # 测试字幕文件
│   ├── sample.srt      # SRT 格式样本
│   ├── sample.vtt      # VTT 格式样本
│   └── README.md       # 字幕文件说明
└── README.md           # 本文件
```

## 使用指南

### 1. 加载测试数据

```swift
import XCTest

final class MyTests: XCTestCase {
    func loadFixture(named name: String, extension ext: String) throws -> Data {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw FixtureError.fileNotFound
        }
        return try Data(contentsOf: url)
    }
    
    func testWithAudio() throws {
        let audioData = try loadFixture(named: "sample-5s", extension: "wav")
        // 使用 audioData 进行测试
    }
}
```

### 2. 使用辅助类

```swift
import PrismCore

extension AsrSegment {
    /// 创建测试用的 AsrSegment
    static func fixture(
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 1,
        text: String = "Test"
    ) -> AsrSegment {
        AsrSegment(
            id: UUID(),
            mediaId: "test-media",
            startTime: startTime,
            endTime: endTime,
            text: text,
            confidence: 0.95,
            createdAt: Int64(Date().timeIntervalSince1970)
        )
    }
}

// 使用
let segment = AsrSegment.fixture(text: "Hello World")
```

## 音频文件规范

### 文件要求

- **格式**: WAV（未压缩，便于测试）
- **采样率**: 16kHz（符合 ASR 引擎要求）
- **声道**: 单声道（Mono）
- **位深度**: 16-bit PCM
- **大小**: 尽量小（减少仓库体积）

### 现有文件

详见 `audio/README.md`

## 字幕文件规范

### 文件要求

- **编码**: UTF-8
- **格式**: SRT/VTT
- **内容**: 包含常见场景（中英文、特殊字符、长文本等）

### 现有文件

详见 `subtitles/README.md`

## 测试数据原则

### 1. 版权合规

- ✅ 使用自生成的测试数据
- ✅ 使用公共领域素材
- ✅ 使用合成音频（TTS）
- ❌ 不使用受版权保护的内容

### 2. 数据最小化

- 文件尽量小（减少 Git 仓库体积）
- 仅包含测试必需的数据
- 优先使用代码生成（而非文件）

### 3. 可维护性

- 文件命名清晰（如 `sample-30s-en.wav`）
- 提供 README 说明文件用途
- 避免二进制文件变更（使用 Git LFS 可选）

## 辅助工具

### TestData.swift

提供常用测试数据的工厂方法：

```swift
enum TestData {
    static func sampleAudioData(duration: TimeInterval = 1.0) -> Data {
        // 生成指定时长的静音 WAV 数据
    }
    
    static func sampleSegments(count: Int = 5) -> [AsrSegment] {
        // 生成测试用的字幕段
    }
    
    static func sampleSRT() -> String {
        // 生成 SRT 格式字符串
    }
}
```

### FixtureLoader.swift

统一的固件加载器：

```swift
struct FixtureLoader {
    static func load(named name: String, extension ext: String) throws -> Data
    static func loadAudio(named name: String) throws -> Data
    static func loadSubtitle(named name: String) throws -> String
}
```

## 扩展指南

### 添加新的音频文件

1. 确保符合规范（16kHz, Mono, 16-bit PCM WAV）
2. 文件命名：`sample-<duration>-<language>.wav`
3. 更新 `audio/README.md`
4. 提交时考虑使用 Git LFS（如文件 >100KB）

### 添加新的字幕文件

1. 确保 UTF-8 编码
2. 文件命名：`sample-<scenario>.<format>`
3. 更新 `subtitles/README.md`
4. 提供中英文版本

## Git LFS 配置（可选）

如果音频文件较大（>100KB），考虑使用 Git LFS：

```bash
# 安装 Git LFS
brew install git-lfs
git lfs install

# 跟踪音频文件
git lfs track "Tests/Fixtures/audio/*.wav"
git add .gitattributes
```

## 参考资料

- [XCTest - Loading Test Resources](https://developer.apple.com/documentation/xctest)
- [Git LFS](https://git-lfs.github.com/)
- [Test Data Builders in Swift](https://www.swiftbysundell.com/articles/using-the-builder-pattern-in-swift/)

---

**维护者**: Prism Player Team  
**最后更新**: 2025-10-24
