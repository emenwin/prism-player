# Prism Player Android Scrum 文档目录

> 最后更新：2025-10-25

## 概述

本目录包含 Prism Player Android 端的 Scrum 敏捷开发相关文档，包括 Sprint 规划、任务跟踪、回顾总结等。

---

## 文档结构

```text
docs/scrum/Android/
├── README.md                      # 本文件：文档导航
├── sprint-plan-v0.2.md            # Sprint 总体规划（v0.2）
├── reviews/                       # Sprint 评审记录
│   └── (待补充)
└── tasks/                         # 任务拆分与跟踪
    ├── README.md                  # 任务管理说明
    ├── sprint-0/                  # Sprint 0 任务详情
    ├── sprint-1/                  # Sprint 1 任务详情
    └── ...
```

---

## 核心文档

### 1. Sprint 规划
- **[Sprint Plan v0.2](./sprint-plan-v0.2.md)**  
  **状态**：✅ 最新版本  
  **描述**：基于 PRD v0.2 和 HLD v0.2 的完整 Sprint 规划，覆盖 Sprint 0 至 Sprint 5（M1–M3 里程碑）。  
  **关键内容**：
  - Sprint 0：基础设施（1 周）
  - Sprint 1–2：M1 原型（播放器 + ASR + 首帧字幕）
  - Sprint 3–4：M2 可用版（模型管理 + 翻译）
  - Sprint 5：M3 优化版（性能 + 质量感知）

---

## Scrum 工作流

参考：[Scrum 工作流规范](../scrum.md)

### 迭代周期
- **Sprint 长度**：2–4 周
- **团队假设**：2 人（可调整）
- **每 Sprint 容量**：~38 Story Points（3 周 Sprint）

### 关键事件
1. **Sprint Planning**：定义 Sprint Goal，选择 PBIs
2. **Daily Scrum**：每日同步（≤15 分钟）
3. **Sprint Review**：演示增量，收集反馈
4. **Sprint Retrospective**：复盘与改进

### 工件
- **Product Backlog**：优先级排序的需求列表
- **Sprint Backlog**：当前 Sprint 承诺的任务
- **Increment**：可发布的产品增量

---

## 任务管理

### 任务拆分原则
- 每个用户故事拆分为可验收的任务（≤8 SP）
- 技术任务（Spike/Enabler）明确标注
- 每个任务包含：
  - 优先级（P0–P2）
  - 估算（Story Points）
  - 验收标准（AC）
  - 负责人

### 任务跟踪工具
- **推荐**：GitHub Projects / Jira / Linear
- **状态流转**：To Do → In Progress → In Review → Done

---

## 度量指标

### Sprint 级指标
- **Velocity**：每 Sprint 完成的 Story Points
- **Burndown Chart**：剩余工作量趋势
- **Defect Density**：Bug 数 / Story Points

### 产品级指标（KPI）
| 指标 | 高端设备 | 中端设备 | 入门设备 |
|------|---------|---------|---------|
| 首帧字幕（P95） | ≤5s | ≤8s | ≤12s |
| RTF | ≥1.0 | ≥0.5 | ≥0.3 |
| 同步偏差 | ≤±200ms | ≤±200ms | ≤±200ms |

---

## Definition of Done (DoD)

每个 PBI 完成时必须满足：
- [ ] 代码实现符合验收标准（AC）
- [ ] 单元测试覆盖率 ≥70%（关键模块 ≥80%）
- [ ] UI 测试覆盖核心路径
- [ ] 代码通过 CI（构建、测试、Detekt、ktlint）
- [ ] Code Review 完成（至少 1 人 Approve）
- [ ] 文档更新（如 API 文档、README）
- [ ] 无未解决的 P0/P1 Bug
- [ ] 国际化字符串完整（中英文）
- [ ] 符合可访问性基线（TalkBack 可用）

---

## 相关文档

### 需求与设计
- [PRD v0.2](../../requirements/prd_v0.2.md)
- [HLD Android v0.2](../../tdd/Android/hld-android-v0.2.md)

### 架构决策
- [ADR 0001：多平台架构](../../adr/iOS-macOS/0001-multiplatform-architecture.md)
- [ADR 0005：测试与 DI 策略](../../adr/iOS-macOS/0005-testing-di-strategy.md)

### 代码规范
- [Prism-Android README](../../../Prism-Android/README.md)（待创建）

---

## 快速开始

### 新成员上手
1. 阅读 [PRD v0.2](../../requirements/prd_v0.2.md) 了解产品需求
2. 阅读 [HLD Android v0.2](../../tdd/Android/hld-android-v0.2.md) 了解技术架构
3. 查看 [Sprint Plan v0.2](./sprint-plan-v0.2.md) 了解当前进度
4. 参与 Daily Scrum 与 Sprint Planning

### 开发流程
1. 从 Sprint Backlog 领取任务
2. 创建 Feature Branch（如 `feature/ASR-001-whisper-integration`）
3. 开发 + 测试（满足 DoD）
4. 提交 PR 并进行 Code Review
5. 合并到 `develop` 分支

---

## 常见问题（FAQ）

### Q1：如何估算 Story Points？
参考 [Sprint Plan v0.2 第 11.1 节](./sprint-plan-v0.2.md#111-story-points-定义)。

### Q2：如何处理技术债务？
作为 Enabler/Spike 任务纳入 Sprint Backlog，优先级由 Product Owner 与团队协商。

### Q3：如何调整 Sprint 容量？
每个 Sprint Retrospective 后根据实际 Velocity 调整下个 Sprint 承诺的 Story Points。

---

## 更新日志

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v0.2 | 2025-10-25 | 初始版本，完整 Sprint 0–5 规划 |

---

**维护责任人**：Scrum Master / Tech Lead  
**反馈渠道**：GitHub Issues 或团队 Slack 频道
