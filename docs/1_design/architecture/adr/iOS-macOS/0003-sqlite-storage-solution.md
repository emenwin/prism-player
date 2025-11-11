# ADR-0003: SQLite 存储方案选择

## 状态

**Accepted** - 2025-10-24

## 上下文

Prism Player 需要本地持久化存储来管理：

1. **ASR 识别结果**
   - 字幕片段（时间戳、文本、置信度）
   - 支持增量写入和查询
   - 需要高效的时间范围查询

2. **媒体元数据**
   - 文件路径、时长、识别进度
   - 模型配置、语言设置
   - 最近播放历史

3. **模型管理**
   - 模型元数据（名称、大小、版本、后端类型）
   - 下载进度、校验状态
   - 模型文件路径映射

4. **应用配置**
   - 用户设置（预加载时长、默认语言等）
   - 缓存策略配置
   - 性能指标记录

### 关键需求

- **性能**: 支持快速时间范围查询（O(log n)）
- **并发**: 支持多线程读写（播放器读取 + 后台识别写入）
- **迁移**: 支持数据库 schema 版本管理
- **轻量**: 最小化依赖，避免引入大型 ORM
- **跨平台**: iOS + macOS 共享代码
- **离线**: 完全本地，无需网络

### 约束条件

- 项目初期，优先快速迭代
- 团队熟悉 Swift 和 SQL
- 需要细粒度控制查询性能
- 避免过度工程化

## 决策

**选择 SQLite + 原生 Swift 封装**，具体方案：

1. **核心技术栈**
   - SQLite 3（系统自带）
   - Swift 原生 GRDB 库（轻量级 SQLite 封装）
   - 异步 Actor 模型封装数据访问层

2. **架构设计**
   ```
   PrismCore/Sources/Storage/
   ├── Database.swift           # 数据库连接管理
   ├── Migrations/              # Schema 迁移脚本
   │   ├── Migration_001.swift  # 初始 schema
   │   └── Migration_002.swift  # 增量迁移
   ├── Models/                  # 数据模型
   │   ├── MediaRecord.swift
   │   ├── SubtitleSegment.swift
   │   └── ModelMetadata.swift
   └── Repositories/            # 数据访问层
       ├── MediaRepository.swift
       ├── SubtitleRepository.swift
       └── ModelRepository.swift
   ```

3. **关键特性**
   - **迁移管理**: 使用 GRDB 的 `DatabaseMigrator`
   - **并发控制**: 通过 Swift Actor 封装，避免竞态
   - **事务支持**: 批量写入使用事务保证原子性
   - **索引优化**: 在 `startTime`/`endTime` 上创建索引

4. **初始 Schema**（v1）
   ```sql
   -- 媒体文件表
   CREATE TABLE media_files (
       id TEXT PRIMARY KEY,
       file_path TEXT NOT NULL,
       duration REAL NOT NULL,
       recognition_progress REAL DEFAULT 0.0,
       model_id TEXT,
       language TEXT,
       created_at INTEGER NOT NULL,
       updated_at INTEGER NOT NULL
   );
   
   -- 字幕片段表
   CREATE TABLE subtitle_segments (
       id TEXT PRIMARY KEY,
       media_id TEXT NOT NULL,
       start_time REAL NOT NULL,
       end_time REAL NOT NULL,
       text TEXT NOT NULL,
       confidence REAL,
       created_at INTEGER NOT NULL,
       FOREIGN KEY (media_id) REFERENCES media_files(id) ON DELETE CASCADE
   );
   CREATE INDEX idx_segments_time ON subtitle_segments(media_id, start_time, end_time);
   
   -- 模型元数据表
   CREATE TABLE model_metadata (
       id TEXT PRIMARY KEY,
       name TEXT NOT NULL,
       size INTEGER NOT NULL,
       backend TEXT NOT NULL,  -- 'whisper-cpp' or 'mlx-swift'
       version TEXT,
       file_path TEXT,
       download_status TEXT,   -- 'pending', 'downloading', 'completed'
       sha256 TEXT,
       created_at INTEGER NOT NULL
   );
   ```

## 结果

### 优点

1. **性能优异**
   - SQLite 在移动设备上久经考验
   - 索引查询速度 <10ms（10万条记录）
   - 无需网络，启动速度快

