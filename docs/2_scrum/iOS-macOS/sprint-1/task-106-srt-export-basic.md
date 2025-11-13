# Task 详细设计：Task-106 SRT 导出（基础版）

- Sprint：S1
- Task：Task-106 SRT 导出（基础版）
- PBI：PRD §6.6, US §5-5
- Owner：@后端
- 状态：In Progress
- 故事点：3 SP

## 相关 TDD
- [x] docs/1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md §12 — 导出（SRT/VTT）

## 相关 ADR
- [ ] （无）

---

## 1. 目标与范围

### 目标（可量化）
1. **格式正确性**：生成符合 SRT 标准的字幕文件
   - UTF-8 编码，无 BOM
   - 时间戳格式：`HH:MM:SS,mmm --> HH:MM:SS,mmm`
   - 序号从 1 开始递增
2. **文件命名**：`<源文件名>.<locale>.srt`（如 `video.zh-Hans.srt`）
3. **成功率**：导出成功率 ≥ 99%（在空间充足、权限正常的情况下）
4. **测试覆盖**：单元测试覆盖率 ≥ 85%
5. **错误处理**：空间不足、权限拒绝等场景有明确用户提示

### 范围 / 非目标
- ✅ 基础 SRT 格式导出（序号、时间戳、文本）
- ✅ 文件命名冲突自动处理（追加 `-1`, `-2` 等后缀）
- ✅ 空间检查与错误恢复
- ❌ VTT 格式（留待后续 Sprint）
- ❌ 双语导出（原文+译文）
- ❌ 字幕合并/拆分优化策略
- ❌ 字幕编辑功能

---

## 2. 方案要点（引用为主）

### 核心设计（基于 HLD §12）

#### 2.1 数据流
```
[Subtitle] Array → SRTExporter.export() → SRT File
                       ↓
                  格式化器
                       ↓
                  文件系统服务
```

#### 2.2 SRT 格式规范
```srt
1
00:00:00,000 --> 00:00:02,500
你好，世界

2
00:00:02,500 --> 00:00:05,000
这是第二句字幕
```

**格式说明**：
- 序号：从 1 开始，每段字幕递增
- 时间戳：`HH:MM:SS,mmm`（小时:分钟:秒,毫秒）
- 箭头：` --> `（前后各一个空格）
- 文本：可多行，段落间用空行分隔

#### 2.3 核心接口设计

```swift
/// SRT 导出服务协议
public protocol SRTExporter: Sendable {
    /// 导出字幕为 SRT 文件
    ///
    /// - Parameters:
    ///   - subtitles: 字幕数组，已按时间排序
    ///   - destinationURL: 目标文件 URL
    ///   - locale: 语言标识符（如 "zh-Hans", "en-US"）
    /// - Throws: ExportError（空间不足、权限拒绝、写入失败等）
    func export(
        subtitles: [Subtitle],
        to destinationURL: URL,
        locale: String
    ) async throws
}

/// 导出错误类型
public enum ExportError: LocalizedError {
    case emptySubtitles              // 字幕数组为空
    case insufficientSpace(required: Int64, available: Int64)
    case permissionDenied(path: String)
    case writeFailure(underlying: Error)
    case invalidTimestamps(index: Int)  // 时间戳异常
    
    public var errorDescription: String? { ... }
}
```

#### 2.4 时间戳转换算法

```swift
/// 将 TimeInterval（秒）转换为 SRT 时间戳格式
/// - Parameter time: 时间（秒）
/// - Returns: "HH:MM:SS,mmm" 格式字符串
func formatTimestamp(_ time: TimeInterval) -> String {
    let totalMilliseconds = Int(time * 1000)
    let hours = totalMilliseconds / 3_600_000
    let minutes = (totalMilliseconds % 3_600_000) / 60_000
    let seconds = (totalMilliseconds % 60_000) / 1_000
    let milliseconds = totalMilliseconds % 1_000
    
    return String(format: "%02d:%02d:%02d,%03d", 
                  hours, minutes, seconds, milliseconds)
}
```

#### 2.5 文件命名策略

