import XCTest
@testable import DayRecorder

final class FileNamingTests: XCTestCase {

    func testDefaultFilename() {
        let date = makeDate(year: 2024, month: 3, day: 15, hour: 9, minute: 5)
        let name = FileNaming.filename(for: "", date: date)
        XCTAssertEqual(name, "2024-03-15_09-05_Recording.m4a")
    }

    func testCustomTitle() {
        let date = makeDate(year: 2024, month: 11, day: 2, hour: 14, minute: 30)
        let name = FileNaming.filename(for: "Team Standup", date: date)
        XCTAssertEqual(name, "2024-11-02_14-30_Team Standup.m4a")
    }

    func testSanitizesIllegalChars() {
        let sanitized = FileNaming.sanitize(title: "Meeting: Q4/Review *Final*")
        XCTAssertFalse(sanitized.contains("/"))
        XCTAssertFalse(sanitized.contains(":"))
        XCTAssertFalse(sanitized.contains("*"))
    }

    func testWhitespaceTrimming() {
        let name = FileNaming.filename(for: "  Notes  ")
        XCTAssertTrue(name.contains("Notes"))
        XCTAssertFalse(name.contains("  Notes"))
    }

    func testUniqueURL() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = FileNaming.uniqueURL(in: dir, filename: "test.m4a")
        XCTAssertEqual(first.lastPathComponent, "test.m4a")

        // Simulate existing file
        FileManager.default.createFile(atPath: first.path, contents: nil)
        let second = FileNaming.uniqueURL(in: dir, filename: "test.m4a")
        XCTAssertEqual(second.lastPathComponent, "test_2.m4a")
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = minute; c.second = 0
        return Calendar.current.date(from: c)!
    }
}

final class RecordingModelTests: XCTestCase {

    func testFormattedDurationUnderHour() {
        let rec = makeRecording(duration: 125)
        XCTAssertEqual(rec.formattedDuration, "2:05")
    }

    func testFormattedDurationOverHour() {
        let rec = makeRecording(duration: 3661)
        XCTAssertEqual(rec.formattedDuration, "1:01:01")
    }

    func testCodableRoundtrip() throws {
        let original = makeRecording(duration: 60)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Recording.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.duration, original.duration)
    }

    private func makeRecording(duration: TimeInterval) -> Recording {
        Recording(
            id: UUID(),
            title: "Test",
            filename: "test.m4a",
            createdAt: Date(),
            duration: duration,
            fileSize: 1024,
            filePath: "/tmp/test.m4a"
        )
    }
}

final class SettingsTests: XCTestCase {

    func testDefaultOutputDirectoryContainsDayRecorder() {
        let store = SettingsStore.shared
        XCTAssertTrue(store.outputDirectory.lastPathComponent == "DayRecorder" ||
                      store.outputDirectory.path.contains("DayRecorder"))
    }

    func testAutoSplitIntervalRawValues() {
        XCTAssertEqual(AutoSplitInterval.off.rawValue, 0)
        XCTAssertEqual(AutoSplitInterval.thirtyMin.rawValue, 30)
        XCTAssertEqual(AutoSplitInterval.sixtyMin.rawValue, 60)
        XCTAssertEqual(AutoSplitInterval.twoHours.rawValue, 120)
    }

    func testAutoSplitIntervalDisplayNames() {
        XCTAssertEqual(AutoSplitInterval.off.displayName, "Off")
        XCTAssertEqual(AutoSplitInterval.thirtyMin.displayName, "30 min")
    }
}
