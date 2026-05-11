import Foundation

enum RefreshReason: String, Codable, Sendable {
    case appOpen
    case manual
    case background
    case shortcut
}

struct WakePlanRefreshResult: Codable, Equatable, Sendable {
    let syncedAt: Date
    let plannedDays: Int
    let scheduledCount: Int
    let canceledCount: Int
    let failedCount: Int
}

struct WakePlanRefreshSnapshot: Equatable, Sendable {
    let permissions: PermissionSnapshot
    let accounts: [ConnectedCalendarAccount]
    let calendars: [CalendarSource]
    let tomorrowPlan: WakeUpPlan
    let displayPlans: [WakeUpPlan]
    let syncResult: AlarmSyncResult
}

struct WakePlanRefreshOutcome: Equatable, Sendable {
    let snapshot: WakePlanRefreshSnapshot
    let result: WakePlanRefreshResult
}

protocol WakePlanRefreshResultStoring {
    func load() throws -> WakePlanRefreshResult?
    func save(_ result: WakePlanRefreshResult) throws
    func clear() throws
}

protocol BackgroundAlarmRefreshScheduling {
    func scheduleNextRefresh(after date: Date) async
}

protocol StaleSyncReminderScheduling {
    func updateReminder(for result: WakePlanRefreshResult) async
}

actor WakePlanRefreshService {
    private let wakePlanService: WakePlanService
    private let permissionService: PermissionService
    private let alarmSyncService: AlarmSyncService
    private let resultStore: WakePlanRefreshResultStoring?
    private let backgroundRefreshScheduler: BackgroundAlarmRefreshScheduling?
    private let staleSyncReminderScheduler: StaleSyncReminderScheduling?
    private let planningWindowCount: Int

    init(
        wakePlanService: WakePlanService,
        permissionService: PermissionService,
        alarmSyncService: AlarmSyncService,
        resultStore: WakePlanRefreshResultStoring? = nil,
        backgroundRefreshScheduler: BackgroundAlarmRefreshScheduling? = nil,
        staleSyncReminderScheduler: StaleSyncReminderScheduling? = nil,
        planningWindowCount: Int = AppConfiguration.managedAlarmPlanningCount
    ) {
        self.wakePlanService = wakePlanService
        self.permissionService = permissionService
        self.alarmSyncService = alarmSyncService
        self.resultStore = resultStore
        self.backgroundRefreshScheduler = backgroundRefreshScheduler
        self.staleSyncReminderScheduler = staleSyncReminderScheduler
        self.planningWindowCount = planningWindowCount
    }

    func refreshAndSync(
        reason: RefreshReason,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> WakePlanRefreshOutcome {
        _ = reason

        let permissions = await permissionService.currentStatus()
        let accounts = try await wakePlanService.accounts()
        let calendars = try await wakePlanService.calendars()
        let dailyPlans = try await wakePlanService.makeDailyPlans(
            startingAt: now,
            count: planningWindowCount,
            calendar: calendar
        )
        let tomorrowTargetDay = TargetDay.tomorrow(from: now, calendar: calendar)
        let tomorrowPlan: WakeUpPlan

        if let plannedTomorrow = dailyPlans.first(where: { $0.targetDay == tomorrowTargetDay }) {
            tomorrowPlan = plannedTomorrow
        } else {
            tomorrowPlan = try await wakePlanService.makePlan(
                targetDay: tomorrowTargetDay,
                calendar: calendar
            )
        }
        let displayPlans = wakePlanService.displayPlans(from: dailyPlans, now: now)
        let syncResult = try await alarmSyncService.sync(plans: displayPlans)

        let snapshot = WakePlanRefreshSnapshot(
            permissions: permissions,
            accounts: accounts,
            calendars: calendars,
            tomorrowPlan: tomorrowPlan,
            displayPlans: displayPlans,
            syncResult: syncResult
        )
        let result = WakePlanRefreshResult(
            syncedAt: now,
            plannedDays: displayPlans.count,
            scheduledCount: syncResult.scheduledCount,
            canceledCount: syncResult.canceledCount,
            failedCount: syncResult.failedCount
        )

        try? resultStore?.save(result)
        await staleSyncReminderScheduler?.updateReminder(for: result)
        await backgroundRefreshScheduler?.scheduleNextRefresh(after: now)

        return WakePlanRefreshOutcome(snapshot: snapshot, result: result)
    }
}

final class UserDefaultsWakePlanRefreshResultStore: WakePlanRefreshResultStoring {
    private let key = "wakeplan.lastRefreshResult"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> WakePlanRefreshResult? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try decoder.decode(WakePlanRefreshResult.self, from: data)
    }

    func save(_ result: WakePlanRefreshResult) throws {
        let data = try encoder.encode(result)
        defaults.set(data, forKey: key)
    }

    func clear() throws {
        defaults.removeObject(forKey: key)
    }
}
