# ADR-0005: 测试架构与依赖注入策略

## 状态

✅ **已接受**（Accepted）

**日期**: 2025-10-24  
**决策者**: Prism Player 开发团队  
**相关任务**: Task-009（Sprint 0）

---

## 上下文与问题陈述

Prism Player 是一个中等规模的音视频播放器应用，包含复杂的业务逻辑：
- ASR 语音识别（多后端支持）
- 实时字幕渲染与同步
- 后台任务调度
- 数据持久化

为了确保代码质量和可维护性，我们需要：
1. **高可测试性**: 核心业务逻辑需要单元测试覆盖率 ≥70%
2. **依赖解耦**: 便于 Mock 外部依赖（ASR 引擎、播放器、存储）
3. **易于维护**: 测试代码清晰，易于扩展
4. **CI 友好**: 测试快速、稳定、可重复

关键问题：
- **如何组织依赖注入**？（协议式 DI vs 容器 vs 框架）
- **如何管理 Mock/Stub**？（命名、目录结构、复用）
- **如何收集覆盖率**？（工具选择、CI 集成）

---

## 决策驱动因素

### 业务需求

1. **TDD 开发模式**: Sprint 1+ 需要先写测试再实现功能
2. **关键路径覆盖**: 首帧字幕、RTF 计算、时间同步等核心逻辑必须有测试
3. **多后端支持**: ASR 引擎（whisper.cpp/MLX）需要抽象层便于切换和测试

### 技术约束

1. **SwiftUI 架构**: 需要兼容 `@StateObject`/`@EnvironmentObject`
2. **Actor 并发**: 指标采集、任务调度使用 Actor，测试需要处理 async/await
3. **无第三方依赖**: 优先使用原生方案，避免增加依赖
4. **多平台**: iOS + macOS，测试需要兼容两个平台

### 团队考量

1. **学习曲线**: 团队熟悉 Swift Protocol，希望方案简单直观
2. **维护成本**: 避免过度设计，保持代码简洁
3. **扩展性**: 后续可能增加新模块（翻译引擎、导出器等）

---

## 考虑的方案

### 方案 A: 协议式 DI（Protocol-based Dependency Injection）

**描述**: 使用 Swift Protocol 定义抽象接口，通过构造函数注入依赖。

**示例**:

```swift
// 1. 定义协议
protocol AsrEngine {
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment]
}

// 2. 实现具体类型
final class WhisperCppEngine: AsrEngine {
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment] {
        // 实现细节
    }
}

// 3. 依赖注入
class AsrService {
    private let engine: AsrEngine
    
    init(engine: AsrEngine) {
        self.engine = engine
    }
    
    func process(_ audio: Data) async throws -> [AsrSegment] {
        return try await engine.transcribe(audioData: audio, options: .default)
    }
}

// 4. 测试时注入 Mock
class MockAsrEngine: AsrEngine {
    var transcribeResult: [AsrSegment] = []
    
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment] {
        return transcribeResult
    }
}

// 测试用例
let mockEngine = MockAsrEngine()
let service = AsrService(engine: mockEngine)
```

**优点**:
- ✅ 简单直观，符合 Swift 惯用法
- ✅ 无第三方依赖，零学习成本
- ✅ 编译时类型安全
- ✅ SwiftUI 兼容性好（可用 `@StateObject` 包装）
- ✅ 测试简单（直接注入 Mock）

**缺点**:
- ⚠️ 需要手动管理依赖关系（构造函数可能参数较多）
- ⚠️ 缺少生命周期管理（需手动实现单例/工厂）
- ⚠️ 深层依赖链需要层层传递

**适用场景**: 中小型项目，依赖关系相对简单

---

### 方案 B: 轻量级服务容器（Lightweight Service Container）

**描述**: 实现一个简单的服务定位器，管理依赖的注册和解析。

**示例**:

