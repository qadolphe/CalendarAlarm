import XCTest
@testable import EarlyOtter

final class ClockTimeTests: XCTestCase {
    func testDateOnTargetDayUsesProvidedTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Detroit")!

        let targetDay = TargetDay(
            date: makeDate(year: 2026, month: 5, day: 2, hour: 14, minute: 0, calendar: calendar),
            calendar: calendar
        )
        let time = ClockTime(hour: 7, minute: 25)

        let result = time.date(on: targetDay, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 5)
        XCTAssertEqual(components.day, 2)
        XCTAssertEqual(components.hour, 7)
        XCTAssertEqual(components.minute, 25)
    }

    func testTargetDayTomorrowNormalizesToStartOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Detroit")!

        let now = makeDate(year: 2026, month: 5, day: 1, hour: 22, minute: 10, calendar: calendar)
        let tomorrow = TargetDay.tomorrow(from: now, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: tomorrow.date)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 5)
        XCTAssertEqual(components.day, 2)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )

        return calendar.date(from: components)!
    }
}
