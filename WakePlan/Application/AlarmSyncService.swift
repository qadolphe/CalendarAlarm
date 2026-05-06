import Foundation

enum AlarmScheduleStatus: Equatable {
    case notScheduled
    case scheduled(ScheduledAlarmRecord)
    case needsPermission
    case disabled
    case failed(String)
}

actor AlarmSyncService {
    private let alarmScheduler: AlarmScheduling
    private let alarmStore: ScheduledAlarmStoring
    private let syncLock = AsyncLock()

    init(
        alarmScheduler: AlarmScheduling,
        alarmStore: ScheduledAlarmStoring
    ) {
        self.alarmScheduler = alarmScheduler
        self.alarmStore = alarmStore
    }

    func sync(plan: WakeUpPlan) async throws -> AlarmScheduleStatus {
        await syncLock.acquire()
        defer { syncLock.release() }

        return try await performSync(plan: plan)
    }

    private func performSync(plan: WakeUpPlan) async throws -> AlarmScheduleStatus {
        let existingRecord: ScheduledAlarmRecord?

        do {
            existingRecord = try loadActiveRecord(now: Date())
        } catch {
            return .failed(error.localizedDescription)
        }

        if let unscheduledStatus = statusForPlanWithoutManagedAlarm(plan) {
            return await removeManagedAlarmIfNeeded(
                existingRecord,
                resultingStatus: unscheduledStatus,
                failurePrefix: "Couldn't remove previous alarm."
            ) ?? unscheduledStatus
        }

        if let existingRecord, existingRecord.planID == plan.id {
            return .scheduled(existingRecord)
        }

        if let replacementFailure = await removeManagedAlarmIfNeeded(
            existingRecord,
            resultingStatus: nil,
            failurePrefix: "Couldn't replace previous alarm."
        ) {
            return replacementFailure
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
    func loadActiveRecord(now: Date) throws -> ScheduledAlarmRecord? {
        guard let record = try alarmStore.load() else {
            return nil
        }

        guard record.isExpired(at: now) else {
            return record
        }

        do {
            try alarmStore.clear()
            return nil
        } catch {
            throw AlarmSyncFailure.clearStaleRecord(error)
        }
    }

    func removeManagedAlarmIfNeeded(
        _ existingRecord: ScheduledAlarmRecord?,
        resultingStatus: AlarmScheduleStatus?,
        failurePrefix: String
    ) async -> AlarmScheduleStatus? {
        guard let existingRecord else {
            return resultingStatus
        }

        do {
            try await alarmScheduler.cancel(nativeAlarmID: existingRecord.nativeAlarmID)
            try alarmStore.clear()
            return resultingStatus
        } catch {
            return .failed("\(failurePrefix) \(error.localizedDescription)")
        }
    }

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

private enum AlarmSyncFailure: LocalizedError {
    case clearStaleRecord(Error)

    var errorDescription: String? {
        switch self {
        case .clearStaleRecord(let error):
            return "Couldn't clear stale alarm record. \(error.localizedDescription)"
        }
    }
}

private final class AsyncLock: @unchecked Sendable {
    private let stateLock = NSLock()
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        await withCheckedContinuation { continuation in
            stateLock.lock()

            if isLocked {
                waiters.append(continuation)
                stateLock.unlock()
                return
            }

            isLocked = true
            stateLock.unlock()
            continuation.resume()
        }
    }

    func release() {
        stateLock.lock()

        guard !waiters.isEmpty else {
            isLocked = false
            stateLock.unlock()
            return
        }

        let waiter = waiters.removeFirst()
        stateLock.unlock()
        waiter.resume()
    }
}