```swift
// 1. 定义容器
actor ServiceContainer {
    static let shared = ServiceContainer()
    
    private var services: [String: Any] = [:]
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        services[key] = factory
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        guard let factory = services[key] as? () -> T else {
            fatalError("Service \(type) not registered")
        }
        return factory()
    }
}

// 2. 注册服务
await ServiceContainer.shared.register(AsrEngine.self) {
    WhisperCppEngine()
}

// 3. 解析服务
class AsrService {
    private let engine: AsrEngine
    
    init() {
        self.engine = await ServiceContainer.shared.resolve(AsrEngine.self)
    }
}

// 4. 测试时替换
await ServiceContainer.shared.register(AsrEngine.self) {
    MockAsrEngine()
}
```

**优点**:
- ✅ 集中管理依赖关系
- ✅ 支持懒加载和作用域
- ✅ 避免深层依赖传递
- ✅ 易于切换实现（测试/生产）

**缺点**:
- ⚠️ 运行时解析，失去编译时安全性
- ⚠️ 测试隔离需要注意（全局状态）
- ⚠️ 增加代码复杂度（需维护容器）
- ⚠️ 难以追踪依赖关系（IDE 无法直接跳转）

**适用场景**: 中大型项目，依赖关系复杂

---

### 方案 C: 第三方 DI 框架（Swinject/Needle/Factory）

**描述**: 使用成熟的依赖注入框架。

**示例（Swinject）**:

```swift
import Swinject

let container = Container()

// 注册
container.register(AsrEngine.self) { _ in WhisperCppEngine() }
container.register(AsrService.self) { r in
    AsrService(engine: r.resolve(AsrEngine.self)!)
}

// 解析
let service = container.resolve(AsrService.self)!
```

**优点**:
- ✅ 功能强大（生命周期、作用域、循环依赖检测）
- ✅ 成熟稳定，有社区支持
- ✅ 减少重复代码

**缺点**:
- ❌ 增加第三方依赖（违反项目原则）
- ❌ 学习曲线陡峭
- ❌ 过度设计（对中等规模项目）
- ❌ 可能与 Swift 新特性冲突（Actor/Concurrency）

**适用场景**: 大型项目，复杂依赖关系，团队已熟悉框架

---

## 决策结果

**选择方案 A: 协议式 DI（Protocol-based Dependency Injection）**

### 理由

1. **简单性优先**
   - 项目规模适中（~3 个 Sprint，20-40k LOC 预估）
   - 依赖关系相对清晰（ASR 引擎、播放器、存储、指标）
   - 团队熟悉 Swift Protocol，零学习成本

2. **符合 Swift 惯用法**
   - 利用 Protocol 和泛型实现抽象
   - 编译时类型安全
   - IDE 支持好（代码跳转、自动补全）

3. **测试友好**
   - 直接注入 Mock，无需容器配置
   - 测试隔离天然（每个测试用例独立构造对象）
   - 易于追踪依赖关系

4. **无额外依赖**
   - 符合项目"优先原生方案"原则
   - 减少维护成本和版本冲突风险

5. **SwiftUI 兼容性好**
   - 可用 `@StateObject` 包装服务
   - 可用 `@EnvironmentObject` 在视图树中传递
   - 与 Combine/Async-Await 无缝集成

### 权衡

**接受的限制**:
- 深层依赖需要层层传递 → 通过合理的架构分层缓解
- 缺少生命周期管理 → 手动实现单例/工厂模式（简单场景足够）
- 构造函数可能参数较多 → 使用工厂方法或 Builder 模式

**缓解措施**:
- 使用协议扩展提供默认实现（减少样板代码）
- 对常用依赖提供静态工厂方法（如 `AsrEngine.production`/`AsrEngine.mock`）
- 在 ViewModel 中使用 `@EnvironmentObject` 注入依赖

---

## 实施策略

### 1. 核心协议定义

为关键组件定义协议：

