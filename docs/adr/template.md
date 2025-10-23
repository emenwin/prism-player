# ADR-XXXX: [简短标题]

## 状态
- **提议中** / **已接受** / **已废弃** / **已替代**
- 日期：YYYY-MM-DD
- 决策者：[@username1, @username2]
- 相关文档：[PRD §X.X, HLD §Y.Y, Sprint Plan Sprint N]

## 背景与问题陈述
<!-- 描述需要做出决策的技术或业务场景 -->
我们需要为 Prism Player 选择依赖注入（DI）方案，以支持：
- 协议驱动的测试（Mock AsrEngine、PlayerService）
- 多平台共享代码（iOS/macOS）
- 最小化样板代码，保持 Swift 原生风格

## 决策驱动因素
<!-- 影响决策的关键因素 -->
- **测试性**：必须支持 Mock/Stub 注入
- **学习曲线**：团队熟悉 Swift 协议与泛型
- **性能**：避免运行时反射开销
- **依赖**：优先原生方案，避免引入重量级框架

## 考虑的方案

### 方案 1：协议式 DI（Protocol-based DI）
```swift
// 协议定义依赖
protocol AsrEngine {
    func transcribe(...) async throws -> [Segment]
}

// 初始化器注入
class TranscriptionService {
    private let asrEngine: AsrEngine
    init(asrEngine: AsrEngine) {
        self.asrEngine = asrEngine
    }
}

// 测试时注入 Mock
class MockAsrEngine: AsrEngine { ... }
let service = TranscriptionService(asrEngine: MockAsrEngine())
```

**优点**：
- ✅ 原生 Swift，零依赖
- ✅ 编译期类型安全
- ✅ 测试友好，Mock 清晰
- ✅ 性能无损

**缺点**：
- ⚠️ 深层依赖树需手动传递
- ⚠️ 缺乏全局容器管理

---

### 方案 2：轻量级容器（Lightweight Container）
```swift
// 简单服务定位器
class ServiceContainer {
    static let shared = ServiceContainer()
    private var services: [String: Any] = [:]
    
    func register<T>(_ type: T.Type, instance: T) {
        services[String(describing: type)] = instance
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        guard let service = services[String(describing: type)] as? T else {
            fatalError("Service not registered: \(type)")
        }
        return service
    }
}
```

**优点**：
- ✅ 集中管理依赖
- ✅ 减少手动传递

**缺点**：
- ⚠️ 运行时错误风险
- ⚠️ 类型安全弱化
- ⚠️ 测试时需重置容器

---

### 方案 3：第三方框架（Swinject/Needle）
**优点**：
- ✅ 功能完善（作用域、自动注入）

**缺点**：
- ❌ 学习成本高
- ❌ 引入外部依赖
- ❌ 过度设计（对当前项目）

## 决策结果
**选择方案 1：协议式 DI**

### 理由
1. 符合 Swift 最佳实践与团队技能栈
2. 测试覆盖率目标（Core≥70%）需要清晰 Mock 策略
3. 项目规模可控，依赖树深度≤3 层
4. 避免引入外部依赖（符合 DoR）

### 实施细节
- 核心协议定义在 `PrismCore`（AsrEngine、PlayerService、StorageService）
- Mock 实现统一放置 `Tests/Mocks/`
- ViewModel 通过初始化器注入服务
- SwiftUI Preview 使用 Mock 服务

### 示例代码
```swift
// filepath: packages/PrismCore/Sources/AsrEngine.swift
public protocol AsrEngine {
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment]
}

// filepath: packages/PrismASR/Sources/WhisperCppBackend.swift
public final class WhisperCppBackend: AsrEngine {
    public func transcribe(...) async throws -> [AsrSegment] {
        // whisper.cpp 实现
    }
}

// filepath: Tests/Mocks/MockAsrEngine.swift
final class MockAsrEngine: AsrEngine {
    var transcribeResult: [AsrSegment] = []
    func transcribe(...) async throws -> [AsrSegment] {
        return transcribeResult
    }
}
```

## 后果

### 正面影响
- 单元测试清晰可控
- 编译期捕获依赖错误
- 代码可读性高

### 负面影响
- ViewModel 初始化需显式传参（可通过工厂方法缓解）
- 深层依赖树需手动传递（当前项目深度≤3 可接受）

### 缓解措施
- 提供 `Dependencies` 命名空间聚合常用依赖
```swift
struct Dependencies {
    let asrEngine: AsrEngine
    let playerService: PlayerService
    let storage: StorageService
}
```

## 遵从性
- 所有新增服务必须定义协议
- 禁止直接实例化具体类型（除 SwiftUI View）
- CI 检查：Mock 覆盖率≥70%（Core/Kit 层）

## 相关决策
- 替代：无
- 延续：ADR-0004（状态机设计也采用协议抽象）
- 冲突：无

## 备注
- Sprint 0 完成基础示例（Mock AsrEngine + PlayerService）
- Sprint 1 全面应用于核心服务

## 参考资料
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Testing Swift: Protocol-Oriented Mocking](https://www.swiftbysundell.com/articles/protocol-oriented-programming-in-swift/)
- Michael Nygard, "Documenting Architecture Decisions" (2011)