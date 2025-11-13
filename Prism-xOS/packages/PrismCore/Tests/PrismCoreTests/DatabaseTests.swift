import XCTest

@testable import PrismCore

/// 数据库基础功能测试
final class DatabaseTests: XCTestCase {
    var db: DatabaseManager!

    override func setUp() async throws {
        // 使用内存数据库进行测试
        db = try DatabaseManager.inMemory()
    }

    // MARK: - 媒体记录测试

    func testMediaRecordCRUD() async throws {
        let repository = MediaRepository(db: db)

        // 创建
        let media = MediaRecord(
            id: "test-media",
            filePath: "/path/to/video.mp4",
            duration: 120.0
        )
        try await repository.save(media)

        // 查询
        let fetched = try await repository.find(id: "test-media")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.filePath, "/path/to/video.mp4")
        XCTAssertEqual(fetched?.duration, 120.0)

        // 更新进度
        try await repository.updateProgress(id: "test-media", progress: 0.5)
        let updated = try await repository.find(id: "test-media")
        XCTAssertEqual(updated?.recognitionProgress, 0.5)

        // 删除
        try await repository.delete(id: "test-media")
        let deleted = try await repository.find(id: "test-media")
        XCTAssertNil(deleted)
    }

    // MARK: - 字幕片段测试

    func testSubtitleSegmentCRUD() async throws {
        let mediaRepo = MediaRepository(db: db)
        let subtitleRepo = SubtitleRepository(db: db)

        // 先创建媒体记录
        let media = MediaRecord(
            id: "test-media",
            filePath: "/path/to/video.mp4",
            duration: 120.0
        )
        try await mediaRepo.save(media)

        // 创建字幕片段
        let segments = [
            AsrSegment(
                mediaId: "test-media",
                startTime: 0.0,
                endTime: 5.0,
                text: "Hello world"
            ),
            AsrSegment(
                mediaId: "test-media",
                startTime: 5.0,
                endTime: 10.0,
                text: "This is a test"
            ),
            AsrSegment(
                mediaId: "test-media",
                startTime: 10.0,
                endTime: 15.0,
                text: "Subtitle segment"
            ),
        ]
        try await subtitleRepo.saveBatch(segments)

        // 查询所有
        let all = try await subtitleRepo.findAll(mediaId: "test-media")
        XCTAssertEqual(all.count, 3)

        // 时间范围查询（查询4.0-11.0，应返回所有与此范围有重叠的片段）
        let range = try await subtitleRepo.findInTimeRange(
            mediaId: "test-media",
            startTime: 4.0,
            endTime: 11.0
        )
        // Segment 1 (0-5): 与4.0-11.0重叠 ✓
        // Segment 2 (5-10): 与4.0-11.0重叠 ✓
        // Segment 3 (10-15): 与4.0-11.0重叠 ✓
        XCTAssertEqual(range.count, 3)
        XCTAssertEqual(range[0].text, "Hello world")
        XCTAssertEqual(range[1].text, "This is a test")
        XCTAssertEqual(range[2].text, "Subtitle segment")

        // 计数
        let count = try await subtitleRepo.count(mediaId: "test-media")
        XCTAssertEqual(count, 3)
    }

    // MARK: - 级联删除测试

    func testCascadeDelete() async throws {
        let mediaRepo = MediaRepository(db: db)
        let subtitleRepo = SubtitleRepository(db: db)

        // 创建媒体和字幕
        let media = MediaRecord(
            id: "test-media",
            filePath: "/path/to/video.mp4",
            duration: 120.0
        )
        try await mediaRepo.save(media)

        let segment = AsrSegment(
            mediaId: "test-media",
            startTime: 0.0,
            endTime: 5.0,
            text: "Test"
        )
        try await subtitleRepo.save(segment)

        // 删除媒体应级联删除字幕
        try await mediaRepo.delete(id: "test-media")

        let segments = try await subtitleRepo.findAll(mediaId: "test-media")
        XCTAssertEqual(segments.count, 0)
    }

    // MARK: - 路径管理测试

    func testAppPaths() throws {
        // 测试路径生成
        XCTAssertNotNil(AppPaths.applicationSupport)
        XCTAssertNotNil(AppPaths.database)
        XCTAssertNotNil(AppPaths.mainDatabase)
        XCTAssertNotNil(AppPaths.models)
        XCTAssertNotNil(AppPaths.audioCache)
        XCTAssertNotNil(AppPaths.exports)

        // 测试目录创建
        try AppPaths.ensureDirectoriesExist()

        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: AppPaths.applicationSupport.path))
        XCTAssertTrue(fileManager.fileExists(atPath: AppPaths.database.path))
    }
}
