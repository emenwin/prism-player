import XCTest

@testable import PrismCore

final class PrismCoreTests: XCTestCase {

    // MARK: - AsrSegment Tests

    func testAsrSegmentCreation() {
        let segment = AsrSegment(
            startTime: 0.0,
            endTime: 5.0,
            text: "Hello, world!",
            confidence: 0.95
        )

        XCTAssertEqual(segment.text, "Hello, world!")
        XCTAssertEqual(segment.startTime, 0.0)
        XCTAssertEqual(segment.endTime, 5.0)
        XCTAssertEqual(segment.confidence, 0.95)
    }

    func testAsrSegmentDuration() {
        let segment = AsrSegment(
            startTime: 10.5,
            endTime: 25.0,
            text: "Test",
            confidence: 0.9
        )

        XCTAssertEqual(segment.duration, 14.5, accuracy: 0.01)
    }

    func testAsrSegmentHighConfidence() {
        let highConfidence = AsrSegment(
            startTime: 0.0,
            endTime: 5.0,
            text: "High",
            confidence: 0.85
        )

        let lowConfidence = AsrSegment(
            startTime: 0.0,
            endTime: 5.0,
            text: "Low",
            confidence: 0.5
        )

        XCTAssertTrue(highConfidence.isHighConfidence)
        XCTAssertFalse(lowConfidence.isHighConfidence)
    }

    func testAsrSegmentCodable() throws {
        let original = AsrSegment(
            id: UUID(),
            startTime: 0.0,
            endTime: 10.0,
            text: "Codable test",
            confidence: 0.92
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AsrSegment.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.startTime, original.startTime)
        XCTAssertEqual(decoded.endTime, original.endTime)
        XCTAssertEqual(decoded.confidence, original.confidence)
    }
}
