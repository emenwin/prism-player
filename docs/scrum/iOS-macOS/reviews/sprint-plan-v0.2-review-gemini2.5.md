# Sprint 计划 v0.2 评审纪要

> 日期：2025-10-17
> 评审目标：`docs/scrum/sprint-plan-v0.2.md`
> 评审依据：
> - `docs/requirements/prd_v0.2.md` (产品需求)
> - `docs/tdd/hld-ios-macos-v0.2.md` (高阶设计)
> - `docs/tdd/hld-ios-macos-v0.2-discussion-list.md` (HLD 评审待办项)

---

## 1. 总体评价

Sprint 计划（v0.2）与 PRD 和 HLD 的对齐度很高，里程碑（M1/M2/M3）划分清晰，PBI（Product Backlog Item）粒度适中。该计划成功地将产品目标分解为可执行的、循序渐进的 Sprint 任务，并正确映射了用户故事和技术组件。

**亮点**:
- **分阶段交付**: M1（原型）、M2（可用版）、M3（优化版）的划分策略合理，确保了价值的快速交付与持续迭代。
- **DoD 明确**: 完成定义（DoD）中包含了 SwiftLint、String Catalog 等具体质量门槛，与 HLD 要求一致。
- **风险意识**: 每个 Sprint 都识别了关键风险并提出了初步的回退策略。

**核心建议**:
计划应更明确地将 `hld-ios-macos-v0.2-discussion-list.md` 中的**高优先级待办项**（如 VAD 方案、状态机、DI 策略）安排进具体的 Sprint 中，以确保架构的关键决策和重构任务不会被遗漏。

---

## 2. 各 Sprint 详细评审

### Sprint 0 (工程基线)

- **评价**: **优秀**。此 Sprint 覆盖了项目启动所需的所有基础建设，为后续开发提供了坚实保障。PBI 列表全面，与 HLD §13 的工程组织规划完全匹配。
- **建议**: 无重大修改建议。可以考虑将 `swift-format` 的评估与集成直接确定下来，而不是作为“可选”，以统一代码风格。

### Sprint 1 (M1 原型)

- **评价**: **良好**。目标明确，聚焦于打通端到端的最小可用链路，是正确的垂直切片策略。PBI 与 PRD/HLD 的核心功能（播放、预加载、ASR、渲染、导出）对齐。
- **潜在问题与建议**:
    1.  **[建议] 明确架构决策任务**: HLD 评审提出了几个高优先级的架构决策点，应在 M1 中明确。建议在 PBI 中增加一个 Spike 或 Tech Debt 任务：
        - **PBI 新增**: “Spike: 确定依赖注入（DI）策略与核心状态机（PlayerViewModel）的初步设计，为后续测试与并发处理奠定基础。” (来源: `hld-ios-macos-v0.2-discussion-list.md`)
    2.  **[澄清] ASR 模型来源**: PBI 描述为“加载本地超轻量模型（内置 Demo 或本地导入）”。建议明确 M1 阶段是**必须支持本地文件导入**，还是仅**内置一个 Demo 模型**即可。前者涉及文件选择器和模型移动逻辑，工作量稍大。

### Sprint 2 (M2 可用版)

- **评价**: **良好**。在 M1 基础上扩展了核心体验，如滚动识别、模型管理和 macOS 支持，路径清晰。
- **潜在问题与建议**:
    1.  **[建议] 明确 VAD 方案**: HLD 评审将“VAD + 对齐方案”列为高优先级。如果 M2 要支持 MLX 后端或不带时间戳的模型，则此任务**必须在 M2 完成**。
        - **PBI 新增**: “Feature: 实现 VAD（语音活动检测）与基础对齐模块，用于支持无原生时间戳的 ASR 模型。” (来源: `hld-ios-macos-v0.2-discussion-list.md`)
    2.  **[建议] 细化 macOS 支持**: “macOS 目标跑通”描述较为笼统。建议拆分为更具体的 PBI：
        - “PBI-macOS-1: 实现 `NSOpenPanel` 文件选择与安全范围书签。”
        - “PBI-macOS-2: 适配 `NSProcessInfo.beginActivity` 防止 App Nap。”
        - “PBI-macOS-3: 适配窗口管理与菜单栏行为。”

### Sprint 3 (M3 优化版)

- **评价**: **良好**。聚焦于性能、高级功能（抢占识别）和稳定性，符合产品迭代优化的规律。
- **潜在问题与建议**:
    1.  **[建议] 明确性能基准**: HLD 评审强调了“性能基准测试与回归框架”。M3 的性能优化工作应基于此框架。
        - **PBI 新增**: “Tech Debt: 建立性能基准测试套件（RTF, 内存, 能耗），用于量化 M3 的优化效果。” (来源: `hld-ios-macos-v0.2-discussion-list.md`)
    2.  **[建议] 包含诊断功能**: PRD 和 HLD 均提及“诊断包”功能。M3 作为优化和稳定 Sprint，是落地此功能的最佳时机。
        - **PBI 新增**: “Feature: 实现诊断包导出功能，包含脱敏的配置、日志与性能指标。” (来源: `hld-ios-macos-v0.2-discussion-list.md`)

---

## 3. 总结与后续步骤

此 Sprint 计划是一个非常好的起点。为了使其更臻完善，建议项目经理（或 Scrum Master）采纳以上建议，将明确的架构决策和技术债偿还任务正式纳入 Backlog，并分配到相应的 Sprint 中。

**下一步**:
1.  召开 Sprint Planning 会议，讨论本评审纪要。
2.  将采纳的建议转化为具体的 PBI，并估算工作量。
3.  更新 `sprint-plan-v0.2.md` 文件，反映最终的规划。