import XCTest
@testable import EarlyOtter

final class DayTimelineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private lazy var day = TargetDay(date: calendar.date(from: DateComponents(year: 2026, month: 10, day: 2))!, calendar: calendar)

    func testEmptyDayShowsAMorning() {
        let timeline = DayTimeline(plan: plan(), alarm: nil, calendar: calendar)

        XCTAssertEqual(timeline.firstHour, 6)
        XCTAssertEqual(timeline.lastHour, 12)
        XCTAssertEqual(timeline.initialOffset, 0)
    }

    func testShortDayStretchesToFillTheScreen() {
        let timeline = DayTimeline(plan: plan(), alarm: nil, minimumHours: 9, calendar: calendar)

        XCTAssertEqual(timeline.lastHour, 15)
    }

    func testRangeStretchesToCoverEveryEvent() {
        let timeline = DayTimeline(
            plan: plan(events: [event("gym", 5, 30, minutes: 45), event("dinner", 17, 30, minutes: 90)]),
            alarm: time(7, 50),
            calendar: calendar
        )

        XCTAssertEqual(timeline.firstHour, 5)
        XCTAssertEqual(timeline.lastHour, 20)
    }

    func testEventBeforeTheAlarmIsFlagged() {
        let timeline = DayTimeline(
            plan: plan(events: [event("gym", 6, 0), event("standup", 9, 0)]),
            alarm: time(7, 50),
            calendar: calendar
        )

        let flags = timeline.blocks.compactMap { block -> Bool? in
            guard case .event(_, let startsBeforeAlarm, _) = block.kind else { return nil }
            return startsBeforeAlarm
        }
        XCTAssertEqual(flags, [true, false])
    }

    func testOverlappingEventsSitSideBySide() {
        let timeline = DayTimeline(
            plan: plan(events: [event("a", 9, 0), event("b", 9, 30), event("c", 11, 0)]),
            alarm: nil,
            calendar: calendar
        )

        let layout = timeline.blocks.map { "\($0.id):\($0.column)/\($0.columns)" }
        XCTAssertEqual(layout, ["a:0/2", "b:1/2", "c:0/1"])
    }

    func testCalendarAlarmShowsPrepAndCommuteBeforeItsEvent() {
        let target = event("standup", 9, 0)
        let wake = time(7, 50)
        let plan = WakeUpPlan(
            id: "p",
            targetDay: day,
            targetEvent: target,
            calculatedWakeTime: wake,
            eventStartTime: target.startDate,
            prepTime: Minutes(45),
            commuteTime: Minutes(25),
            alarmSettings: .default,
            reason: .event,
            appliedRuleName: nil,
            matchedRuleNames: []
        )

        let steps = DayTimeline(plan: plan, alarm: wake, calendar: calendar).blocks.filter { $0.id == "prep" || $0.id == "commute" }

        XCTAssertEqual(steps.map(\.start), [wake, time(8, 35)])
        XCTAssertEqual(steps.last?.end, target.startDate)
    }

    private func plan(events: [ParsedEvent] = []) -> WakeUpPlan {
        WakeUpPlan(
            id: "p",
            targetDay: day,
            targetEvent: nil,
            dayEvents: events,
            calculatedWakeTime: time(7, 50),
            eventStartTime: nil,
            prepTime: Minutes(0),
            commuteTime: Minutes(0),
            alarmSettings: .default,
            reason: .alarm,
            appliedRuleName: nil,
            matchedRuleNames: []
        )
    }

    private func time(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day.date)!
    }

    private func event(_ id: String, _ hour: Int, _ minute: Int, minutes: Int = 60) -> ParsedEvent {
        let start = time(hour, minute)
        return ParsedEvent(
            id: id,
            calendarID: "c",
            title: id,
            startDate: start,
            endDate: start.addingTimeInterval(TimeInterval(minutes * 60)),
            timeZoneIdentifier: nil,
            isAllDay: false,
            status: .confirmed,
            availability: .busy,
            location: nil,
            notes: nil
        )
    }
}
