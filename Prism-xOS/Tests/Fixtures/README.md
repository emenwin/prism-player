# Fixtures

共享测试数据与资源文件目录。

## 使用规范

- 存放测试用的音频样本、JSON 数据、模型文件等
- 文件命名清晰反映用途，例如：`sample_10s_en.wav`、`asr_result_sample.json`
- 控制文件大小，避免大文件进入 Git（考虑使用 Git LFS）

## 目录结构建议

```
Fixtures/
├── audio/
│   ├── sample_10s_en.wav
│   └── sample_30s_zh.m4a
├── json/
│   └── asr_segments_sample.json
└── models/
    └── (考虑 Git LFS 或外部下载)
```
