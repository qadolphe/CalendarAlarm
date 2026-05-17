import Foundation

final class EarlyOtterService {
    private let calendarProvider: CalendarEventProviding
    private let preferencesStore: PreferencesStoring
    private let calculator: EarlyOtterCalculator

    init(
        calendarProvider: CalendarEventProviding,
        preferencesStore: PreferencesStoring,
        calculator: EarlyOtterCalculator = EarlyOtterCalculator()
    ) {
        self.calendarProvider = calendarProvider
        self.preferencesStore = preferencesStore
        self.calculator = calculator
    }

    func makePlan(
        targetDay: TargetDay = .tomorrow(),
        calendar: Calendar = .current
    ) async throws -> WakeUpPlan {
        let preferences = try preferencesStore.load()
        return try await makePlan(
            targetDay: targetDay,
            preferences: preferences,
            calendar: calendar
        )
    }

    func makeUpcomingPlans(
        after targetDay: TargetDay = .tomorrow(),
        count: Int,
        calendar: Calendar = .current
    ) async throws -> [WakeUpPlan] {
        guard count > 0 else { return [] }

        let preferences = try preferencesStore.load()
        let targetDays = (1...count).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: targetDay.date) ?? targetDay.date
            return TargetDay(date: date, calendar: calendar)
        }

        return try await makePlans(
            for: targetDays,
            preferences: preferences,
            calendar: calendar
        )
    }

    func makeDailyPlans(
        startingAt now: Date = Date(),
        count: Int,
        calendar: Calendar = .current
    ) async throws -> [WakeUpPlan] {
        guard count > 0 else { return [] }

        let preferences = try preferencesStore.load()
        let targetDays = makeTargetDays(
            startingAt: now,
            count: count,
            calendar: calendar
        )

        return try await makePlans(
            for: targetDays,
            preferences: preferences,
            calendar: calendar
        )
    }

    func makeDisplayPlans(
        startingAt now: Date = Date(),
        count: Int,
        calendar: Calendar = .current
    ) async throws -> [WakeUpPlan] {
        let dailyPlans = try await makeDailyPlans(
            startingAt: now,
            count: count,
            calendar: calendar
        )

        return displayPlans(from: dailyPlans, now: now)
    }

    func displayPlans(
        from dailyPlans: [WakeUpPlan],
        now: Date = Date()
    ) -> [WakeUpPlan] {
        dailyPlans.filter { plan in
            plan.reason != .disabled
                && plan.reason != .inactiveDay
                && plan.reason != .systemDisabled
                && plan.reason != .noSchedule
                && plan.calculatedWakeTime > now
        }
    }

    private func makePlan(
        targetDay: TargetDay,
        preferences: AlarmPreferences,
        calendar: Calendar = .current
    ) async throws -> WakeUpPlan {
        let plans = try await makePlans(
            for: [targetDay],
            preferences: preferences,
            calendar: calendar
        )

        return plans[0]
    }

    private func makePlans(
        for targetDays: [TargetDay],
        preferences: AlarmPreferences,
        calendar: Calendar
    ) async throws -> [WakeUpPlan] {
        guard !targetDays.isEmpty else { return [] }

        let eventsByDay = try await loadEventsByDay(
            for: targetDays,
            calendar: calendar
        )

        return targetDays.map { targetDay in
            calculator.calculate(
                events: eventsByDay[targetDay.date] ?? [],
                preferences: preferences,
                targetDay: targetDay,
                calendar: calendar
            )
        }
    }

    private func loadEventsByDay(
        for targetDays: [TargetDay],
        calendar: Calendar
    ) async throws -> [Date: [ParsedEvent]] {
        guard let firstDay = targetDays.first,
              let lastDay = targetDays.last else {
            return [:]
        }

        let interval = DateInterval(
            start: firstDay.interval(calendar: calendar).start,
            end: lastDay.interval(calendar: calendar).end
        )
        let events = try await calendarProvider.events(
            in: interval,
            calendar: calendar
        )

        return Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.startDate)
        }
        .mapValues { events in
            events.sorted { $0.startDate < $1.startDate }
        }
    }

    private func makeTargetDays(
        startingAt now: Date,
        count: Int,
        calendar: Calendar
    ) -> [TargetDay] {
        (0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
            return TargetDay(date: date, calendar: calendar)
        }
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