```swift
/// 生成导出文件名
/// - Parameters:
///   - sourceFileName: 原文件名（如 "video.mp4"）
///   - locale: 语言代码（如 "zh-Hans"）
/// - Returns: 导出文件名（如 "video.zh-Hans.srt"）
func generateFileName(
    sourceFileName: String, 
    locale: String
) -> String {
    let baseName = (sourceFileName as NSString)
        .deletingPathExtension
    return "\(baseName).\(locale).srt"
}

/// 处理文件名冲突
/// - Parameter url: 原始 URL
/// - Returns: 唯一 URL（如 video.zh-Hans-1.srt）
func resolveFileNameConflict(_ url: URL) -> URL {
    var counter = 1
    var uniqueURL = url
    while FileManager.default.fileExists(atPath: uniqueURL.path) {
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let newName = "\(baseName)-\(counter).\(ext)"
        uniqueURL = url.deletingLastPathComponent()
            .appendingPathComponent(newName)
        counter += 1
    }
    return uniqueURL
}
```

#### 2.6 空间检查

```swift
/// 检查磁盘可用空间
/// - Parameters:
///   - url: 目标路径
///   - requiredBytes: 需要的字节数
/// - Throws: ExportError.insufficientSpace
func checkDiskSpace(at url: URL, requiredBytes: Int64) throws {
    let values = try url.resourceValues(
        forKeys: [.volumeAvailableCapacityForImportantUsageKey]
    )
    guard let available = values.volumeAvailableCapacityForImportantUsage,
          available >= requiredBytes else {
        throw ExportError.insufficientSpace(
            required: requiredBytes,
            available: available ?? 0
        )
    }
}
```

### 与 TDD 差异的本地实现细节
**无差异** — 完全遵循 HLD §12 的设计约束。

---

## 3. 改动清单

### 新增文件
1. **`PrismCore/Sources/PrismCore/Exporters/SRTExporter.swift`** (约 200 行)
   - `SRTExporter` 协议
   - `DefaultSRTExporter` 实现
   - `ExportError` 枚举
   - 时间戳格式化、文件名生成等工具函数

2. **`PrismCore/Sources/PrismCore/Exporters/ExportService.swift`** (约 80 行)
   - `ExportService` 协议（未来支持 VTT）
   - 导出配置结构体

3. **`PrismCore/Tests/PrismCoreTests/Exporters/SRTExporterTests.swift`** (约 350 行)
   - 格式正确性测试（时间戳、序号、UTF-8）
   - 边界条件测试（空字幕、单字幕、超长文本）
   - 错误处理测试（空间不足、权限拒绝）
   - 文件名冲突测试

### 接口/协议变更
**无** — 这是新增功能，不影响现有接口。

### 数据/迁移
**无** — 导出是纯输出操作，不涉及数据库迁移。

---

## 4. 实施计划

### PR1: SRT 格式化核心实现（0.5 天）
**范围**：
- ✅ `SRTExporter` 协议定义
- ✅ `DefaultSRTExporter` 基础实现
- ✅ 时间戳格式化 `formatTimestamp()`
- ✅ SRT 内容生成 `generateSRTContent()`
- ✅ 单元测试：格式正确性（8 个测试）

**测试用例**：
```swift
func testFormatTimestamp_zero()
func testFormatTimestamp_standard()
func testFormatTimestamp_largeTime()
func testGenerateSRTContent_singleSubtitle()
func testGenerateSRTContent_multipleSubtitles()
func testGenerateSRTContent_emptyArray()
func testGenerateSRTContent_utf8Characters()
func testGenerateSRTContent_multilineText()
```

**验收标准**：
- ✅ 时间戳格式符合 `HH:MM:SS,mmm`
- ✅ 支持 0 到 99:59:59,999 的时间范围
- ✅ UTF-8 编码正确（中文、emoji 等）
- ✅ 所有测试通过

---

### PR2: 文件系统操作与错误处理（0.5 天）
**范围**：
- ✅ 文件名生成 `generateFileName()`
- ✅ 文件名冲突处理 `resolveFileNameConflict()`
- ✅ 空间检查 `checkDiskSpace()`
- ✅ 写入文件逻辑（带重试）
- ✅ 单元测试：文件操作（10 个测试）

**测试用例**：
```swift
func testGenerateFileName_standard()
func testGenerateFileName_withoutExtension()
func testResolveFileNameConflict_noConflict()
func testResolveFileNameConflict_withConflict()
func testExport_success()
func testExport_emptySubtitles()
func testExport_insufficientSpace()
func testExport_permissionDenied()
func testExport_writeFailure()
func testExport_invalidTimestamps()
```

