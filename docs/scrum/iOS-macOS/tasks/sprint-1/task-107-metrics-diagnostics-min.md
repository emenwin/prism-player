# Task 详细设计：Task-107 指标与诊断（最小化）

- Sprint：S1
- Task：Task-107 指标与诊断（最小化）
- PBI：PRD §KPI, §6.2/§6.4 派生指标
- Owner：@架构
- 状态：Todo

## 相关 TDD
- [x] docs/tdd/iOS-macOS/hld-ios-macos-v0.2.md — 参见 §13 可观测性

## 相关 ADR
- [ ] docs/adr/iOS-macOS/0004-logging-metrics-strategy.md （若存在）— 本地日志与采样策略

## 1. 目标与范围
- 目标：记录首帧时间、段识别耗时样本、RTF 分布、时间同步偏差 P95；本地日志存储与读取。
- 非目标：线上埋点与可视化平台。

## 2. 方案要点（引用为主）
- OSLog 分类：performance.asr, performance.first_frame, sync.offset。
- 采样：固定窗口与事件触发结合；本地 JSON 环形缓冲。

## 3. 改动清单
- PrismCore/Sources/Diagnostics/MetricsLogger.swift
- PrismCore/Tests/Diagnostics/

## 4. 实施计划
- PR1：日志分类与写入（0.5d）
- PR2：采样聚合与导出（0.5d）
- PR3：验证与基线报告脚本（0.5d）

## 5. 测试与验收
- 单测：统计正确性与边界（空/异常）。
- 验收：任务清单 4 项验收标准全部通过。

## 6. 观测与验证
- 本地日志审计；脚本汇总 P50/P95；随 E2E 运行输出摘要。

## 7. 风险与未决
- 日志体积控制；通过限速与环形缓冲解决。

## 定义完成（DoD）
- [ ] CI 通过 / 覆盖率达标
- [ ] 文档更新
- [ ] Code Review 通过

---

模板版本：v1.1  
文档版本：v1.0  
最后更新：2025-11-06  
变更记录：
- v1.0 (2025-11-06): 初始详细设计
