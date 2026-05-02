import Foundation

final class WakePlanService {
    private let calendarReader: CalendarReading
    private let preferencesStore: PreferencesStoring
    private let calculator: WakePlanCalculator

    init(
        calendarReader: CalendarReading,
        preferencesStore: PreferencesStoring,
        calculator: WakePlanCalculator = WakePlanCalculator()
    ) {
        self.calendarReader = calendarReader
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

    private func makePlan(
        targetDay: TargetDay,
        preferences: AlarmPreferences,
        calendar: Calendar = .current
    ) async throws -> WakeUpPlan {
        let events = try await calendarReader.events(
            for: targetDay,
            selectedCalendarIDs: preferences.selectedCalendarIDs
        )

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
        let availableCalendars = try await calendarReader.calendars()

        return availableCalendars.map { source in
            CalendarSource(
                id: source.id,
                title: source.title,
                isSelected: selectedIDs.isEmpty || selectedIDs.contains(source.id)
            )
        }
    }
}
