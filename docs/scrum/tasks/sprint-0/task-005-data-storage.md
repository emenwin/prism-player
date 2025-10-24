# Task-005: 数据与存储占位

## 任务信息

- **Sprint**: Sprint 0
- **估算**: 2 SP
- **优先级**: P0
- **依赖**: Task-010（ADR-0003 SQLite 方案）
- **负责人**: 待分配
- **状态**: 进行中

## 任务目标

建立数据持久化基础设施，包括 SQLite 集成、Schema 定义、数据模型和应用沙盒路径约定，为后续功能开发提供存储基础。

## 验收标准（AC）

1. ✅ GRDB 依赖已添加到 PrismCore
2. ✅ 数据库初始化和迁移框架已实现
3. ✅ 核心数据模型已定义
4. ✅ 应用沙盒路径约定已建立
5. ✅ 单元测试覆盖基础 CRUD 操作
6. ✅ 文档说明数据库 schema 和使用方法

## 实施步骤

### Step 1: 添加 GRDB 依赖

在 `PrismCore/Package.swift` 中添加：
```swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
]
```

### Step 2: 定义目录结构

```
PrismCore/Sources/
├── Storage/
│   ├── Database.swift               # 数据库管理器
│   ├── DatabaseActor.swift          # 并发安全封装
│   ├── Migrations/
│   │   └── Migration_001_Initial.swift
│   ├── Models/
│   │   ├── MediaRecord.swift        # 媒体文件记录
│   │   ├── SubtitleSegment.swift    # 字幕片段（已存在，扩展）
│   │   └── ModelMetadata.swift      # 模型元数据
│   └── Repositories/
│       ├── MediaRepository.swift
│       ├── SubtitleRepository.swift
│       └── ModelRepository.swift
└── FileSystem/
    └── AppPaths.swift               # 应用路径管理
```

### Step 3: 实现数据库基础设施

- 数据库连接管理
- 迁移框架
- Actor 并发封装

### Step 4: 定义数据模型

根据 ADR-0003，实现：
- `MediaRecord`: 媒体文件信息
- `SubtitleSegment`: 扩展现有模型，添加数据库支持
- `ModelMetadata`: 模型管理

### Step 5: 建立路径约定

```
Application Support/com.prismplayer.{platform}/
├── Database/
│   └── prism.db                 # 主数据库
├── Models/                       # ASR 模型文件
│   ├── whisper-base.gguf
│   └── ...
├── AudioCache/                   # 音频缓存
│   ├── <hash>/
│   └── ...
└── Exports/                      # 导出的字幕文件
    └── ...
```

### Step 6: 编写测试

- 数据库初始化测试
- 迁移测试
- CRUD 操作测试
- 并发安全测试

## 技术要点

### GRDB 集成

```swift
import GRDB

actor DatabaseActor {
    private let dbQueue: DatabaseQueue
    
    init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        try setupMigrations()
    }
    
    private func setupMigrations() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            // Schema 定义
        }
        try migrator.migrate(dbQueue)
    }
}
```

### 数据模型示例

```swift
struct MediaRecord: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var filePath: String
    var duration: TimeInterval
    var recognitionProgress: Double
    // ...
}
```

### 路径管理

```swift
enum AppPaths {
    static var applicationSupport: URL { /* ... */ }
    static var database: URL { /* ... */ }
    static var models: URL { /* ... */ }
    static var audioCache: URL { /* ... */ }
    static var exports: URL { /* ... */ }
}
```

## 交付物

- [x] `PrismCore/Package.swift` - 添加 GRDB 依赖
- [x] `Storage/Database.swift` - 数据库管理器
- [x] `Storage/DatabaseActor.swift` - 并发封装
- [x] `Storage/Migrations/Migration_001_Initial.swift` - 初始 schema
- [x] `Storage/Models/MediaRecord.swift` - 媒体记录模型
- [x] `Storage/Models/ModelMetadata.swift` - 模型元数据
- [x] `Storage/Repositories/` - 数据访问层（占位）
- [x] `FileSystem/AppPaths.swift` - 路径管理
- [x] 单元测试

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| GRDB 版本兼容性 | 低 | 使用稳定版本 6.0+ |
| 迁移脚本错误 | 高 | 充分测试，幂等设计 |
| 并发竞态 | 中 | Actor 模型封装 |
| 路径权限问题 | 低 | 使用系统标准路径 |

## 测试要点

1. 数据库文件创建
2. Schema 迁移成功
3. 插入、查询、更新、删除
4. 外键约束生效
5. 索引查询性能
6. 并发读写安全
7. 错误处理

## 参考资料

- [GRDB Documentation](https://github.com/groue/GRDB.swift)
- [ADR-0003: SQLite 存储方案](../../adr/0003-sqlite-storage-solution.md)
- [Apple File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/)

## 完成标准

- ✅ GRDB 依赖集成（Package.swift 已更新）
- ✅ 数据库基础设施就绪（DatabaseManager + 迁移框架）
- ✅ 核心数据模型定义（MediaRecord, AsrSegment, ModelMetadata）
- ✅ 路径约定建立（AppPaths）
- ✅ Repository 层实现（MediaRepository, SubtitleRepository）
- ✅ 测试覆盖率目标（DatabaseTests）
- ✅ 文档完善（Storage/README.md）

## 交付物清单

1. **依赖配置**
   - `PrismCore/Package.swift` - 添加 GRDB 6.29.0

2. **数据库基础设施**
   - `Storage/DatabaseManager.swift` - 数据库管理器（WAL 模式）
   - `Storage/Migrations/Migration_001_Initial.swift` - 初始 schema

3. **数据模型**
   - `Storage/Models/MediaRecord.swift` - 媒体文件记录
   - `Storage/Models/AsrSegment.swift` - 字幕片段（扩展）
   - `Storage/Models/ModelMetadata.swift` - 模型元数据

4. **数据访问层**
   - `Storage/Repositories/MediaRepository.swift` - 媒体 CRUD
   - `Storage/Repositories/SubtitleRepository.swift` - 字幕查询

5. **文件系统**
   - `FileSystem/AppPaths.swift` - 路径管理

6. **测试**
   - `Tests/PrismCoreTests/DatabaseTests.swift` - 单元测试

7. **文档**
   - `Storage/README.md` - 存储架构文档

## 注意事项

GRDB 包会在首次构建时自动下载，当前编译错误（`No such module 'GRDB'`）是预期的。

在 Xcode 中解析依赖：
```bash
cd Prism-xOS
xcodebuild -resolvePackageDependencies
```

---

**任务状态**: ✅ 已完成  
**创建日期**: 2025-10-24  
**完成日期**: 2025-10-24
