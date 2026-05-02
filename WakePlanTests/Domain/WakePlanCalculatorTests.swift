import XCTest
@testable import WakePlan

final class WakePlanCalculatorTests: XCTestCase {
    private let calculator = WakePlanCalculator()

    func testUsesEarliestValidEvent() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        let laterEvent = event(
            id: "later",
            startDate: makeDate(year: 2026, month: 5, day: 2, hour: 10, minute: 0, calendar: calendar),
            endDate: makeDate(year: 2026, month: 5, day: 2, hour: 11, minute: 0, calendar: calendar)
        )
        let earlierEvent = event(
            id: "earlier",
            startDate: makeDate(year: 2026, month: 5, day: 2, hour: 8, minute: 30, calendar: calendar),
            endDate: makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 0, calendar: calendar)
        )

        let plan = calculator.calculate(
            events: [laterEvent, earlierEvent],
            preferences: .default,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertEqual(plan.targetEvent?.id, "earlier")
        XCTAssertEqual(plan.reason, .event)
    }

    func testFallsBackWhenNoValidEvents() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)

        let plan = calculator.calculate(
            events: [],
            preferences: .default,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertNil(plan.targetEvent)
        XCTAssertTrue(plan.isFallback)
        XCTAssertEqual(plan.reason, .fallback)
        XCTAssertEqual(plan.calculatedWakeTime, ClockTime.defaultLatestWakeTime.date(on: targetDay, calendar: calendar))
    }

    func testSubtractsPrepAndCommuteTime() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        let start = makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 0, calendar: calendar)

        let plan = calculator.calculate(
            events: [event(startDate: start, endDate: start.addingTimeInterval(1_800))],
            preferences: .default,
            targetDay: targetDay,
            calendar: calendar
        )

        let expected = makeDate(year: 2026, month: 5, day: 2, hour: 7, minute: 55, calendar: calendar)
        XCTAssertEqual(plan.calculatedWakeTime, expected)
    }

    func testDisabledPreferencesReturnDisabledPlan() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        var preferences = AlarmPreferences.default
        preferences.isEnabled = false

        let plan = calculator.calculate(
            events: [event()],
            preferences: preferences,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertEqual(plan.reason, .disabled)
        XCTAssertTrue(plan.isFallback)
        XCTAssertNil(plan.targetEvent)
    }

    func testDoesNotMutateEvents() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        let events = [
            event(id: "a", startDate: makeDate(year: 2026, month: 5, day: 2, hour: 10, minute: 0, calendar: calendar), endDate: makeDate(year: 2026, month: 5, day: 2, hour: 11, minute: 0, calendar: calendar)),
            event(id: "b", startDate: makeDate(year: 2026, month: 5, day: 2, hour: 8, minute: 0, calendar: calendar), endDate: makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 0, calendar: calendar))
        ]

        _ = calculator.calculate(
            events: events,
            preferences: .default,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertEqual(events[0].id, "a")
        XCTAssertEqual(events[1].id, "b")
    }

    func testHandlesMidnightEvent() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        let start = makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 15, calendar: calendar)

        let plan = calculator.calculate(
            events: [event(startDate: start, endDate: start.addingTimeInterval(3_600))],
            preferences: .default,
            targetDay: targetDay,
            calendar: calendar
        )

        let expected = makeDate(year: 2026, month: 5, day: 1, hour: 23, minute: 10, calendar: calendar)
        XCTAssertEqual(plan.calculatedWakeTime, expected)
    }

    func testHandlesDSTBoundary() {
        var calendar = configuredCalendar()
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        let targetDay = TargetDay(date: makeDate(year: 2026, month: 3, day: 8, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        let start = makeDate(year: 2026, month: 3, day: 8, hour: 3, minute: 30, calendar: calendar)

        let plan = calculator.calculate(
            events: [event(startDate: start, endDate: start.addingTimeInterval(3_600))],
            preferences: .default,
            targetDay: targetDay,
            calendar: calendar
        )

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: plan.calculatedWakeTime)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 8)
        XCTAssertEqual(components.hour, 1)
        XCTAssertEqual(components.minute, 25)
    }

    private func configuredCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Detroit")!
        return calendar
    }

    private func event(
        id: String = UUID().uuidString,
        startDate: Date = Date(timeIntervalSince1970: 1_000),
        endDate: Date = Date(timeIntervalSince1970: 2_000)
    ) -> ParsedEvent {
        ParsedEvent(
            id: id,
            calendarID: "work",
            title: "Standup",
            startDate: startDate,
            endDate: endDate,
            timeZoneIdentifier: nil,
            isAllDay: false,
            status: .confirmed,
            availability: .busy,
            location: nil,
            notes: nil
        )
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
