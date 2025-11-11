# Task 详细设计：Task-105 字幕渲染（基础样式）与时间同步

- Sprint：S1
- Task：Task-105 字幕渲染（基础样式）与时间同步
- PBI：PRD §6.4/§6.5
- Owner：@前端
- 状态：Todo

## 相关 TDD
- [x] docs/tdd/iOS-macOS/hld-ios-macos-v0.2.md — 参见 §3 渲染与时间同步

## 相关 ADR
- [ ] （无直接 ADR；遵循 UI/可访问性通用约束）

## 1. 目标与范围
- 目标：以 PlayerService 时间为唯一时钟；基础样式；P95 同步偏差 ≤ 200ms；SwiftUI 实时更新不卡顿。
- 非目标：高级样式/卡拉OK特效/多轨道；后续迭代。

## 2. 方案要点（引用为主）
- 单一真值时钟：PlayerService 进度回调→ViewModel→SubtitleView。
- 去抖与批量更新（≤16ms 帧间隔），避免每字符重绘。

## 3. 改动清单
- PrismKit/Sources/Views/SubtitleView.swift
- PrismPlayer/Sources/Views/
- PrismCore/Sources/ViewModels/SubtitleViewModel.swift

## 4. 实施计划
- PR1：ViewModel 与时间对齐算法（0.5d）
- PR2：基础样式与无障碍支持（0.5d）
- PR3：偏差采样与日志（0.5d）
- PR4：集成测试与性能基线（0.5d）

## 5. 测试与验收
- 单测：时间对齐、空/加载/错误状态、长文本换行。
- E2E：播放→显示→更新；断言 P95 ≤ 200ms。
- 验收：任务清单 6 项验收标准全部通过。

## 6. 观测与验证
- 记录显示时间与播放器时间差值分布；OSLog 指标。

## 7. 风险与未决
- SwiftUI 重绘开销；通过最小化 State 变化与分层渲染降低。

## 定义完成（DoD）
- [ ] CI 通过 / 覆盖率达标
- [ ] 国际化文本，无硬编码
- [ ] 文档更新
- [ ] 性能与可观测到位
- [ ] Code Review 通过

---

模板版本：v1.1  
文档版本：v1.0  
最后更新：2025-11-06  
变更记录：
- v1.0 (2025-11-06): 初始详细设计
