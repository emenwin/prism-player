# 数据存储架构

本文档说明 Prism Player 的数据持久化架构和使用方法。

## 概述

项目使用 **SQLite + GRDB** 作为本地存储方案，提供高性能、类型安全的数据访问层。

- **技术栈**: SQLite 3 + [GRDB.swift](https://github.com/groue/GRDB.swift)
- **架构**: Repository 模式 + Actor 并发
- **决策文档**: [ADR-0003: SQLite 存储方案](../../../../docs/adr/0003-sqlite-storage-solution.md)

## 目录结构

```
Storage/
├── DatabaseManager.swift            # 数据库管理器
├── Migrations/                       # Schema 迁移
│   └── Migration_001_Initial.swift
├── Models/                           # 数据模型
│   ├── AsrSegment.swift              # 字幕片段
│   ├── MediaRecord.swift             # 媒体文件记录
│   └── ModelMetadata.swift           # 模型元数据
└── Repositories/                     # 数据访问层
    ├── MediaRepository.swift
    ├── SubtitleRepository.swift
    └── ModelRepository.swift (待实现)
```

## 数据模型

### 1. MediaRecord（媒体文件）

存储已导入媒体文件的元数据和识别进度。

```swift
struct MediaRecord {
    let id: String
    let filePath: String
    let duration: TimeInterval
    var recognitionProgress: Double  // 0.0 - 1.0
    var modelId: String?
    var language: String?
}
```

### 2. AsrSegment（字幕片段）

存储 ASR 识别的字幕片段，支持高效时间范围查询。

```swift
struct AsrSegment {
    let id: UUID
    let mediaId: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let confidence: Double?
}
```

**索引**: `(media_id, start_time, end_time)` 复合索引

### 3. ModelMetadata（模型元数据）

管理 ASR 模型的下载状态和文件路径。

```swift
struct ModelMetadata {
    let id: String
    let name: String
    let size: Int64
    let backend: AsrBackend  // whisper-cpp, mlx-swift
    var downloadStatus: DownloadStatus
    var filePath: String?
}
```

## 使用示例

### 初始化

```swift
// 单例模式，自动初始化
let db = DatabaseManager.shared

// 或用于测试的内存数据库
let testDb = try DatabaseManager.inMemory()
```

### 媒体记录操作

```swift
let repository = MediaRepository()

// 保存媒体
let media = MediaRecord(
    filePath: "/path/to/video.mp4",
    duration: 120.0
)
try await repository.save(media)

// 查询
let found = try await repository.find(id: media.id)

// 更新进度
try await repository.updateProgress(id: media.id, progress: 0.5)

// 删除（级联删除关联字幕）
try await repository.delete(id: media.id)
```

### 字幕操作

```swift
let repository = SubtitleRepository()

// 批量保存
let segments = [
    AsrSegment(mediaId: "media-id", startTime: 0, endTime: 5, text: "Hello"),
    AsrSegment(mediaId: "media-id", startTime: 5, endTime: 10, text: "World")
]
try await repository.saveBatch(segments)

// 时间范围查询（高效）
let subtitles = try await repository.findInTimeRange(
    mediaId: "media-id",
    startTime: 4.0,
    endTime: 11.0
)

// 查询所有
let all = try await repository.findAll(mediaId: "media-id")

// 计数
let count = try await repository.count(mediaId: "media-id")
```

## Schema 迁移

### 迁移管理

迁移由 `DatabaseMigrator` 自动管理，按顺序执行：

```swift
var migrator = DatabaseMigrator()
migrator.registerMigration("v1_initial") { db in
    // 创建表
}
migrator.registerMigration("v2_add_translation") { db in
    // 添加翻译字段
}
try migrator.migrate(dbQueue)
```

### 添加新迁移

1. 创建 `Migration_XXX_Description.swift`
2. 实现 `migrate(_ db: Database)` 方法
3. 在 `DatabaseManager` 中注册

```swift
migrator.registerMigration("v2_add_translation") { db in
    try Migration_002_AddTranslation.migrate(db)
}
```

## 并发安全

### Actor 封装

所有 Repository 使用 `actor` 封装，保证并发安全：

```swift
public actor MediaRepository {
    // 自动串行化访问
}
```

### WAL 模式

数据库启用 WAL（Write-Ahead Logging）模式：
- 支持并发读写
- 读操作不阻塞写操作
- 提升性能

## 性能优化

### 索引策略

- **时间范围查询**: `(media_id, start_time, end_time)` 复合索引
- **文件路径查询**: `file_path` 单列索引
- **模型状态查询**: `download_status` 单列索引

### 批量操作

```swift
// 批量插入使用事务
try await db.writeAsync { db in
    for segment in segments {
        try segment.insert(db)
    }
}
```

### 查询优化

```swift
// 限制结果数量
try MediaRecord
    .order(MediaRecord.Columns.updatedAt.desc)
    .limit(10)
    .fetchAll(db)
```

## 文件系统布局

```
Application Support/com.prismplayer.{platform}/
├── Database/
│   ├── prism.db                 # 主数据库
│   ├── prism.db-shm             # WAL 共享内存
│   └── prism.db-wal             # WAL 日志
├── Models/                       # ASR 模型
│   ├── whisper-base.gguf
│   └── whisper-small.gguf
├── AudioCache/                   # 音频缓存
└── Exports/                      # 导出文件
```

### 路径管理

```swift
// 获取标准路径
let dbPath = AppPaths.mainDatabase
let modelsDir = AppPaths.models
let cacheDir = AppPaths.audioCache

// 确保目录存在
try AppPaths.ensureDirectoriesExist()

// 清理缓存
try AppPaths.clearAudioCache()
```

## 测试

### 单元测试

使用内存数据库进行测试：

```swift
class DatabaseTests: XCTestCase {
    var db: DatabaseManager!
    
    override func setUp() async throws {
        db = try DatabaseManager.inMemory()
    }
    
    func testCRUD() async throws {
        let repo = MediaRepository(db: db)
        // 测试逻辑...
    }
}
```

### 测试覆盖

- ✅ CRUD 操作
- ✅ 时间范围查询
- ✅ 级联删除
- ✅ 并发安全
- ✅ 迁移流程

## 故障排查

### 数据库锁定

**问题**: `database is locked` 错误

**解决**:
1. 确保使用 WAL 模式
2. 避免长时间持有事务
3. 使用 Actor 封装避免竞态

### 迁移失败

**问题**: 迁移无法回滚

**解决**:
1. 每次迁移幂等设计
2. 测试环境先验证
3. 备份数据库

### 性能问题

**问题**: 查询慢

**解决**:
1. 检查索引是否生效（`EXPLAIN QUERY PLAN`）
2. 限制结果数量
3. 使用分页

## 未来扩展

- [ ] 实现 ModelRepository
- [ ] 添加数据库备份功能
- [ ] 实现数据导入/导出
- [ ] 添加全文搜索（FTS5）
- [ ] 优化大数据集性能

## 参考资料

- [GRDB.swift 文档](https://github.com/groue/GRDB.swift)
- [SQLite 官方文档](https://www.sqlite.org/docs.html)
- [ADR-0003: SQLite 存储方案](../../../../docs/adr/0003-sqlite-storage-solution.md)

---

**文档版本**: v1.0  
**最后更新**: 2025-10-24
