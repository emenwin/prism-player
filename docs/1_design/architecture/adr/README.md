# 架构决策记录（ADR）目录

本目录用于存放架构决策记录（Architecture Decision Record，ADR）。ADR 用于记录影响系统整体或长期演进的重要技术取舍，便于团队在时间维度上保持一致性与可追溯性。

## 何时撰写 ADR
- 技术/框架选型或弃用（例如：ASR 引擎、数据库、日志与指标栈）
- 跨团队/跨版本的接口契约与数据模型变更
- 安全、隐私、合规与观测标准
- 架构分层、边界与演进策略

以下情况通常不需要新增 ADR（写在 TDD 或 Task 文档即可）：
- 局部实现细节、参数调优、单个任务内的执行策略

## 文件命名与状态
- 命名：`NNNN-kebab-title.md`（四位递增编号 + 中划线标题）
- 状态枚举：`Proposed` | `Accepted` | `Deprecated` | `Superseded`（被编号 X 取代）
- 典型字段：Title、Status、Deciders、Date、Context、Decision、Consequences、Alternatives、References

## 目录结构建议
```
adr/
 ├─ template.md                      # ADR 模板
 ├─ 0001-multiplatform-architecture.md
 ├─ 0002-player-view-ui-stack.md
 ├─ 0003-sqlite-storage-solution.md
 └─ <platform>/                      # 可选：平台特定 ADR
    └─ README.md
```

> 你可以直接复制 `template.md` 新建一条 ADR，并按上述命名规则保存。

## 工作流
1. Proposed：提出 ADR 草案并创建讨论（Issue/PR）。
2. Review：相关角色评审、记录备选方案与权衡。
3. Accepted：达成一致后合并；需要时启动 Spike/PoC 验证。
4. Deprecated/Superseded：当决策不再适用或被新 ADR 替代时，更新状态并在两文档间建立链接。

## 与 TDD/Task 的关系
- TDD（技术设计文档）引用 ADR，简述受影响的约束与影响面，不嵌入 ADR 正文。
- Task 文档仅落地本任务的执行方案与测试，链接相关 ADR/TDD 即可。

## 模板
- ADR 模板参见：`../template/adr.template.md`

如需创建新 ADR：
1) 复制 `template.md`；2) 更新元信息与标题；3) 提交 PR 并邀请评审；4) 在相关 TDD/Task/PR 中添加链接。