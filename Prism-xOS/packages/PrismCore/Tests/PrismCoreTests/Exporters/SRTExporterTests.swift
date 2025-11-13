import XCTest

@testable import PrismCore

/// SRT 导出器单元测试
///
/// 测试覆盖：
/// - 时间戳格式化（正常值、边界值、大数值）
/// - SRT 内容生成（单条、多条、空数组、UTF-8、多行）
/// - 文件名生成与冲突处理
/// - 错误处理（空字幕、时间戳异常、空间不足、权限拒绝）
final class SRTExporterTests: XCTestCase {
    var exporter: DefaultSRTExporter!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        exporter = DefaultSRTExporter()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SRTExporterTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - 时间戳格式化测试

    func testFormatTimestamp_zero() {
        let result = exporter.formatTimestamp(0.0)
        XCTAssertEqual(result, "00:00:00,000")
    }

    func testFormatTimestamp_standard() {
        let result = exporter.formatTimestamp(65.5)
        XCTAssertEqual(result, "00:01:05,500")
    }

    func testFormatTimestamp_largeTime() {
        let result = exporter.formatTimestamp(3_665.123)
        XCTAssertEqual(result, "01:01:05,123")
    }

    func testFormatTimestamp_boundary() {
        // 测试边界值：0 和接近最大值（99:59:59,999 = 359_999.999 秒）
        XCTAssertEqual(exporter.formatTimestamp(0.0), "00:00:00,000")
        XCTAssertEqual(exporter.formatTimestamp(359_999.999), "99:59:59,999")
    }

    func testFormatTimestamp_millisecondPrecision() {
        // 测试毫秒精度
        XCTAssertEqual(exporter.formatTimestamp(1.002), "00:00:01,002")
        XCTAssertEqual(exporter.formatTimestamp(1.999), "00:00:01,999")
        XCTAssertEqual(exporter.formatTimestamp(1.123), "00:00:01,123")
    }

    // MARK: - SRT 内容生成测试

    func testGenerateSRTContent_singleSubtitle() {
        let subtitles = [
            Subtitle(text: "你好，世界", startTime: 0, endTime: 2.5)
        ]

        let result = exporter.generateSRTContent(from: subtitles)

        let expected = """
            1
            00:00:00,000 --> 00:00:02,500
            你好，世界


            """

        XCTAssertEqual(result, expected)
    }

    func testGenerateSRTContent_multipleSubtitles() {
        let subtitles = [
            Subtitle(text: "第一句", startTime: 0, endTime: 2),
            Subtitle(text: "第二句", startTime: 2, endTime: 4),
            Subtitle(text: "第三句", startTime: 4, endTime: 6),
        ]

        let result = exporter.generateSRTContent(from: subtitles)

        XCTAssertTrue(result.contains("1\n00:00:00,000 --> 00:00:02,000\n第一句"))
        XCTAssertTrue(result.contains("2\n00:00:02,000 --> 00:00:04,000\n第二句"))
        XCTAssertTrue(result.contains("3\n00:00:04,000 --> 00:00:06,000\n第三句"))

        // 验证序号递增
        let lines = result.split(separator: "\n")
        let sequenceNumbers = lines.compactMap { Int($0) }
        XCTAssertEqual(sequenceNumbers, [1, 2, 3])
    }

    func testGenerateSRTContent_utf8Characters() {
        let subtitles = [
            Subtitle(text: "中文字幕 🎬", startTime: 0, endTime: 2),
            Subtitle(text: "English Subtitle", startTime: 2, endTime: 4),
            Subtitle(text: "Émojis: 😀🎉✨", startTime: 4, endTime: 6),
            Subtitle(text: "Special: <>&\"'", startTime: 6, endTime: 8),
        ]

        let result = exporter.generateSRTContent(from: subtitles)

        XCTAssertTrue(result.contains("中文字幕 🎬"))
        XCTAssertTrue(result.contains("English Subtitle"))
        XCTAssertTrue(result.contains("Émojis: 😀🎉✨"))
        XCTAssertTrue(result.contains("Special: <>&\"'"))
    }

