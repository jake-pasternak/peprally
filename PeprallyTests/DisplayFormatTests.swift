import XCTest
@testable import Peprally

final class DisplayFormatTests: XCTestCase {

    /// Postgres `timestamptz` the way PostgREST returns it: microseconds and a
    /// `+00:00` offset, which ISO8601DateFormatter can't parse unaided.
    private func postgresTimestamp(secondsAgo: TimeInterval) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSxxx"
        return f.string(from: Date().addingTimeInterval(-secondsAgo))
    }

    func testRelativeParsesMicrosecondTimestamps() {
        XCTAssertEqual(DisplayFormat.relative(postgresTimestamp(secondsAgo: 5 * 60 + 10)), "5m")
        XCTAssertEqual(DisplayFormat.relative(postgresTimestamp(secondsAgo: 3 * 3600 + 60)), "3h")
        XCTAssertEqual(DisplayFormat.relative(postgresTimestamp(secondsAgo: 2 * 86400 + 60)), "2d")
        XCTAssertEqual(DisplayFormat.relative(postgresTimestamp(secondsAgo: 3 * 604800 + 60)), "3w")
    }

    func testRelativeAcceptsTimestampsWithoutFraction() {
        let f = ISO8601DateFormatter()
        let iso = f.string(from: Date().addingTimeInterval(-7200 - 30))
        XCTAssertEqual(DisplayFormat.relative(iso), "2h")
    }

    func testRelativeFallsBackToNowOnGarbage() {
        XCTAssertEqual(DisplayFormat.relative("not a date"), "now")
        XCTAssertEqual(DisplayFormat.relative(postgresTimestamp(secondsAgo: 10)), "now")
    }

    func testInitials() {
        XCTAssertEqual(DisplayFormat.initials(from: "@peptidepete"), "PE")
        XCTAssertEqual(DisplayFormat.initials(from: "j"), "J")
        XCTAssertEqual(DisplayFormat.initials(from: ""), "•")
        XCTAssertEqual(DisplayFormat.initials(from: "@"), "•")
    }

    func testAvatarShadeIsStablePerHandle() {
        XCTAssertEqual(DisplayFormat.avatarHex(from: "glp1journey"),
                       DisplayFormat.avatarHex(from: "glp1journey"))
        // Any input must land inside the grey palette, never trap.
        for seed in ["", "a", String(repeating: "z", count: 10_000), "🧪"] {
            let hex = DisplayFormat.avatarHex(from: seed)
            XCTAssertTrue((0xDCDCDC...0xF2F2F2).contains(hex), "\(seed.prefix(8)) → \(hex)")
        }
    }
}
