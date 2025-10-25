# Task-010: ADR 目录与模板

## 任务信息

- **Sprint**: Sprint 0
- **估算**: 1 SP
- **优先级**: P3
- **依赖**: 无
- **负责人**: 待分配
- **状态**: 进行中

## 任务目标

建立 Architecture Decision Records (ADR) 目录结构和模板，记录项目中的关键技术决策，确保决策过程透明、可追溯。

## 验收标准（AC）

1. ✅ ADR 目录结构已创建
2. ✅ ADR 模板已提供
3. ✅ README 说明 ADR 使用规范
4. ✅ 首批 ADR 已创建（SQLite 方案、DI 方案）

## 实施步骤

### Step 1: 创建 ADR 目录结构

```
docs/adr/
├── README.md           # ADR 使用指南
├── template.md         # ADR 模板
├── 0001-*.md          # 第一个 ADR
├── 0002-*.md          # 第二个 ADR
└── ...
```

### Step 2: 创建 ADR 模板

基于 Michael Nygard 的 ADR 模板，包含：
- 标题
- 状态（Proposed/Accepted/Deprecated/Superseded）
- 上下文
- 决策
- 结果
- 替代方案

### Step 3: 编写 ADR 使用指南

在 README.md 中说明：
- ADR 是什么
- 何时创建 ADR
- ADR 编号规则
- ADR 状态转换

### Step 4: 创建首批 ADR

1. **0001-sqlite-storage-solution.md**
   - SQLite vs CoreData vs GRDB
   - 选择 SQLite + 原生 Swift 封装

2. **0002-dependency-injection-strategy.md**
   - 协议式 DI vs 依赖注入框架
   - 选择轻量级协议式 DI

## 技术要点

### ADR 编号规则

- 4位数字递增：0001, 0002, 0003...
- 文件名格式：`NNNN-kebab-case-title.md`
- 按时间顺序排列，不修改历史 ADR

### ADR 状态

- **Proposed**: 提议中，待讨论
- **Accepted**: 已接受，正在实施
- **Deprecated**: 已废弃，但保留记录
- **Superseded by XXX**: 被新 ADR 取代

### ADR 最佳实践

- 简洁明了，聚焦决策本身
- 记录上下文和约束
- 列出考虑过的替代方案
- 说明决策的后果和权衡

## 交付物

- [x] `docs/adr/README.md` - ADR 使用指南
- [x] `docs/adr/template.md` - ADR 模板
- [x] `docs/adr/0001-sqlite-storage-solution.md` - SQLite 方案 ADR
- [ ] `docs/adr/0002-dependency-injection-strategy.md` - DI 策略 ADR（可选）

## 参考资料

- [ADR GitHub Organization](https://adr.github.io/)
- [Michael Nygard's ADR Template](https://github.com/joelparkerhenderson/architecture-decision-record)
- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

## 完成标准

- ✅ ADR 目录结构已建立
- ✅ 模板和指南已完善
- ✅ 首个 ADR（SQLite）已创建
- ✅ 符合行业最佳实践

---

**任务状态**: 进行中  
**创建日期**: 2025-10-24  
**最后更新**: 2025-10-24
