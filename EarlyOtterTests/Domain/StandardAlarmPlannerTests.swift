import XCTest
@testable import EarlyOtter

final class StandardAlarmPlannerTests: XCTestCase {
    private let planner = StandardAlarmPlanner()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Detroit")!
        return calendar
    }()

    // Saturday, May 2 2026.
    private var saturday: TargetDay {
        TargetDay(date: date(hour: 0, minute: 0), calendar: calendar)
    }

    func testSkipsWhenCalendarAlarmRingsInsideWindow() {
        let alarm = StandardAlarm(
            time: ClockTime(hour: 6, minute: 45),
            repeatDays: Set(1...7),
            calendarSkip: .within(Minutes(180))
        )

        let plans = planner.plans(
            for: [saturday],
            calendarPlans: [calendarPlan(at: date(hour: 5, minute: 50))],
            preferences: preferences(with: [alarm]),
            calendar: calendar
        )

        XCTAssertTrue(plans.isEmpty)
    }

    func testRingsWhenCalendarAlarmIsOutsideWindow() {
        let nap = StandardAlarm(
            time: ClockTime(hour: 15, minute: 0),
            repeatDays: Set(1...7),
            label: "Nap",
            calendarSkip: .within(Minutes(180))
        )

        let plans = planner.plans(
            for: [saturday],
            calendarPlans: [calendarPlan(at: date(hour: 9, minute: 0))],
            preferences: preferences(with: [nap]),
            calendar: calendar
        )

        XCTAssertEqual(plans.map(\.calculatedWakeTime), [date(hour: 15, minute: 0)])
        XCTAssertEqual(plans.first?.reason, .alarm)
        XCTAssertEqual(plans.first?.alarmLabel, "Nap")
    }

    func testAlarmWithoutSkipRuleAlwaysRings() {
        let alarm = StandardAlarm(time: ClockTime(hour: 6, minute: 45), repeatDays: Set(1...7))

        let plans = planner.plans(
            for: [saturday],
            calendarPlans: [calendarPlan(at: date(hour: 6, minute: 0))],
            preferences: preferences(with: [alarm]),
            calendar: calendar
        )

        XCTAssertEqual(plans.count, 1)
    }

    func testEditedDayReplacesStandardAlarms() {
        let alarm = StandardAlarm(time: ClockTime(hour: 6, minute: 45), repeatDays: Set(1...7))
        var prefs = preferences(with: [alarm])
        prefs.setOverride(DayAlarmOverride(customWakeTime: nil, isSkipped: true), for: saturday, calendar: calendar)

        let plans = planner.plans(for: [saturday], calendarPlans: [], preferences: prefs, calendar: calendar)

        XCTAssertTrue(plans.isEmpty)
    }

    func testOneTimeAlarmRingsOnItsDayThenCountsAsFired() {
        let alarm = StandardAlarm(time: ClockTime(hour: 15, minute: 0))
            .armed(now: date(hour: 12, minute: 0), calendar: calendar)
        let sunday = TargetDay.tomorrow(from: saturday.date, calendar: calendar)

        XCTAssertEqual(alarm.oneTimeDay, saturday)
        XCTAssertNotNil(alarm.ringDate(on: saturday, calendar: calendar))
        XCTAssertNil(alarm.ringDate(on: sunday, calendar: calendar))
        XCTAssertFalse(alarm.hasFired(now: date(hour: 14, minute: 59), calendar: calendar))
        XCTAssertTrue(alarm.hasFired(now: date(hour: 15, minute: 0), calendar: calendar))
    }

    func testChosenDateIsKeptUntilItPasses() {
        let nextWeek = TargetDay(date: date(hour: 0, minute: 0).addingTimeInterval(7 * 86_400), calendar: calendar)
        let alarm = StandardAlarm(time: ClockTime(hour: 9, minute: 0), chosenDay: nextWeek)

        let armed = alarm.armed(now: date(hour: 12, minute: 0), calendar: calendar)
        XCTAssertEqual(armed.oneTimeDay, nextWeek)

        // Turned back on after that date, it falls back to the next 9:00.
        let rearmed = alarm.armed(now: nextWeek.date.addingTimeInterval(12 * 3_600), calendar: calendar)
        XCTAssertNil(rearmed.chosenDay)
        XCTAssertEqual(rearmed.oneTimeDay, TargetDay.tomorrow(from: nextWeek.date, calendar: calendar))
    }

    func testWeekViewShowsEarlierStandardAlarmWithTheDaysEvent() {
        let calendarAlarm = calendarPlan(at: date(hour: 9, minute: 0))
        let alarm = StandardAlarm(time: ClockTime(hour: 7, minute: 0), repeatDays: Set(1...7))
        let alarmPlans = planner.plans(
            for: [saturday],
            calendarPlans: [calendarAlarm],
            preferences: preferences(with: [alarm]),
            calendar: calendar
        )

        let dayPlans = planner.earliestPerDay(calendarPlans: [calendarAlarm], alarmPlans: alarmPlans)

        XCTAssertEqual(dayPlans.first?.reason, .alarm)
        XCTAssertEqual(dayPlans.first?.firstEventOfDay?.id, calendarAlarm.targetEvent?.id)
    }

    func testStandbySchedulesMigrateToRepeatingAlarms() throws {
        var legacy = AlarmPreferences.default
        legacy.alarmRules = [
            AlarmRule.makeDefault(alarmSettings: RuleAlarmSettings(sound: .tide, snoozeEnabled: false, snoozeDuration: Minutes(5)))
        ]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        json["schedule"] = [
            "isEnabled": true,
            "activeDays": [2, 3, 4, 5, 6],
            "fallbackEnabledDays": [2, 3, 7],
            "fallbackWakeTimes": ["7": ["hour": 9, "minute": 30]]
        ]

        let migrated = try JSONDecoder().decode(
            AlarmPreferences.self,
            from: JSONSerialization.data(withJSONObject: json)
        )

        XCTAssertEqual(migrated.standardAlarms.map(\.time), [ClockTime(hour: 8, minute: 0), ClockTime(hour: 9, minute: 30)])
        XCTAssertEqual(migrated.standardAlarms.map(\.repeatDays), [[2, 3], [7]])
        XCTAssertTrue(migrated.standardAlarms.allSatisfy { $0.calendarSkip == .within(CalendarSkipRule.defaultWindow) })
        XCTAssertTrue(migrated.standardAlarms.allSatisfy { $0.settings.sound == .tide })

        // Saved again, the alarms round-trip instead of migrating a second time.
        let reloaded = try JSONDecoder().decode(AlarmPreferences.self, from: JSONEncoder().encode(migrated))
        XCTAssertEqual(reloaded.standardAlarms, migrated.standardAlarms)
    }

    // MARK: Helpers

    private func preferences(with alarms: [StandardAlarm]) -> AlarmPreferences {
        var preferences = AlarmPreferences.default
        preferences.standardAlarms = alarms
        return preferences
    }

    private func calendarPlan(at wakeTime: Date) -> WakeUpPlan {
        let start = wakeTime.addingTimeInterval(3_600)
        let event = ParsedEvent(
            id: "event",
            calendarID: "work",
            title: "Class",
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            timeZoneIdentifier: calendar.timeZone.identifier,
            isAllDay: false,
            status: .confirmed,
            availability: .busy,
            location: nil,
            notes: nil
        )

        return WakeUpPlan(
            id: "calendar-plan",
            targetDay: saturday,
            targetEvent: event,
            calculatedWakeTime: wakeTime,
            eventStartTime: start,
            prepTime: Minutes(30),
            commuteTime: Minutes(30),
            alarmSettings: .default,
            reason: .event,
            appliedRuleName: "Default",
            matchedRuleNames: []
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 5,
            day: 2,
            hour: hour,
            minute: minute
        ))!
    }
}
