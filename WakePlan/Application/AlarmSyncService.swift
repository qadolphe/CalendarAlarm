import Foundation

enum AlarmScheduleStatus: Equatable {
    case notScheduled
    case scheduled(ScheduledAlarmRecord)
    case needsPermission
    case disabled
    case failed(String)
}

final class AlarmSyncService {
    private let alarmScheduler: AlarmScheduling
    private let alarmStore: ScheduledAlarmStoring

    init(
        alarmScheduler: AlarmScheduling,
        alarmStore: ScheduledAlarmStoring
    ) {
        self.alarmScheduler = alarmScheduler
        self.alarmStore = alarmStore
    }

    func sync(plan: WakeUpPlan) async throws -> AlarmScheduleStatus {
        let now = Date()
        var existingRecord = try alarmStore.load()

        if let record = existingRecord, record.isExpired(at: now) {
            do {
                try alarmStore.clear()
                existingRecord = nil
            } catch {
                return .failed("Couldn't clear stale alarm record: \(record.debugSummary). \(error.localizedDescription)")
            }
        }

        if let unscheduledStatus = statusForPlanWithoutManagedAlarm(plan) {
            guard let existingRecord else {
                return unscheduledStatus
            }

            do {
                try await alarmScheduler.cancel(nativeAlarmID: existingRecord.nativeAlarmID)
                try alarmStore.clear()
            } catch {
                return .failed("Couldn't remove previous alarm: \(existingRecord.debugSummary). \(error.localizedDescription)")
            }

            return unscheduledStatus
        }

        if let existingRecord, existingRecord.planID == plan.id {
            return .scheduled(existingRecord)
        }

        if let existingRecord {
            do {
                try await alarmScheduler.cancel(nativeAlarmID: existingRecord.nativeAlarmID)
                try alarmStore.clear()
            } catch {
                return .failed("Couldn't replace previous alarm: \(existingRecord.debugSummary). \(error.localizedDescription)")
            }
        }

        guard await alarmScheduler.authorizationState() == .authorized else {
            return .needsPermission
        }

        do {
            let record = try await alarmScheduler.schedule(plan: plan)
            try alarmStore.save(record)
            return .scheduled(record)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

#if DEBUG
    func scheduleTestAlarm(
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> AlarmScheduleStatus {
        guard await alarmScheduler.authorizationState() == .authorized else {
            return .needsPermission
        }

        do {
            let plan = makeTestAlarmPlan(now: now, calendar: calendar)
            let record = try await alarmScheduler.schedule(plan: plan)
            return .scheduled(record)
        } catch {
            return .failed(error.localizedDescription)
        }
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
            alarmSettings: .default,
            isFallback: false,
            reason: .manualOverride,
            appliedRuleName: nil,
            matchedRuleNames: []
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
#endif
}

private extension AlarmSyncService {
    func statusForPlanWithoutManagedAlarm(_ plan: WakeUpPlan) -> AlarmScheduleStatus? {
        switch plan.reason {
        case .noSchedule:
            return .notScheduled
        case .disabled, .systemDisabled, .inactiveDay:
            return .disabled
        case .event, .fallback, .authorizationMissing, .manualOverride:
            return nil
        }
    }
}
