# Prism Player

[![Build & Test](https://github.com/yourusername/prism-player/workflows/Build%20%26%20Test/badge.svg)](https://github.com/yourusername/prism-player/actions)
[![SwiftLint](https://github.com/yourusername/prism-player/workflows/SwiftLint/badge.svg)](https://github.com/yourusername/prism-player/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

音视频播放器，支持实时离线语音转文字字幕功能。

## 项目代号：Project Rosetta（罗塞塔计划）

- 含义：罗塞塔石碑是一块刻有古埃及象形文、世俗体和古希腊文三种语言的石碑，是破解古埃及象形文字的关键。
- 为何适合：该代号精准描述了我们的技术核心——“翻译”与“破解”。我们的 AI 模型像那块石碑，接收一种形式的信息（音频波形），将其“翻译”为另一种人类可读的形式（文字），强调技术挑战、精确性以及构建沟通桥梁的价值，契合以算法与工程为核心的团队气质。
- 使用约定（内部）：
	- 文档与沟通可使用“Project Rosetta/罗塞塔计划”作为项目代号；
	- 提交记录与任务标题可采用简写“[Rosetta] ...”以便检索；
	- 对外场景仍以正式产品名称呈现（如适用）。

## 文档分类

### 文档目录 [./docs](./docs/)

[./docs/文档目录详细说明](./docs/文档目录详细说明.md)

### 关键文档

- **需求**: [PRD v0.2](./docs/requirements/prd_v0.2.md)
- **Sprint 计划**: 
  - iOS/macOS: [Sprint Plan v0.2](./docs/scrum/iOS-macOS/sprint-plan-v0.2-updated.md)
  - Android: [Sprint Plan v0.2](./docs/scrum/Android/sprint-plan-v0.2.md)
- **CI/CD**: [CI/CD 文档](./docs/ci-cd.md)
- **代码规范**: 
  - iOS/macOS: [Prism-xOS README](./Prism-xOS/README.md)
  - Android: [Prism-Android README](./Prism-Android/README.md)（待创建）

最新 PRD：
- v0.2（当前）：[docs/requirements/prd_v0.2.md](./docs/requirements/prd_v0.2.md)
- v0.1（存档）：[docs/requirements/prd_v0.1.md](./docs/requirements/prd_v0.1.md)


## 工程目录

```
.
├── Prism-xOS/                # iOS / macOS 工程与 Swift Packages（Xcode Workspace）
│   ├── apps/
│   │   ├── PrismPlayer-iOS/
│   │   └── PrismPlayer-macOS/
│   └── packages/
│       ├── PrismCore/
│       ├── PrismASR/
│       └── PrismKit/
└── Prism-Android/            # Android 工程（Jetpack Compose + MVVM）
```
## 工程目录说明

- Prism-xOS：iOS 与 macOS 平台的应用工程与 Swift Packages 集合（Xcode Workspace），包含应用目录 `apps/` 和可复用模块 `packages/`（PrismCore/PrismASR/PrismKit）。
- Prism-Android：Android 平台工程，采用 Jetpack Compose + MVVM 架构与 Android Gradle 构建。
- Tests：跨模块共享的测试资源（Mocks、Fixtures）。
- scripts：仓库脚本与 CI 辅助文件。
