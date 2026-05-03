import Foundation

final class WakePlanService {
    private let calendarProvider: CalendarEventProviding
    private let preferencesStore: PreferencesStoring
    private let calculator: WakePlanCalculator

    init(
        calendarProvider: CalendarEventProviding,
        preferencesStore: PreferencesStoring,
        calculator: WakePlanCalculator = WakePlanCalculator()
    ) {
        self.calendarProvider = calendarProvider
        self.preferencesStore = preferencesStore
        self.calculator = calculator
    }

    func makePlan(targetDay: TargetDay = .tomorrow()) async throws -> WakeUpPlan {
        let preferences = try preferencesStore.load()
        return try await makePlan(targetDay: targetDay, preferences: preferences)
    }

    func makeUpcomingPlans(
        after targetDay: TargetDay = .tomorrow(),
        count: Int,
        calendar: Calendar = .current
    ) async throws -> [WakeUpPlan] {
        guard count > 0 else { return [] }

        let preferences = try preferencesStore.load()
        var plans: [WakeUpPlan] = []
        plans.reserveCapacity(count)

        for offset in 1...count {
            let date = calendar.date(byAdding: .day, value: offset, to: targetDay.date) ?? targetDay.date
            let day = TargetDay(date: date, calendar: calendar)
            let plan = try await makePlan(targetDay: day, preferences: preferences, calendar: calendar)
            plans.append(plan)
        }

        return plans
    }

    func makeDisplayPlans(
        startingAt now: Date = Date(),
        count: Int,
        calendar: Calendar = .current
    ) async throws -> [WakeUpPlan] {
        guard count > 0 else { return [] }

        let preferences = try preferencesStore.load()
        var plans: [WakeUpPlan] = []
        plans.reserveCapacity(count)

        for offset in 0..<count {
            let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
            let day = TargetDay(date: date, calendar: calendar)
            let plan = try await makePlan(targetDay: day, preferences: preferences, calendar: calendar)

            if plan.calculatedWakeTime > now {
                plans.append(plan)
            }
        }

        return plans
    }

    private func makePlan(
        targetDay: TargetDay,
        preferences: AlarmPreferences,
        calendar: Calendar = .current
    ) async throws -> WakeUpPlan {
        let events = try await calendarProvider.events(for: targetDay)

        return calculator.calculate(
            events: events,
            preferences: preferences,
            targetDay: targetDay,
            calendar: calendar
        )
    }

    func calendars() async throws -> [CalendarSource] {
        let preferences = try preferencesStore.load()
        let selectedIDs = preferences.selectedCalendarIDs
        let availableCalendars = try await calendarProvider.calendars()

        return availableCalendars.map { source in
            CalendarSource(
                id: source.id,
                title: source.title,
                isSelected: selectedIDs.isEmpty || selectedIDs.contains(source.id),
                accountID: source.accountID,
                provider: source.provider
            )
        }
    }

    func accounts() async throws -> [ConnectedCalendarAccount] {
        try await calendarProvider.accounts()
    }
}