```swift
// ASR 引擎协议
protocol AsrEngine: Actor {
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment]
    func cancel() async
}

// 播放器服务协议
protocol PlayerService: AnyObject {
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    func play() async
    func pause() async
    func seek(to time: TimeInterval) async
}

// 存储协议
protocol AsrSegmentStore: Actor {
    func save(_ segments: [AsrSegment], for mediaId: String) async throws
    func fetch(for mediaId: String) async throws -> [AsrSegment]
    func delete(for mediaId: String) async throws
}

// 指标采集协议（已在 Task-007 定义）
protocol MetricsCollector: Actor {
    func recordTiming(_ name: String, duration: TimeInterval) async
    func recordDistribution(_ name: String, value: Double) async
}
```

### 2. Mock/Stub 命名约定

**命名规则**:
- `MockXxx`: 可验证交互（记录调用次数、参数）
- `StubXxx`: 预设响应（返回固定值）
- `FakeXxx`: 简化实现（如内存数据库）
- `SpyXxx`: 记录行为（用于验证调用顺序）

**示例**:

```swift
// Mock: 验证交互
class MockAsrEngine: AsrEngine {
    var transcribeCalled = false
    var transcribeCallCount = 0
    var lastAudioData: Data?
    
    var transcribeResult: [AsrSegment] = []
    
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment] {
        transcribeCalled = true
        transcribeCallCount += 1
        lastAudioData = audioData
        return transcribeResult
    }
    
    func cancel() async {}
}

// Stub: 简单预设
class StubAsrEngine: AsrEngine {
    var segments: [AsrSegment] = []
    
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment] {
        return segments
    }
    
    func cancel() async {}
}
```

### 3. 测试目录结构

```
Prism-xOS/
├── packages/
│   ├── PrismCore/
│   │   ├── Sources/PrismCore/
│   │   │   ├── ASR/
│   │   │   │   ├── AsrEngine.swift          # 协议定义
│   │   │   │   └── WhisperCppEngine.swift   # 实现
│   │   │   ├── Player/
│   │   │   │   ├── PlayerService.swift
│   │   │   │   └── AVPlayerService.swift
│   │   │   └── Storage/
│   │   │       ├── AsrSegmentStore.swift
│   │   │       └── SQLiteAsrSegmentStore.swift
│   │   └── Tests/PrismCoreTests/
│   │       ├── Mocks/
│   │       │   ├── MockAsrEngine.swift
│   │       │   ├── MockPlayerService.swift
│   │       │   └── MockAsrSegmentStore.swift
│   │       ├── Fixtures/
│   │       │   ├── TestData.swift           # 测试数据常量
│   │       │   └── audio/                   # 测试音频文件
│   │       └── ASR/
│   │           ├── WhisperCppEngineTests.swift
│   │           └── AsrServiceTests.swift
│   ├── PrismASR/
│   │   └── Tests/PrismASRTests/
│   └── PrismKit/
│       └── Tests/PrismKitTests/
└── Tests/
    ├── Mocks/                               # 跨包共享 Mock
    │   └── README.md
    └── Fixtures/                            # 跨包共享测试数据
        └── README.md
```

### 4. 工厂方法模式

为生产和测试环境提供便捷的工厂方法：

```swift
extension AsrEngine {
    /// 生产环境默认引擎
    static func production(modelPath: String) -> AsrEngine {
        WhisperCppEngine(modelPath: modelPath)
    }
    
    /// 测试环境 Mock 引擎
    static func mock(segments: [AsrSegment] = []) -> AsrEngine {
        let mock = MockAsrEngine()
        mock.transcribeResult = segments
        return mock
    }
}

// 使用
let engine = AsrEngine.production(modelPath: "/path/to/model.bin")
let testEngine = AsrEngine.mock(segments: testSegments)
```

### 5. SwiftUI 集成

在 ViewModel 中使用协议式 DI：

