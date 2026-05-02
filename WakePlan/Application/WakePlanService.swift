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
        let events = try await calendarReader.events(
            for: targetDay,
            selectedCalendarIDs: preferences.selectedCalendarIDs
        )

        return calculator.calculate(
            events: events,
            preferences: preferences,
            targetDay: targetDay
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