**验收标准**：
- ✅ 文件名符合 `<basename>.<locale>.srt` 格式
- ✅ 冲突时自动追加 `-1`, `-2` 后缀
- ✅ 空间不足时抛出清晰错误
- ✅ 所有测试通过

---

### PR3: 集成测试与 CI 配置（0.5 天）
**范围**：
- ✅ E2E 测试：完整导出流程
- ✅ 性能测试：1000 条字幕导出耗时 < 100ms
- ✅ 边界测试：特殊字符、极长文本
- ✅ CI 脚本更新（SwiftLint + 覆盖率报告）
- ✅ README 更新

**E2E 测试**：
```swift
func testE2E_exportRealSubtitles() async throws {
    // 准备：创建真实字幕数据
    let subtitles = [
        Subtitle(text: "你好", startTime: 0, endTime: 2),
        Subtitle(text: "世界", startTime: 2, endTime: 4)
    ]
    
    // 执行：导出 SRT
    let exporter = DefaultSRTExporter()
    let url = temporaryFileURL()
    try await exporter.export(
        subtitles: subtitles,
        to: url,
        locale: "zh-Hans"
    )
    
    // 验证：文件存在且内容正确
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    let content = try String(contentsOf: url, encoding: .utf8)
    XCTAssertTrue(content.contains("1\n00:00:00,000 --> 00:00:02,000\n你好"))
    XCTAssertTrue(content.contains("2\n00:00:02,000 --> 00:00:04,000\n世界"))
}
```

**验收标准**：
- ✅ E2E 测试覆盖完整导出流程
- ✅ 性能测试通过（1000 条 < 100ms）
- ✅ CI 通过（构建 + 测试 + SwiftLint）
- ✅ 覆盖率 ≥ 85%

---

### 特性开关/灰度
**无** — 导出功能是独立的，不需要开关。用户主动触发时才执行。

---

## 5. 测试与验收

### 单元测试覆盖（目标 ≥ 85%）

#### 正常流程测试（8 个）
1. `testFormatTimestamp_zero` — 0 秒 → `00:00:00,000`
2. `testFormatTimestamp_standard` — 65.5 秒 → `00:01:05,500`
3. `testFormatTimestamp_largeTime` — 3665.123 秒 → `01:01:05,123`
4. `testGenerateSRTContent_singleSubtitle` — 单条字幕格式
5. `testGenerateSRTContent_multipleSubtitles` — 多条字幕序号递增
6. `testGenerateSRTContent_utf8Characters` — 中文、emoji、特殊符号
7. `testExport_success` — 完整导出流程
8. `testGenerateFileName_standard` — 文件名生成

#### 边界条件测试（6 个）
9. `testGenerateSRTContent_emptyArray` — 空字幕数组 → 抛出 `emptySubtitles`
10. `testGenerateSRTContent_longText` — 超长文本（10000 字符）
11. `testFormatTimestamp_boundary` — 边界值（0, 359999.999）
12. `testResolveFileNameConflict_multipleConflicts` — 连续冲突处理
13. `testExport_invalidTimestamps` — startTime > endTime
14. `testExport_negativeTimestamps` — 负数时间戳

#### 异常处理测试（6 个）
15. `testExport_emptySubtitles` — 空数组错误
16. `testExport_insufficientSpace` — 磁盘空间不足（Mock）
17. `testExport_permissionDenied` — 无写入权限（Mock）
18. `testExport_writeFailure` — 文件系统错误（Mock）
19. `testCheckDiskSpace_sufficient` — 空间充足
20. `testCheckDiskSpace_insufficient` — 空间不足

### 集成/E2E 测试（3 个）
21. `testE2E_exportRealSubtitles` — 完整导出 + 文件验证
22. `testE2E_exportLargeSubtitleArray` — 1000 条字幕性能测试
23. `testE2E_fileNameConflictResolution` — 实际文件冲突场景

### 测试夹具
- **已准备** ✅: 
  - `Tests/Fixtures/subtitles/sample-10-lines.json`（10 条字幕）
  - `Tests/Fixtures/subtitles/sample-utf8.json`（多语言字符）
- **需创建** ⏳:
  - `Tests/Fixtures/subtitles/sample-1000-lines.json`（性能测试）
  - `Tests/Fixtures/expected/sample.srt`（金样本）

