# Prism Player Android 任务管理说明

> 最后更新：2025-10-25

## 概述

本文档说明如何使用 `tasks/` 目录管理 Sprint 任务，包括任务拆分、跟踪、状态更新等操作指南。

---

## 目录结构

```text
docs/scrum/Android/tasks/
├── README.md                      # 本文件：任务管理说明
├── sprint-0/                      # Sprint 0 任务详情
│   ├── task-001-project-init.md
│   ├── task-002-quality-tools.md
│   └── ...
├── sprint-1/                      # Sprint 1 任务详情
│   ├── task-101-media-playback.md
│   ├── task-102-audio-extraction.md
│   └── ...
└── sprint-summary.md              # 各 Sprint 完成情况总结（待补充）
```

---

## 任务命名规范

### 文件命名
```
task-<sprint_id><task_number>-<short_description>.md
```

**示例**：
- `task-001-project-init.md`（Sprint 0 第 1 个任务：项目初始化）
- `task-101-media-playback.md`（Sprint 1 第 1 个任务：媒体播放）
- `task-402-translation-scheduler.md`（Sprint 4 第 2 个任务：翻译调度器）

### 任务 ID 规则
- **Sprint 0**：`001–099`
- **Sprint 1**：`101–199`
- **Sprint 2**：`201–299`
- **Sprint 3**：`301–399`
- **Sprint 4**：`401–499`
- **Sprint 5**：`501–599`

---

## 任务模板

每个任务文件应包含以下内容：

```markdown
# Task [ID]: [任务标题]

> Sprint: [Sprint 编号]  
> 优先级: [P0/P1/P2]  
> 估算: [Story Points]  
> 负责人: [姓名/GitHub ID]  
> 状态: [To Do / In Progress / In Review / Done]

## 背景

[为什么需要这个任务，关联的用户故事或技术需求]

## 目标

[这个任务完成后要达成的目标]

## 任务清单

- [ ] 子任务 1
- [ ] 子任务 2
- [ ] 子任务 3

## 验收标准（AC）

- [ ] 验收标准 1
- [ ] 验收标准 2

## 技术要点

[关键技术细节、架构决策、API 设计等]

## 依赖

- 依赖任务：[Task ID]
- 外部依赖：[库、工具等]

## 风险

- [潜在风险与缓解策略]

## 参考文档

- [相关文档链接]

## 更新日志

| 日期 | 更新内容 | 更新人 |
|------|---------|--------|
| 2025-10-25 | 任务创建 | XXX |
```

---

## 任务状态流转

### 状态定义
| 状态 | 含义 | 触发条件 |
|------|------|---------|
| **To Do** | 待开始 | 任务进入 Sprint Backlog |
| **In Progress** | 进行中 | 开发者开始工作 |
| **In Review** | 代码审查中 | PR 提交并等待 Review |
| **Done** | 已完成 | 通过 Review 且满足 DoD |

### 流转规则
```
To Do → In Progress → In Review → Done
         ↑              ↓
         └─── Blocked ───┘
```

- **Blocked**：遇到阻塞时更新状态并在 Daily Scrum 中提出

---

## 任务拆分原则

### 大小控制
- 单个任务估算 ≤5 SP
- 超过 5 SP 的任务需进一步拆分为子任务
- 每个子任务应可在 1–3 天内完成

### 拆分示例
**原任务**：集成 Whisper.cpp NDK（8 SP）

**拆分后**：
1. Task 201：编译 Whisper.cpp 为 Android NDK 库（3 SP）
2. Task 202：实现 JNI 绑定与 AsrEngine 接口（3 SP）
3. Task 203：单元测试与性能验证（2 SP）

### 依赖关系
- 明确标注任务间的依赖（如 Task 202 依赖 Task 201）
- 使用工具（如 GitHub Projects）可视化依赖图

---

## 估算方法

### Planning Poker
- 团队成员独立估算，讨论差异，达成共识
- 使用斐波那契数列（1, 2, 3, 5, 8）

