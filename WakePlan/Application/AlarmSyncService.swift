import Foundation

final class AlarmSyncService {
    private let calendarReader: CalendarReading
    private let alarmScheduler: AlarmScheduling
    private let preferencesStore: PreferencesStoring
    private let alarmStore: ScheduledAlarmStoring
    private let calculator: WakePlanCalculator

    init(
        calendarReader: CalendarReading,
        alarmScheduler: AlarmScheduling,
        preferencesStore: PreferencesStoring,
        alarmStore: ScheduledAlarmStoring,
        calculator: WakePlanCalculator = WakePlanCalculator()
    ) {
        self.calendarReader = calendarReader
        self.alarmScheduler = alarmScheduler
        self.preferencesStore = preferencesStore
        self.alarmStore = alarmStore
        self.calculator = calculator
    }

    func recalculateAndSyncAlarm(targetDay: TargetDay = .tomorrow()) async throws -> WakeUpPlan {
        let preferences = try preferencesStore.load()

        let events = try await calendarReader.events(
            for: targetDay,
            selectedCalendarIDs: preferences.selectedCalendarIDs
        )

        let plan = calculator.calculate(
            events: events,
            preferences: preferences,
            targetDay: targetDay
        )

        let existingRecord = try alarmStore.load()

        if let existingRecord, existingRecord.planID == plan.id {
            return plan
        }

        if let existingRecord {
            try await alarmScheduler.cancel(nativeAlarmID: existingRecord.nativeAlarmID)
            try alarmStore.clear()
        }

        guard preferences.isEnabled, plan.reason != .disabled else {
            return plan
        }

        let alarmAuthorization = try await resolvedAlarmAuthorization()

        guard alarmAuthorization == .authorized else {
            return WakeUpPlan(
                id: plan.id,
                targetDay: plan.targetDay,
                targetEvent: plan.targetEvent,
                calculatedWakeTime: plan.calculatedWakeTime,
                eventStartTime: plan.eventStartTime,
                prepTime: plan.prepTime,
                commuteTime: plan.commuteTime,
                isFallback: plan.isFallback,
                reason: .authorizationMissing
            )
        }

        let record = try await alarmScheduler.schedule(plan: plan)
        try alarmStore.save(record)

        return plan
    }

    func scheduleTestAlarm(
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> WakeUpPlan {
        let plan = makeTestAlarmPlan(now: now, calendar: calendar)
        let alarmAuthorization = try await resolvedAlarmAuthorization()

        guard alarmAuthorization == .authorized else {
            return WakeUpPlan(
                id: plan.id,
                targetDay: plan.targetDay,
                targetEvent: plan.targetEvent,
                calculatedWakeTime: plan.calculatedWakeTime,
                eventStartTime: plan.eventStartTime,
                prepTime: plan.prepTime,
                commuteTime: plan.commuteTime,
                isFallback: plan.isFallback,
                reason: .authorizationMissing
            )
        }

        _ = try await alarmScheduler.schedule(plan: plan)
        return plan
    }

    private func resolvedAlarmAuthorization() async throws -> AlarmAuthorizationState {
        let currentState = await alarmScheduler.authorizationState()

        guard currentState == .notDetermined else {
            return currentState
        }

        return try await alarmScheduler.requestAuthorization()
    }

    private func makeTestAlarmPlan(
        now: Date,
        calendar: Calendar
    ) -> WakeUpPlan {
        let wakeTime = nextMinute(after: now, calendar: calendar)

        return WakeUpPlan(
            id: WakePlanID(rawValue: "test-\(Int(wakeTime.timeIntervalSince1970))"),
            targetDay: TargetDay(date: wakeTime, calendar: calendar),
            targetEvent: nil,
            calculatedWakeTime: wakeTime,
            eventStartTime: nil,
            prepTime: Minutes(0),
            commuteTime: Minutes(0),
            isFallback: false,
            reason: .manualOverride
        )
    }

    private func nextMinute(
        after date: Date,
        calendar: Calendar
    ) -> Date {
        let minuteComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let startOfMinute = calendar.date(from: minuteComponents) ?? date

        return calendar.date(byAdding: .minute, value: 1, to: startOfMinute)
            ?? date.addingTimeInterval(60)
    }
}
