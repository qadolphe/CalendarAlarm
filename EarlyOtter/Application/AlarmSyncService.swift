import Foundation

enum AlarmScheduleStatus: Equatable, Sendable {
    case notScheduled
    case scheduled(ScheduledAlarmRecord)
    case needsPermission
    case disabled
    case failed(String)
}

struct AlarmSyncResult: Equatable, Sendable {
    let records: [ScheduledAlarmRecord]
    let statusesByPlanID: [WakePlanID: AlarmScheduleStatus]
    let scheduledCount: Int
    let canceledCount: Int
    let failedCount: Int

    func status(for plan: WakeUpPlan) -> AlarmScheduleStatus {
        statusesByPlanID[plan.id] ?? .notScheduled
    }
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
        let result = try await sync(plans: [plan])
        return result.status(for: plan)
    }

    func sync(plans: [WakeUpPlan]) async throws -> AlarmSyncResult {
        await syncLock.acquire()
        defer { syncLock.release() }

        return try await performSync(plans: plans)
    }

    private func performSync(plans: [WakeUpPlan]) async throws -> AlarmSyncResult {
        let existingRecords: [ScheduledAlarmRecord]

        do {
            existingRecords = try loadActiveRecords(now: Date())
        } catch {
            let statuses = Dictionary(
                uniqueKeysWithValues: plans.map {
                    ($0.id, AlarmScheduleStatus.failed(error.localizedDescription))
                }
            )
            return AlarmSyncResult(
                records: [],
                statusesByPlanID: statuses,
                scheduledCount: 0,
                canceledCount: 0,
                failedCount: plans.isEmpty ? 1 : plans.count
            )
        }

        var statusesByPlanID: [WakePlanID: AlarmScheduleStatus] = [:]
        var desiredManagedPlans: [WakeUpPlan] = []

        for plan in plans {
            if let unscheduledStatus = statusForPlanWithoutManagedAlarm(plan) {
                statusesByPlanID[plan.id] = unscheduledStatus
            } else {
                desiredManagedPlans.append(plan)
            }
        }

        let existingByPlanID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.planID, $0) })
        let desiredPlanIDs = Set(desiredManagedPlans.map(\.id))
        var retainedRecords = existingByPlanID.filter { desiredPlanIDs.contains($0.key) }
        var scheduledCount = 0
        var canceledCount = 0
        var failedCount = 0
        var obsoleteRemovalErrors: [String] = []

        for record in existingRecords where !desiredPlanIDs.contains(record.planID) {
            do {
                try await alarmScheduler.cancel(nativeAlarmID: record.nativeAlarmID)
                canceledCount += 1
            } catch {
                failedCount += 1
                obsoleteRemovalErrors.append(error.localizedDescription)
            }
        }

        if !obsoleteRemovalErrors.isEmpty {
            let failureMessage = "Couldn't replace previous alarms. \(obsoleteRemovalErrors.joined(separator: " "))"

            for plan in desiredManagedPlans where retainedRecords[plan.id] == nil {
                statusesByPlanID[plan.id] = .failed(failureMessage)
            }

            let activeRecords = retainedRecords.values.sorted(by: Self.sortRecords)
            try saveRecords(activeRecords)

            return AlarmSyncResult(
                records: activeRecords,
                statusesByPlanID: statusesByPlanID,
                scheduledCount: scheduledCount,
                canceledCount: canceledCount,
                failedCount: failedCount
            )
        }

        let authorizationState = await alarmScheduler.authorizationState()

        for plan in desiredManagedPlans {
            if let existingRecord = retainedRecords[plan.id] {
                statusesByPlanID[plan.id] = .scheduled(existingRecord)
                continue
            }

            guard authorizationState == .authorized else {
                statusesByPlanID[plan.id] = .needsPermission
                continue
            }

            do {
                let record = try await alarmScheduler.schedule(plan: plan)
                retainedRecords[plan.id] = record
                statusesByPlanID[plan.id] = .scheduled(record)
                scheduledCount += 1
            } catch {
                statusesByPlanID[plan.id] = .failed(error.localizedDescription)
                failedCount += 1
            }
        }

        let activeRecords = retainedRecords.values.sorted(by: Self.sortRecords)
        try saveRecords(activeRecords)

        return AlarmSyncResult(
            records: activeRecords,
            statusesByPlanID: statusesByPlanID,
            scheduledCount: scheduledCount,
            canceledCount: canceledCount,
            failedCount: failedCount
        )
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
    static func sortRecords(_ lhs: ScheduledAlarmRecord, _ rhs: ScheduledAlarmRecord) -> Bool {
        if lhs.scheduledWakeTime != rhs.scheduledWakeTime {
            return lhs.scheduledWakeTime < rhs.scheduledWakeTime
        }

        return lhs.planID.rawValue < rhs.planID.rawValue
    }

    func loadActiveRecords(now: Date) throws -> [ScheduledAlarmRecord] {
        let records = try alarmStore.load()
        let activeRecords = records
            .filter { !$0.isExpired(at: now) }
            .sorted(by: Self.sortRecords)

        guard activeRecords.count != records.count else {
            return activeRecords
        }

        do {
            if activeRecords.isEmpty {
                try alarmStore.clear()
            } else {
                try alarmStore.save(activeRecords)
            }
            return activeRecords
        } catch {
            throw AlarmSyncFailure.clearStaleRecord(error)
        }
    }

    func saveRecords(_ records: [ScheduledAlarmRecord]) throws {
        if records.isEmpty {
            try alarmStore.clear()
        } else {
            try alarmStore.save(records)
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