### 参考基准（Baseline）
- **1 SP**：添加一个简单的 Compose UI 组件
- **2 SP**：实现一个 UseCase 接口
- **3 SP**：设计并实现一个 Room Entity + DAO
- **5 SP**：集成一个新的第三方库（如 Hilt）
- **8 SP**：实现一个完整的功能模块（需拆分）

---

## 跟踪工具

### 推荐工具
1. **GitHub Projects**（轻量级）
   - 创建项目看板
   - 列：To Do / In Progress / In Review / Done
   - 关联 Issue 与 PR

2. **Jira**（重量级）
   - Epic → Story → Sub-task 层级
   - Scrum Board + Burndown Chart
   - 与 GitHub 集成

3. **Linear**（现代化）
   - 快速操作，键盘友好
   - 自动状态同步

### 日常更新
- **Daily Scrum** 前更新任务状态
- **PR 合并** 后标记任务为 Done
- **遇到阻塞** 立即更新并通知团队

---

## 报告与总结

### Sprint 总结模板
每个 Sprint 结束后创建 `sprint-<N>-summary.md`：

```markdown
# Sprint [N] 总结

> 时间：[开始日期] – [结束日期]  
> Sprint Goal：[目标]

## 完成情况

- **承诺 SP**：38
- **完成 SP**：35
- **完成率**：92%

## 已完成任务

- [x] Task 101: 媒体播放（5 SP）
- [x] Task 102: 音频提取（5 SP）
- ...

## 未完成任务

- [ ] Task 105: 性能优化（3 SP）→ 推迟至 Sprint 2

## KPI 验证

| 指标 | 目标 | 实际 | 状态 |
|------|------|------|------|
| 首帧时间 | ≤5s | 4.2s | ✅ |
| RTF | ≥1.0 | 1.2 | ✅ |

## 问题与改进

- **问题 1**：NDK 集成比预期复杂 → 增加 Spike 时间
- **改进 1**：Code Review 流程优化（引入 PR 模板）

## Retrospective 输出

### 做得好的
- 团队协作顺畅
- CI/CD 自动化节省时间

### 需要改进
- 估算偏乐观，下个 Sprint 保守估算
- 单元测试覆盖率不足，需加强

### 行动项
- [ ] 安排 Hilt 技术分享会
- [ ] 更新 DoD 清单（增加测试覆盖率要求）
```

---

## 常见问题（FAQ）

### Q1：任务估算过高怎么办？
拆分为更小的子任务，每个子任务 ≤3 SP。

### Q2：任务被阻塞如何处理？
1. 标记状态为 Blocked
2. 在 Daily Scrum 中提出
3. Scrum Master 协助移除阻塞

### Q3：任务中途需要调整估算？
允许调整，但需在 Sprint Planning 或 Daily Scrum 中说明原因。

### Q4：如何处理紧急 Bug？
作为 P0 任务插入 Sprint Backlog，调整其他任务优先级。

---

## 最佳实践

### 任务创建
- ✅ 标题简洁明了（≤10 个词）
- ✅ 验收标准清晰可验证
- ✅ 关联 PRD 用户故事或 HLD 章节
- ❌ 避免模糊描述（如"优化性能"）

### 任务执行
- ✅ 每日更新状态
- ✅ 代码提交关联任务 ID（如 `[Task-201] Implement Whisper.cpp JNI`）
- ✅ PR 描述中引用任务（如 `Closes #201`）
- ❌ 避免长期停留在 In Progress 状态

### Code Review
- ✅ 使用 PR 模板（检查 DoD）
- ✅ 至少 1 人 Approve 后合并
- ✅ Review 时验证验收标准
- ❌ 避免过大的 PR（>500 行建议拆分）

---

## 相关文档

- [Sprint Plan v0.2](../sprint-plan-v0.2.md)
- [Definition of Done (DoD)](../sprint-plan-v0.2.md#10-definition-of-done-dod)
- [Scrum 工作流](../../scrum.md)

---

**维护责任人**：Scrum Master  
**反馈渠道**：GitHub Issues 或团队会议