```swift
@MainActor
class SubtitleViewModel: ObservableObject {
    @Published var segments: [AsrSegment] = []
    
    private let asrEngine: AsrEngine
    private let playerService: PlayerService
    private let metricsCollector: MetricsCollector
    
    init(
        asrEngine: AsrEngine,
        playerService: PlayerService,
        metricsCollector: MetricsCollector = SharedMetricsCollector.shared
    ) {
        self.asrEngine = asrEngine
        self.playerService = playerService
        self.metricsCollector = metricsCollector
    }
    
    func transcribe(audioData: Data) async {
        let startTime = Date()
        
        do {
            let segments = try await asrEngine.transcribe(
                audioData: audioData,
                options: .default
            )
            self.segments = segments
            
            let duration = Date().timeIntervalSince(startTime)
            await metricsCollector.recordTiming("asr.transcribe", duration: duration)
        } catch {
            // 错误处理
        }
    }
}

// SwiftUI 视图
struct SubtitleView: View {
    @StateObject private var viewModel: SubtitleViewModel
    
    init(asrEngine: AsrEngine, playerService: PlayerService) {
        _viewModel = StateObject(wrappedValue: SubtitleViewModel(
            asrEngine: asrEngine,
            playerService: playerService
        ))
    }
    
    var body: some View {
        // UI 实现
    }
}

// 测试
@MainActor
final class SubtitleViewModelTests: XCTestCase {
    func testTranscribe() async {
        // Given
        let mockEngine = MockAsrEngine()
        mockEngine.transcribeResult = [
            AsrSegment(startTime: 0, endTime: 1, text: "Hello")
        ]
        let mockPlayer = MockPlayerService()
        let viewModel = SubtitleViewModel(
            asrEngine: mockEngine,
            playerService: mockPlayer
        )
        
        // When
        await viewModel.transcribe(audioData: testAudioData)
        
        // Then
        XCTAssertEqual(viewModel.segments.count, 1)
        XCTAssertTrue(mockEngine.transcribeCalled)
    }
}
```

---

## 测试覆盖率策略

### 覆盖率目标

根据 Sprint Plan 要求：
- **Core/Kit 层**: ≥70%（业务逻辑、数据处理）
- **ViewModel 层**: ≥60%（UI 逻辑）
- **关键路径**: ≥80%（首帧、RTF、时间同步、导出）

### 工具配置

**选择 Xcode 内置覆盖率 + slather**:

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Tests with Coverage
        run: |
          xcodebuild test \
            -workspace Prism-xOS/PrismPlayer.xcworkspace \
            -scheme PrismCore \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -enableCodeCoverage YES \
            -resultBundlePath TestResults.xcresult
      
      - name: Generate Coverage Report
        run: |
          xcrun xccov view --report --json TestResults.xcresult > coverage.json
          
      - name: Check Coverage Threshold
        run: |
          # 提取总覆盖率并验证 ≥70%
          python scripts/check_coverage.py coverage.json 70
```

### 覆盖率报告

在 PR 中展示覆盖率变化（可选集成 Codecov）。

---

## 示例实现

### MockAsrEngine

```swift
/// Mock ASR 引擎用于单元测试
///
/// 特性:
/// - 记录所有方法调用
/// - 可配置返回值和错误
/// - 支持验证调用次数和参数
actor MockAsrEngine: AsrEngine {
    // MARK: - Call Recording
    
    private(set) var transcribeCalled = false
    private(set) var transcribeCallCount = 0
    private(set) var cancelCalled = false
    
    private(set) var lastAudioData: Data?
    private(set) var lastOptions: AsrOptions?
    
    // MARK: - Configuration
    
    var transcribeResult: Result<[AsrSegment], AsrError> = .success([])
    var transcribeDelay: TimeInterval = 0
    
    // MARK: - AsrEngine
    
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment] {
        transcribeCalled = true
        transcribeCallCount += 1
        lastAudioData = audioData
        lastOptions = options
        
        if transcribeDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(transcribeDelay * 1_000_000_000))
        }
        
        switch transcribeResult {
        case .success(let segments):
            return segments
        case .failure(let error):
            throw error
        }
    }
    
    func cancel() async {
        cancelCalled = true
    }
    
    // MARK: - Reset
    
    func reset() {
        transcribeCalled = false
        transcribeCallCount = 0
        cancelCalled = false
        lastAudioData = nil
        lastOptions = nil
    }
}
```

### 测试用例示例

```swift
final class AsrServiceTests: XCTestCase {
    var sut: AsrService!
    var mockEngine: MockAsrEngine!
    var mockMetrics: MockMetricsCollector!
    
