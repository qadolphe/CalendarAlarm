import XCTest
@testable import WakePlan

@MainActor
final class AppStateTests: XCTestCase {
    func testPrimaryDashboardPlanReturnsNoSchedulePlaceholderWhenNoFuturePlansExist() {
        let calendar = configuredCalendar()
        let now = makeDate(
            year: 2026,
            month: 5,
            day: 4,
            hour: 10,
            minute: 40,
            calendar: calendar
        )

        let plan = AppState.primaryDashboardPlan(
            from: [],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(plan.reason, .noSchedule)
        XCTAssertFalse(plan.isFallback)
        XCTAssertNil(plan.targetEvent)
        XCTAssertEqual(plan.targetDay, TargetDay.tomorrow(from: now, calendar: calendar))
        XCTAssertEqual(plan.calculatedWakeTime, TargetDay.tomorrow(from: now, calendar: calendar).date)
    }

    func testPrimaryDashboardPlanPrefersFirstFutureDisplayPlan() {
        let calendar = configuredCalendar()
        let now = makeDate(
            year: 2026,
            month: 5,
            day: 4,
            hour: 10,
            minute: 40,
            calendar: calendar
        )
        let expectedWakeTime = makeDate(
            year: 2026,
            month: 5,
            day: 5,
            hour: 8,
            minute: 30,
            calendar: calendar
        )
        let expectedPlan = WakeUpPlan(
            id: "future-plan",
            targetDay: TargetDay(date: expectedWakeTime, calendar: calendar),
            targetEvent: nil,
            calculatedWakeTime: expectedWakeTime,
            eventStartTime: nil,
            prepTime: Minutes(0),
            commuteTime: Minutes(0),
            alarmSettings: .default,
            isFallback: true,
            reason: .fallback,
            appliedRuleName: nil,
            matchedRuleNames: []
        )

        let plan = AppState.primaryDashboardPlan(
            from: [expectedPlan],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(plan, expectedPlan)
    }

    private func configuredCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Detroit")!
        return calendar
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
            calendar: calendar,
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
