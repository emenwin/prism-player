# 测试 Fixtures

本目录包含测试所需的媒体文件样本。

## 音频样本

由于版权和文件大小原因，音频样本不包含在 Git 仓库中。您可以：

1. **使用远程测试流**（推荐）
   - 测试会自动使用 Apple 提供的公开 HLS 测试流
   - 无需额外配置

2. **添加本地测试文件**（可选）
   - 在 `audio/` 目录下放置任意测试音频/视频文件
   - 支持格式：mp4, mov, m4a, wav
   - 建议文件大小：< 5MB
   - 建议时长：10-30 秒

### 示例文件命名

```
audio/
├── sample.m4a      # 音频样本
├── sample.mp4      # 视频样本
└── sample.mov      # QuickTime 样本
```

### 生成测试音频

您可以使用 `ffmpeg` 生成简单的测试音频：

```bash
# 生成 10 秒的 440Hz 正弦波音频
ffmpeg -f lavfi -i "sine=frequency=440:duration=10" \
  -c:a aac -b:a 128k \
  Tests/Fixtures/audio/sample.m4a
```

## 字幕样本

测试用的字幕文件（SRT/VTT）。

```
subtitles/
├── sample.srt
└── sample.vtt
```