2. **开发效率高**
   - GRDB 提供类型安全的 Swift API
   - 迁移管理自动化
   - 减少样板代码

3. **可维护性强**
   - SQL 可读性好，团队熟悉
   - Schema 版本控制清晰
   - 易于 Debug（可用 SQLite 客户端查看）

4. **轻量级**
   - GRDB 库体积 ~500KB
   - 无额外运行时依赖
   - 系统自带 SQLite

5. **并发安全**
   - GRDB 内置连接池
   - Actor 模型避免数据竞争
   - WAL 模式支持读写并发

### 缺点与缓解

1. **手动 SQL 维护**
   - 缺点：复杂查询需要手写 SQL
   - 缓解：封装常用查询为 Repository 方法；复杂查询使用 GRDB 查询构建器

2. **无对象关系映射（ORM）**
   - 缺点：需要手动映射 SQL 结果到 Swift 对象
   - 缓解：GRDB 的 `Codable` 支持自动映射；Repository 层抽象细节

3. **迁移手动管理**
   - 缺点：Schema 变更需要手写迁移脚本
   - 缓解：遵循迁移最佳实践；每次迁移独立测试

### 风险

- **数据损坏**: 低（SQLite 稳定）；定期备份，提供导出功能
- **性能瓶颈**: 中（长视频大量片段）；分批查询，LRU 缓存
- **迁移失败**: 低；迁移脚本幂等，提供回滚机制

## 替代方案

### 1. CoreData

**优点**:
- Apple 官方，集成度高
- 自动迁移支持
- iCloud 同步（虽然不需要）

**缺点**:
- 学习曲线陡峭
- 性能不如 SQLite（大量小对象）
- 调试困难，黑盒行为
- 仅限 Apple 平台

**为何不选**: 过度设计，性能不及 SQLite，调试困难

### 2. Realm

**优点**:
- 跨平台（iOS/Android）
- 对象数据库，无需 SQL
- 响应式查询

**缺点**:
- 较大第三方依赖（~10MB）
- 迁移复杂（需要版本管理）
- 团队不熟悉
- 过去有稳定性问题

**为何不选**: 引入重依赖，团队不熟悉，收益不明显

### 3. SwiftData (iOS 17+)

**优点**:
- Apple 官方新框架
- Swift 原生，类型安全
- 自动迁移

**缺点**:
- 新框架，成熟度不足
- 文档和社区少
- 仍基于 CoreData
- 最低 iOS 17（符合项目要求但边界）

**为何不选**: 成熟度不足，风险高，不如 SQLite 稳定

### 4. 纯文件存储（JSON/Plist）

**优点**:
- 简单，无需库
- 易于查看和调试

**缺点**:
- 无索引，查询慢（O(n)）
- 并发控制复杂
- 大文件加载慢
- 无事务支持

**为何不选**: 性能不满足需求，并发不安全

## 实施计划

### Sprint 0（当前）

1. **依赖集成**
   - 添加 GRDB 到 `PrismCore/Package.swift`
   - 配置数据库路径（Application Support）

2. **基础架构**
   - 创建 `Database.swift` 管理连接
   - 实现初始 schema（Migration_001）
   - 封装 `DatabaseActor` 提供并发安全接口

3. **测试**
   - 单元测试：CRUD 操作
   - 集成测试：迁移流程
   - 性能测试：10万条插入+查询

### Sprint 1

- 实现 `MediaRepository` 和 `SubtitleRepository`
- 集成到 AsrEngine 写入流程
- 集成到播放器字幕查询

### 后续优化

- 监控查询性能，优化索引
- 实现数据库压缩和清理
- 添加导出功能（备份）

## 参考资料

- [GRDB.swift](https://github.com/groue/GRDB.swift)
- [SQLite 官方文档](https://www.sqlite.org/docs.html)
- [Swift Concurrency and Database Access](https://github.com/groue/GRDB.swift/blob/master/Documentation/Concurrency.md)

## 元数据

- **作者**: Prism Player Team
- **决策日期**: 2025-10-24
- **相关 ADR**: 
  - ADR-0001: 多平台架构选择
  - ADR-0004: 状态机设计（待创建）
- **相关任务**: 
  - Task-005: 数据与存储占位
  - Sprint 1: AsrEngine 与持久化集成

---

**状态变更日志**:
- 2025-10-24: Proposed → Accepted