    func testGenerateSRTContent_multilineText() {
        let subtitles = [
            Subtitle(text: "第一行\n第二行\n第三行", startTime: 0, endTime: 3)
        ]

        let result = exporter.generateSRTContent(from: subtitles)

        XCTAssertTrue(result.contains("第一行\n第二行\n第三行"))
    }

    func testGenerateSRTContent_emptyArray() {
        let subtitles: [Subtitle] = []
        let result = exporter.generateSRTContent(from: subtitles)
        XCTAssertEqual(result, "")
    }

    func testGenerateSRTContent_longText() {
        // 测试超长文本（10_000 字符）
        let longText = String(repeating: "很长的字幕内容。", count: 1_000)
        let subtitles = [
            Subtitle(text: longText, startTime: 0, endTime: 10)
        ]

        let result = exporter.generateSRTContent(from: subtitles)
        XCTAssertTrue(result.contains(longText))
    }

    // MARK: - 文件名生成测试

    func testGenerateFileName_standard() {
        let result = DefaultSRTExporter.generateFileName(
            sourceFileName: "video.mp4",
            locale: "zh-Hans"
        )
        XCTAssertEqual(result, "video.zh-Hans.srt")
    }

    func testGenerateFileName_withoutExtension() {
        let result = DefaultSRTExporter.generateFileName(
            sourceFileName: "audio",
            locale: "en-US"
        )
        XCTAssertEqual(result, "audio.en-US.srt")
    }

    func testGenerateFileName_multipleExtensions() {
        let result = DefaultSRTExporter.generateFileName(
            sourceFileName: "video.backup.mp4",
            locale: "ja"
        )
        XCTAssertEqual(result, "video.backup.ja.srt")
    }

    // MARK: - 文件名冲突处理测试

    func testResolveFileNameConflict_noConflict() {
        let url = tempDirectory.appendingPathComponent("test.srt")
        let result = exporter.resolveFileNameConflict(url)
        XCTAssertEqual(result, url)
    }

