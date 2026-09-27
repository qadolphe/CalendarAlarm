import XCTest
@testable import EarlyOtter

final class TimetableFormatTests: XCTestCase {
    func testDurationUnderAnHourIsMinutes() {
        XCTAssertEqual(TimetableFormat.duration(Minutes(45)), .init(value: "45", unit: "min"))
    }

    func testDurationFromAnHourIsHours() {
        XCTAssertEqual(TimetableFormat.duration(Minutes(60)), .init(value: "1", unit: "hr"))
        XCTAssertEqual(TimetableFormat.duration(Minutes(90)), .init(value: "1:30", unit: "hr"))
    }

    func testClockSplitsPeriodIn12HourLocale() {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 7, minute: 55))!

        let parts = TimetableFormat.clock(date, calendar: calendar, locale: Locale(identifier: "en_US"))

        XCTAssertEqual(parts.value, "7:55")
        XCTAssertEqual(parts.unit, calendar.amSymbol)
    }

    func testClockHasNoPeriodIn24HourLocale() {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 7, minute: 55))!

        XCTAssertNil(TimetableFormat.clock(date, calendar: calendar, locale: Locale(identifier: "en_GB")).unit)
    }

    func testCountdownDisappearsOnceTheAlarmHasPassed() {
        let now = Date()
        XCTAssertNotNil(TimetableFormat.countdown(from: now, to: now.addingTimeInterval(3_600)))
        XCTAssertNil(TimetableFormat.countdown(from: now, to: now.addingTimeInterval(-60)))
    }
}
