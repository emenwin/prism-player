import PrismCore
import XCTest

@testable import PrismASR

final class AsrEngineTests: XCTestCase {
    // MARK: - AsrOptions Tests

    func testAsrOptionsDefaultValues() {
        let options = AsrOptions()

        XCTAssertNil(options.language)
        XCTAssertTrue(options.enableTimestamps)
    }

    func testAsrOptionsCustomValues() {
        let options = AsrOptions(language: "en", enableTimestamps: false)

        XCTAssertEqual(options.language, "en")
        XCTAssertFalse(options.enableTimestamps)
    }

    // MARK: - MockAsrEngine Tests

    func testMockAsrEngineReturnsPresetResults() async throws {
        let mockEngine = MockAsrEngine()
        let expectedSegments = [
            AsrSegment(startTime: 0.0, endTime: 5.0, text: "Hello", confidence: 0.9)
        ]
        mockEngine.transcribeResult = expectedSegments

        let audioData = Data([0x00, 0x01, 0x02])
        let options = AsrOptions(language: "en")

        let result = try await mockEngine.transcribe(audioData: audioData, options: options)

        XCTAssertTrue(mockEngine.transcribeCalled)
        XCTAssertEqual(mockEngine.lastAudioData, audioData)
        XCTAssertEqual(mockEngine.lastOptions?.language, "en")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.text, "Hello")
    }

    func testMockAsrEngineThrowsError() async {
        let mockEngine = MockAsrEngine()
        mockEngine.errorToThrow = NSError(domain: "TestError", code: 1)

        let audioData = Data()
        let options = AsrOptions()

        do {
            _ = try await mockEngine.transcribe(audioData: audioData, options: options)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(mockEngine.transcribeCalled)
        }
    }

    // MARK: - AsrLanguage Tests

    func testAsrLanguageRawValues() {
        XCTAssertEqual(AsrLanguage.auto.rawValue, "auto")
        XCTAssertEqual(AsrLanguage.english.rawValue, "en")
        XCTAssertEqual(AsrLanguage.chinese.rawValue, "zh")
    }

    func testAsrLanguageDisplayNames() {
        XCTAssertEqual(AsrLanguage.english.displayName, "asr.language.english")
        XCTAssertEqual(AsrLanguage.chinese.displayName, "asr.language.chinese")
    }
}
