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
        let existingRecord = try alarmStore.load()

        if plan.reason == .disabled || plan.reason == .systemDisabled {
            if let existingRecord {
                do {
                    try await alarmScheduler.cancel(nativeAlarmID: existingRecord.nativeAlarmID)
                    try alarmStore.clear()
                } catch {
                    return .failed(error.localizedDescription)
                }
            }

            return plan.reason == .systemDisabled ? .disabled : .disabled
        }

        if let existingRecord, existingRecord.planID == plan.id {
            return .scheduled(existingRecord)
        }

        if let existingRecord {
            do {
                try await alarmScheduler.cancel(nativeAlarmID: existingRecord.nativeAlarmID)
                try alarmStore.clear()
            } catch {
                return .failed(error.localizedDescription)
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