    override func setUp() async throws {
        mockEngine = MockAsrEngine()
        mockMetrics = MockMetricsCollector()
        sut = AsrService(
            engine: mockEngine,
            metricsCollector: mockMetrics
        )
    }
    
    override func tearDown() {
        sut = nil
        mockEngine = nil
        mockMetrics = nil
    }
    
    // MARK: - Success Cases
    
    func testTranscribe_Success_ReturnsSegments() async throws {
        // Given
        let testAudio = Data([0x00, 0x01, 0x02, 0x03])
        let expectedSegments = [
            AsrSegment(startTime: 0, endTime: 1, text: "Hello"),
            AsrSegment(startTime: 1, endTime: 2, text: "World")
        ]
        await mockEngine.setTranscribeResult(.success(expectedSegments))
        
        // When
        let result = try await sut.transcribe(audioData: testAudio)
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].text, "Hello")
        XCTAssertEqual(result[1].text, "World")
        
        let called = await mockEngine.transcribeCalled
        XCTAssertTrue(called)
    }
    
    func testTranscribe_RecordsMetrics() async throws {
        // Given
        let testAudio = Data([0x00])
        await mockEngine.setTranscribeResult(.success([]))
        
        // When
        _ = try await sut.transcribe(audioData: testAudio)
        
        // Then
        let timingCalled = await mockMetrics.recordTimingCalled
        XCTAssertTrue(timingCalled)
        
        let lastMetricName = await mockMetrics.lastTimingName
        XCTAssertEqual(lastMetricName, "asr.transcribe")
    }
    
    // MARK: - Error Cases
    
    func testTranscribe_EngineError_ThrowsError() async {
        // Given
        let testAudio = Data([0x00])
        await mockEngine.setTranscribeResult(.failure(.modelLoadFailed))
        
        // When/Then
        do {
            _ = try await sut.transcribe(audioData: testAudio)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AsrError)
        }
    }
    
    // MARK: - Performance
    
    func testTranscribe_Performance() async throws {
        // Given
        let testAudio = Data(count: 1024)
        await mockEngine.setTranscribeResult(.success([]))
        
        // When
        measure {
            let expectation = expectation(description: "transcribe")
            Task {
                _ = try await sut.transcribe(audioData: testAudio)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
}
```

---

## 后续演进路径

### 短期（Sprint 1-2）

- ✅ 为所有核心协议创建 Mock 实现
- ✅ 建立测试 Fixtures（音频样本、字幕样本）
- ✅ 达成覆盖率目标（Core ≥70%）

### 中期（Sprint 3+）

- 🔄 评估是否需要轻量级容器（如依赖关系变复杂）
- 🔄 引入集成测试框架（XCUITest）
- 🔄 性能测试基线（XCTMetrics）

### 长期（维护阶段）

- 🔮 持续监控覆盖率趋势
- 🔮 优化 Mock 复用性
- 🔮 可选引入快照测试（SwiftUI 视图）

---

## 相关文档

- [Task-009: 测试架构与 DI 策略定义](../../scrum/tasks/sprint-0/task-009-testing-di.md)
- [Sprint Plan v0.2](../../scrum/sprint-plan-v0.2-updated.md) - 覆盖率目标定义
- [HLD iOS/macOS v0.2](../../tdd/hld-ios-macos-v0.2.md) - 架构设计

## 参考资料

- [Protocol-Oriented Programming in Swift (WWDC 2015)](https://developer.apple.com/videos/play/wwdc2015/408/)
- [Testing Tips & Tricks (WWDC 2018)](https://developer.apple.com/videos/play/wwdc2018/417/)
- [Swift by Sundell: Dependency Injection](https://www.swiftbysundell.com/articles/dependency-injection-using-factories-in-swift/)
- [Point-Free: Protocol Witnesses](https://www.pointfree.co/episodes/ep33-protocol-witnesses-part-1)

---

**维护者**: Prism Player Team  
**版本**: 1.0  
**最后更新**: 2025-10-24