    func testResolveFileNameConflict_withConflict() throws {
        let url = tempDirectory.appendingPathComponent("test.srt")

        // 创建冲突文件
        try "dummy".write(to: url, atomically: true, encoding: .utf8)

        let result = exporter.resolveFileNameConflict(url)

        XCTAssertEqual(result.lastPathComponent, "test-1.srt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.path))
    }

    func testResolveFileNameConflict_multipleConflicts() throws {
        let url = tempDirectory.appendingPathComponent("test.srt")

        // 创建多个冲突文件
        try "dummy".write(to: url, atomically: true, encoding: .utf8)

        let url1 = tempDirectory.appendingPathComponent("test-1.srt")
        try "dummy".write(to: url1, atomically: true, encoding: .utf8)

        let url2 = tempDirectory.appendingPathComponent("test-2.srt")
        try "dummy".write(to: url2, atomically: true, encoding: .utf8)

        let result = exporter.resolveFileNameConflict(url)

        XCTAssertEqual(result.lastPathComponent, "test-3.srt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.path))
    }

    // MARK: - 完整导出测试

    func testExport_success() async throws {
        let subtitles = [
            Subtitle(text: "第一句", startTime: 0, endTime: 2),
            Subtitle(text: "第二句", startTime: 2, endTime: 4),
        ]

        let url = tempDirectory.appendingPathComponent("success.srt")

        try await exporter.export(subtitles: subtitles, to: url, locale: "zh-Hans")

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("1\n00:00:00,000 --> 00:00:02,000\n第一句"))
        XCTAssertTrue(content.contains("2\n00:00:02,000 --> 00:00:04,000\n第二句"))
    }

    func testExport_emptySubtitles() async {
        let subtitles: [Subtitle] = []
        let url = tempDirectory.appendingPathComponent("empty.srt")

        do {
            try await exporter.export(subtitles: subtitles, to: url, locale: "zh-Hans")
            XCTFail("应该抛出 emptySubtitles 错误")
        } catch let error as ExportError {
            XCTAssertEqual(error, .emptySubtitles)
        } catch {
            XCTFail("抛出了错误的错误类型：\(error)")
        }
    }

    func testExport_invalidTimestamps_negativeTime() async {
        let subtitles = [
            Subtitle(text: "测试", startTime: -1, endTime: 2)
        ]
        let url = tempDirectory.appendingPathComponent("invalid.srt")

        do {
            try await exporter.export(subtitles: subtitles, to: url, locale: "zh-Hans")
            XCTFail("应该抛出 invalidTimestamps 错误")
        } catch let error as ExportError {
            XCTAssertEqual(error, .invalidTimestamps(index: 0))
        } catch {
            XCTFail("抛出了错误的错误类型：\(error)")
        }
    }

    func testExport_invalidTimestamps_endBeforeStart() async {
        let subtitles = [
            Subtitle(text: "正常", startTime: 0, endTime: 2),
            Subtitle(text: "异常", startTime: 5, endTime: 3),  // endTime < startTime
        ]
        let url = tempDirectory.appendingPathComponent("invalid2.srt")

        do {
            try await exporter.export(subtitles: subtitles, to: url, locale: "zh-Hans")
            XCTFail("应该抛出 invalidTimestamps 错误")
        } catch let error as ExportError {
            XCTAssertEqual(error, .invalidTimestamps(index: 1))
        } catch {
            XCTFail("抛出了错误的错误类型：\(error)")
        }
    }

    func testExport_fileNameConflictResolution() async throws {
        let subtitles = [
            Subtitle(text: "测试", startTime: 0, endTime: 2)
        ]

        let url = tempDirectory.appendingPathComponent("conflict.srt")

        // 第一次导出
        try await exporter.export(subtitles: subtitles, to: url, locale: "zh-Hans")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        // 第二次导出同一文件名，应自动重命名
        try await exporter.export(subtitles: subtitles, to: url, locale: "zh-Hans")

        let url1 = tempDirectory.appendingPathComponent("conflict-1.srt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url1.path))
    }

    func testExport_utf8EncodingNoBOM() async throws {
        let subtitles = [
            Subtitle(text: "中文测试 🎬", startTime: 0, endTime: 2)
        ]

        let url = tempDirectory.appendingPathComponent("utf8.srt")

        try await exporter.export(subtitles: subtitles, to: url, locale: "zh-Hans")

        let data = try Data(contentsOf: url)

        // 验证 UTF-8 编码（无 BOM）
        // UTF-8 BOM 是 EF BB BF
        if data.count >= 3 {
            let firstThreeBytes = data.prefix(3)
            let hasBOM =
                firstThreeBytes[0] == 0xEF && firstThreeBytes[1] == 0xBB
                && firstThreeBytes[2] == 0xBF
            XCTAssertFalse(hasBOM, "文件不应包含 UTF-8 BOM")
        }

        // 验证内容可以正确解码
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("中文测试 🎬"))
    }

    // MARK: - 错误描述测试

    func testExportError_localizedDescription() {
        let error1 = ExportError.emptySubtitles
        XCTAssertNotNil(error1.errorDescription)
        XCTAssertTrue(error1.errorDescription!.contains("字幕"))

        let error2 = ExportError.insufficientSpace(required: 1_048_576, available: 524_288)
        XCTAssertNotNil(error2.errorDescription)
        XCTAssertTrue(error2.errorDescription!.contains("1.00 MB"))

        let error3 = ExportError.permissionDenied(path: "/test/path")
        XCTAssertNotNil(error3.errorDescription)
        XCTAssertTrue(error3.errorDescription!.contains("/test/path"))

        let error4 = ExportError.invalidTimestamps(index: 5)
        XCTAssertNotNil(error4.errorDescription)
        XCTAssertTrue(error4.errorDescription!.contains("6"))  // index + 1
    }

    func testExportError_equatable() {
        XCTAssertEqual(ExportError.emptySubtitles, ExportError.emptySubtitles)
        XCTAssertEqual(
            ExportError.insufficientSpace(required: 100, available: 50),
            ExportError.insufficientSpace(required: 100, available: 50)
        )
        XCTAssertEqual(
            ExportError.permissionDenied(path: "/test"),
            ExportError.permissionDenied(path: "/test")
        )
        XCTAssertEqual(
            ExportError.invalidTimestamps(index: 0),
            ExportError.invalidTimestamps(index: 0)
        )

        XCTAssertNotEqual(ExportError.emptySubtitles, ExportError.invalidTimestamps(index: 0))
    }
}
