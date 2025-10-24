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

推荐使用树形结构展示，清晰标注用途和关键文件：

```text
docs/
├── requirements/                 # 需求文档
│   ├── prd_v0.2.md               # 当前 PRD（最新）
│   ├── prd_v0.1.md               # PRD 历史版本
│   ├── prd_review-claude4.5.md   # PRD 评审报告（Claude 4.5）
│   ├── prd_review_gemini2.5.md   # PRD 评审报告（Gemini 2.5）
│   └── short.md                  # PRD 摘要/提要
└── tdd/                          # 技术设计文档（TDD/HLD，待补充）
└── adr/                          # Architecture Decision Records 规范
└── scrum/                        # Scrum 敏捷开发流程与任务
└── ci-cd.md                      # CI/CD 文档
└── Prism-xOS/                    # iOS 、macOS 项目工程目录
└── Prism-Android/                # Android 项目工程目录
```

### 关键文档

- **需求**: [PRD v0.2](./docs/requirements/prd_v0.2.md)
- **Sprint 计划**: [Sprint Plan v0.2](./docs/scrum/sprint-plan-v0.2-updated.md)
- **CI/CD**: [CI/CD 文档](./docs/ci-cd.md)
- **代码规范**: [Prism-xOS README](./Prism-xOS/README.md)

最新 PRD：
- v0.2（当前）：[docs/requirements/prd_v0.2.md](./docs/requirements/prd_v0.2.md)
- v0.1（存档）：[docs/requirements/prd_v0.1.md](./docs/requirements/prd_v0.1.md)

### PRD vs TDD 

PRD 文档应该聚焦于"做什么"（What）和"为什么"（Why），而不是"怎么做"（How）。架构图、线程模型、DI 策略等属于**技术设计文档（Technical Design Document, TDD）**的范畴，不应该出现在 PRD 中。

### PRD vs TDD 的职责分离

| 文档类型 | 核心职责 | 典型内容 | 负责人 |
|---------|---------|---------|--------|
| **PRD** | 定义产品需求 | 用户故事、功能列项、验收标准、成功指标 | PM/产品经理 |
| **TDD** | 定义技术方案 | 架构设计、API 设计、数据模型、技术选型细节 | 技术负责人/架构师 |

 