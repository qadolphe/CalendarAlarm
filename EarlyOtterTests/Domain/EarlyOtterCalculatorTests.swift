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

        XCTAssertEqual(plan.reason, .fallback)
        XCTAssertTrue(plan.isFallback)
        XCTAssertNil(plan.targetEvent)
    }

    func testInactiveDayReturnsInactiveDayPlan() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        var preferences = AlarmPreferences.default
        preferences.activeDays = [2, 3, 4, 5, 6]

        let plan = calculator.calculate(
            events: [event()],
            preferences: preferences,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertEqual(plan.reason, .fallback)
        XCTAssertTrue(plan.isFallback)
        XCTAssertNil(plan.targetEvent)
    }

    func testNoScheduleWhenNoEventsAndFallbackDisabled() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        var preferences = AlarmPreferences.default
        preferences.fallbackEnabledDays = []

        let plan = calculator.calculate(
            events: [],
            preferences: preferences,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertEqual(plan.reason, .noSchedule)
        XCTAssertFalse(plan.isFallback)
        XCTAssertNil(plan.targetEvent)
    }

    func testFallbackWinsWhenEarlierThanEventAlarm() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        var preferences = AlarmPreferences.default
        preferences.schedule.fallbackWakeTimes[calendar.component(.weekday, from: targetDay.date)] = ClockTime(hour: 8, minute: 0)

        let eventStart = makeDate(year: 2026, month: 5, day: 2, hour: 15, minute: 0, calendar: calendar)
        let plan = calculator.calculate(
            events: [event(startDate: eventStart, endDate: eventStart.addingTimeInterval(1_800))],
            preferences: preferences,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertEqual(plan.reason, .fallback)
        XCTAssertTrue(plan.isFallback)
        XCTAssertNil(plan.targetEvent)
        XCTAssertEqual(plan.calculatedWakeTime, makeDate(year: 2026, month: 5, day: 2, hour: 8, minute: 0, calendar: calendar))
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

    func testSkipsEventsOutsideRuleCalendarSelection() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        let personalEvent = event(
            id: "personal",
            calendarID: "personal",
            startDate: makeDate(year: 2026, month: 5, day: 2, hour: 8, minute: 0, calendar: calendar),
            endDate: makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 0, calendar: calendar)
        )
        let workEvent = event(
            id: "work",
            calendarID: "work",
            startDate: makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 0, calendar: calendar),
            endDate: makeDate(year: 2026, month: 5, day: 2, hour: 10, minute: 0, calendar: calendar)
        )
        var preferences = AlarmPreferences.default
        preferences.alarmRules = [
            AlarmRule.makeDefault(selectedCalendarIDs: ["work"])
        ]

        let plan = calculator.calculate(
            events: [personalEvent, workEvent],
            preferences: preferences,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertEqual(plan.targetEvent?.id, "work")
    }

    func testFallbackInheritsDefaultRuleAlarmSettings() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        var preferences = AlarmPreferences.default
        preferences.alarmRules = [
            AlarmRule.makeDefault(
                prepTime: Minutes(45),
                commuteTime: Minutes(20),
                alarmSettings: RuleAlarmSettings(
                    sound: .glass,
                    snoozeEnabled: false,
                    snoozeDuration: Minutes(15)
                )
            )
        ]

        let plan = calculator.calculate(
            events: [],
            preferences: preferences,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertEqual(plan.reason, .fallback)
        XCTAssertEqual(plan.alarmSettings.sound, .glass)
        XCTAssertFalse(plan.alarmSettings.snoozeEnabled)
        XCTAssertEqual(plan.alarmSettings.snoozeDuration, Minutes(15))
    }

    func testRuleWeekdaysGateRuleMatching() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        let saturdayEvent = event(
            id: "office",
            calendarID: "work",
            startDate: makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 0, calendar: calendar),
            endDate: makeDate(year: 2026, month: 5, day: 2, hour: 10, minute: 0, calendar: calendar),
            title: "Office planning"
        )
        let weekdaysOnlyRule = AlarmRule(
            id: UUID(),
            name: "Weekdays Only",
            isDefault: false,
            activeWeekdays: Set([2, 3, 4, 5, 6]),
            selectedCalendarIDs: [],
            conditions: [.titleContains("office")],
            prepTime: Minutes(60),
            commuteTime: Minutes(30),
            alarmSettings: .default
        )
        var preferences = AlarmPreferences.default
        preferences.alarmRules = [
            weekdaysOnlyRule,
            AlarmRule.makeDefault(prepTime: Minutes(10), commuteTime: Minutes(0))
        ]
        preferences.fallbackEnabledDays = []

        let plan = calculator.calculate(
            events: [saturdayEvent],
            preferences: preferences,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertEqual(plan.appliedRuleName, "Default")
        XCTAssertEqual(plan.prepTime, Minutes(10))
        XCTAssertEqual(plan.commuteTime, Minutes(0))
    }

    // MARK: - Earliest wake time policy

    /// An event that starts later but needs heavy prep wins over an earlier event with minimal prep.
    func testEarliestWakeTimeWinsOverEarliestEventStart() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)

        // Remote meeting at 8:30 — matched by "Remote" rule: 15 min prep → wake 8:15
        let remoteEvent = event(
            id: "remote",
            calendarID: "work",
            startDate: makeDate(year: 2026, month: 5, day: 2, hour: 8, minute: 30, calendar: calendar),
            endDate: makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 30, calendar: calendar),
            title: "Remote standup"
        )
        // Office meeting at 9:00 — matched by "Office" rule: 45 min prep + 30 min commute → wake 7:45
        let officeEvent = event(
            id: "office",
            calendarID: "work",
            startDate: makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 0, calendar: calendar),
            endDate: makeDate(year: 2026, month: 5, day: 2, hour: 10, minute: 0, calendar: calendar),
            title: "Office planning"
        )

        let remoteRule = AlarmRule(
            id: UUID(), name: "Remote", isDefault: false,
            activeWeekdays: Set(1...7),
            selectedCalendarIDs: [],
            conditions: [.titleContains("remote")],
            prepTime: Minutes(15), commuteTime: Minutes(0),
            alarmSettings: .default
        )
        let officeRule = AlarmRule(
            id: UUID(), name: "Office", isDefault: false,
            activeWeekdays: Set(1...7),
            selectedCalendarIDs: [],
            conditions: [.titleContains("office")],
            prepTime: Minutes(45), commuteTime: Minutes(30),
            alarmSettings: .default
        )
        var preferences = AlarmPreferences.default
        preferences.alarmRules = [remoteRule, officeRule, AlarmRule.makeDefault(prepTime: Minutes(0), commuteTime: Minutes(0))]

        let plan = calculator.calculate(
            events: [remoteEvent, officeEvent],
            preferences: preferences,
            targetDay: targetDay,
            calendar: calendar
        )

        // Office event starts later but requires more prep → earlier wake time wins
        XCTAssertEqual(plan.targetEvent?.id, "office")
        let expected = makeDate(year: 2026, month: 5, day: 2, hour: 7, minute: 45, calendar: calendar)
        XCTAssertEqual(plan.calculatedWakeTime, expected)
    }

    /// When multiple rules match the same event, matchedRuleNames is populated.
    func testMatchedRuleNamesPopulatedForMultiRuleEvent() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)

        let evt = event(
            id: "planning",
            calendarID: "work",
            startDate: makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 0, calendar: calendar),
            endDate: makeDate(year: 2026, month: 5, day: 2, hour: 10, minute: 0, calendar: calendar),
            title: "Work and school planning"
        )

        let workRule = AlarmRule(
            id: UUID(), name: "Work", isDefault: false,
            activeWeekdays: Set(1...7),
            selectedCalendarIDs: [],
            conditions: [.titleContains("work")],
            prepTime: Minutes(30), commuteTime: Minutes(0),   // wake at 8:30
            alarmSettings: .default
        )
        let schoolRule = AlarmRule(
            id: UUID(), name: "School", isDefault: false,
            activeWeekdays: Set(1...7),
            selectedCalendarIDs: [],
            conditions: [.titleContains("school")],
            prepTime: Minutes(15), commuteTime: Minutes(0),   // wake at 8:45
            alarmSettings: .default
        )
        var preferences = AlarmPreferences.default
        preferences.alarmRules = [workRule, schoolRule, AlarmRule.makeDefault(prepTime: Minutes(0), commuteTime: Minutes(0))]
        preferences.fallbackEnabledDays = []

        let plan = calculator.calculate(
            events: [evt],
            preferences: preferences,
            targetDay: targetDay,
            calendar: calendar
        )

        // Work rule gives earlier wake time
        let expected = makeDate(year: 2026, month: 5, day: 2, hour: 8, minute: 30, calendar: calendar)
        XCTAssertEqual(plan.calculatedWakeTime, expected)
        // Both rules matched → names surfaced
        XCTAssertTrue(plan.matchedRuleNames.contains("Work"))
        XCTAssertTrue(plan.matchedRuleNames.contains("School"))
    }

    /// When only one rule matches an event, matchedRuleNames is empty (no explanation needed).
    func testMatchedRuleNamesEmptyForSingleRuleMatch() {
        let calendar = configuredCalendar()
        let targetDay = TargetDay(date: makeDate(year: 2026, month: 5, day: 2, hour: 0, minute: 0, calendar: calendar), calendar: calendar)
        let start = makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 0, calendar: calendar)

        let plan = calculator.calculate(
            events: [event(startDate: start, endDate: start.addingTimeInterval(3_600))],
            preferences: .default,
            targetDay: targetDay,
            calendar: calendar
        )

        XCTAssertTrue(plan.matchedRuleNames.isEmpty)
    }

    private func configuredCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Detroit")!
        return calendar
    }

    private func event(
        id: String = UUID().uuidString,
        calendarID: String = "work",
        startDate: Date = Date(timeIntervalSince1970: 1_000),
        endDate: Date = Date(timeIntervalSince1970: 2_000),
        title: String = "Standup"
    ) -> ParsedEvent {
        ParsedEvent(
            id: id,
            calendarID: calendarID,
            title: title,
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