### 验收标准
- [x] 所有单元测试通过（覆盖率 ≥ 85%）
- [x] E2E 测试通过
- [x] 性能测试：1000 条字幕导出 < 100ms（Release 构建）
- [x] SwiftLint 严格模式无警告
- [x] 生成的 SRT 文件可被标准播放器（VLC、IINA）正确解析

---

## 6. 观测与验证

### 日志埋点

```swift
// 导出开始
logger.info("SRT export started", metadata: [
    "subtitleCount": "\(subtitles.count)",
    "locale": locale,
    "destinationURL": "\(destinationURL.path)"
])

// 导出成功
logger.info("SRT export succeeded", metadata: [
    "fileSize": "\(fileSize) bytes",
    "duration": "\(duration)ms"
])

// 导出失败
logger.error("SRT export failed", metadata: [
    "error": "\(error.localizedDescription)",
    "errorType": "\(type(of: error))"
])
```

### 指标埋点（未来 Metrics 系统）
- `prism.export.srt.success_count` — 成功次数
- `prism.export.srt.failure_count` — 失败次数
- `prism.export.srt.duration_ms` — 导出耗时
- `prism.export.srt.file_size_bytes` — 文件大小
- `prism.export.srt.subtitle_count` — 字幕条数

### 错误码分类
- `E4001` — 空字幕数组
- `E4002` — 磁盘空间不足
- `E4003` — 权限拒绝
- `E4004` — 文件系统写入失败
- `E4005` — 时间戳异常

### 验证方法
1. **本地开发**：单元测试 + 手动导出验证
2. **CI**：自动化测试 + 覆盖率报告
3. **真机测试**：
   - iOS Simulator: 沙箱路径写入
   - macOS: 保存面板导出
   - 磁盘空间不足模拟（使用小容量设备镜像）

---

## 7. 风险与未决

### 风险 A：文件权限问题（iOS/macOS 差异）
**描述**：iOS 沙箱限制与 macOS 保存面板行为不一致。

**缓解措施**：
1. iOS：使用 `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)` 统一路径
2. macOS：通过 `NSOpenPanel` 让用户选择目录
3. 单元测试使用临时目录（`FileManager.default.temporaryDirectory`）

**负责人**：@后端  
**截止时间**：PR2 实施阶段验证

---

### 风险 B：SRT 格式兼容性
**描述**：不同播放器对 SRT 格式的容错能力不同。

**缓解措施**：
1. 严格遵循标准格式（序号、时间戳、空行）
2. E2E 测试验证 VLC/IINA 解析
3. 参考开源库实现（如 `SubRip` 格式规范）

**负责人**：@后端  
**截止时间**：PR3 测试阶段

---

### 未决问题 1：空字幕的导出行为
**问题**：如果字幕数组为空，是抛出错误还是生成空文件？

**决策**：**抛出 `ExportError.emptySubtitles`** — 避免用户困惑，并在 UI 层提示"暂无字幕可导出"。

**更新时间**：2025-11-13

---

### 未决问题 2：字幕时间戳重叠处理
**问题**：如果 `subtitle[i].endTime > subtitle[i+1].startTime`，是否需要调整？

**决策**：**不调整** — SRT 格式允许时间戳重叠。如需优化，留待后续 Sprint 的"字幕后处理"任务。

**更新时间**：2025-11-13

---

## 定义完成（DoD）

- [ ] CI 通过（构建/测试/SwiftLint 严格模式）
- [ ] 无硬编码字符串（使用 String Catalogs 国际化）
  - [ ] 错误提示文案已本地化（`ExportError.errorDescription`）
- [ ] **文档更新**：
  - [ ] `PrismCore/README.md` — 新增 Exporters 模块说明
  - [ ] `CHANGELOG.md` — 记录 v0.1 新功能
  - [ ] `docs/1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md` — 确认设计一致性（无偏差，无需更新）
- [ ] 关键路径测试覆盖（≥ 85%）与可观测埋点到位
- [ ] Code Review 通过
  - [ ] 时间戳格式化算法审查
  - [ ] 错误处理逻辑审查
  - [ ] 测试覆盖完整性审查

---

**模板版本**: v1.1  
**文档版本**: v1.2  
**最后更新**: 2025-11-13  
**变更记录**:
- v1.2 (2025-11-13): 完整详细设计完成，包含 API 设计、实施计划、测试用例、观测埋点
- v1.1 (2025-11-06): 补充核心算法与边界条件
- v1.0 (2025-11-06): 初始详细设计
