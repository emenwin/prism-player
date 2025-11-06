# Task 详细设计：Task-104 播放器与识别状态机设计与实现

- Sprint：S1
- Task：Task-104 播放器与识别状态机设计与实现
- PBI：PRD §6.4/§6.5（状态与同步）
- Owner：@架构
- 状态：Todo

## 相关 TDD
- [x] docs/tdd/iOS-macOS/hld-ios-macos-v0.2.md — 参见 §2.2 状态机与协作约束

## 相关 ADR
- [ ] docs/adr/iOS-macOS/0003-dual-asr-backend-strategy.md — 识别后端差异影响并发与取消策略

## 1. 目标与范围
- 目标（量化）：实现 idle/loading/playing/paused/recognizing/error 状态机；快速 seek 冲突可控，100 次连续 seek 无死锁/崩溃；状态转移用例覆盖率 ≥ 90%。
- 范围/非目标：本任务不实现 UI 细节与样式；仅提供 Actor 封装与事件处理、取消机制及测试。

## 2. 方案要点（引用为主）
- 遵循 HLD §2.2 的状态与事件定义；以 Actor 作为并发边界；通过 seekId（UUID）实现幂等取消。
- 与 TDD 差异：无。

## 3. 改动清单
- PrismCore/Sources/StateMachine/PlayerRecognitionState.swift
- PrismCore/Sources/Coordinators/PlaybackCoordinator.swift
- PrismCore/Tests/StateMachine/
- 接口：StateMachine.send(event:) async，StateObserver（AsyncSequence）

## 4. 实施计划
- PR1：状态与事件枚举、Actor 框架、观察者接口（0.5d）
- PR2：seek 冲突处理与取消令牌（1d）
- PR3：与 PlayerService/AsrEngine 集成桩（0.5d）
- PR4：状态转移测试（全路径覆盖）（1d）

## 5. 测试与验收
- 单测：所有状态转移、边界（快速 seek、并发识别触发取消、错误恢复）。
- 覆盖率：核心逻辑 ≥ 80%。
- E2E：简化旅程（选择媒体→播放→seek→字幕识别触发→取消）。
- 验收：任务清单中 6 项验收标准全部通过。

## 6. 观测与验证
- OSLog：state_enter/state_exit、event、seekId、latency_ms。
- 指标：快速 seek 冲突率、取消延迟 P95。

## 7. 风险与未决
- 竞争条件与取消时序复杂；以单线程 Actor + 明确顺序保证，必要时引入队列序号。

## 定义完成（DoD）
- [ ] CI 通过（构建/测试/SwiftLint 严格）
- [ ] 无硬编码字符串
- [ ] 文档更新（README/HLD 偏差如有）
- [ ] 可观测埋点到位
- [ ] Code Review 通过

---

模板版本：v1.1  
文档版本：v1.0  
最后更新：2025-11-06  
变更记录：
- v1.0 (2025-11-06): 初始详细设计
