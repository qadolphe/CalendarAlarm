import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum RefreshReason: String, Codable, Sendable {
    case appOpen
    case manual
    case background
    case shortcut
}

struct EarlyOtterRefreshResult: Codable, Equatable, Sendable {
    let syncedAt: Date
    let plannedDays: Int
    let scheduledCount: Int
    let canceledCount: Int
    let failedCount: Int
}

struct EarlyOtterRefreshSnapshot: Equatable, Sendable {
    let permissions: PermissionSnapshot
    let accounts: [ConnectedCalendarAccount]
    let calendars: [CalendarSource]
    let tomorrowPlan: WakeUpPlan
    let dailyPlans: [WakeUpPlan]
    let displayPlans: [WakeUpPlan]
    let syncResult: AlarmSyncResult
}

struct EarlyOtterRefreshOutcome: Equatable, Sendable {
    let snapshot: EarlyOtterRefreshSnapshot
    let result: EarlyOtterRefreshResult
}

protocol EarlyOtterRefreshResultStoring {
    func load() throws -> EarlyOtterRefreshResult?
    func save(_ result: EarlyOtterRefreshResult) throws
    func clear() throws
}

protocol BackgroundAlarmRefreshScheduling {
    func scheduleNextRefresh(after date: Date) async
}

protocol StaleSyncReminderScheduling {
    func updateReminder(for result: EarlyOtterRefreshResult) async
}

actor EarlyOtterRefreshService {
    private let earlyOtterService: EarlyOtterService
    private let permissionService: PermissionService
    private let alarmSyncService: AlarmSyncService
    private let resultStore: EarlyOtterRefreshResultStoring?
    private let widgetSnapshotStore: NextAlarmWidgetSnapshotStoring?
    private let backgroundRefreshScheduler: BackgroundAlarmRefreshScheduling?
    private let staleSyncReminderScheduler: StaleSyncReminderScheduling?
    private let planningWindowCount: Int

    init(
        earlyOtterService: EarlyOtterService,
        permissionService: PermissionService,
        alarmSyncService: AlarmSyncService,
        resultStore: EarlyOtterRefreshResultStoring? = nil,
        widgetSnapshotStore: NextAlarmWidgetSnapshotStoring? = nil,
        backgroundRefreshScheduler: BackgroundAlarmRefreshScheduling? = nil,
        staleSyncReminderScheduler: StaleSyncReminderScheduling? = nil,
        planningWindowCount: Int = AppConfiguration.managedAlarmPlanningCount
    ) {
        self.earlyOtterService = earlyOtterService
        self.permissionService = permissionService
        self.alarmSyncService = alarmSyncService
        self.resultStore = resultStore
        self.widgetSnapshotStore = widgetSnapshotStore
        self.backgroundRefreshScheduler = backgroundRefreshScheduler
        self.staleSyncReminderScheduler = staleSyncReminderScheduler
        self.planningWindowCount = planningWindowCount
    }

    func refreshAndSync(
        reason: RefreshReason,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> EarlyOtterRefreshOutcome {
        _ = reason

        do {
            let permissions = await permissionService.currentStatus()
            let accounts = try await earlyOtterService.accounts()
            let calendars = try await earlyOtterService.calendars()
            let dashboardStart = startOfDashboardWeek(containing: now, calendar: calendar)
            let dailyPlans = try await earlyOtterService.makeDailyPlans(
                startingAt: dashboardStart,
                count: AppConfiguration.dashboardPlanningCount,
                calendar: calendar
            )
            let tomorrowTargetDay = TargetDay.tomorrow(from: now, calendar: calendar)
            let tomorrowPlan: WakeUpPlan

            if let plannedTomorrow = dailyPlans.first(where: { $0.targetDay == tomorrowTargetDay }) {
                tomorrowPlan = plannedTomorrow
            } else {
                tomorrowPlan = try await earlyOtterService.makePlan(
                    targetDay: tomorrowTargetDay,
                    calendar: calendar
                )
            }
            let displayPlans = Array(
                earlyOtterService.displayPlans(from: dailyPlans, now: now)
                    .prefix(planningWindowCount)
            )
            let syncResult = try await alarmSyncService.sync(plans: displayPlans)

            let snapshot = EarlyOtterRefreshSnapshot(
                permissions: permissions,
                accounts: accounts,
                calendars: calendars,
                tomorrowPlan: tomorrowPlan,
                dailyPlans: dailyPlans,
                displayPlans: displayPlans,
                syncResult: syncResult
            )
            let result = EarlyOtterRefreshResult(
                syncedAt: now,
                plannedDays: displayPlans.count,
                scheduledCount: syncResult.scheduledCount,
                canceledCount: syncResult.canceledCount,
                failedCount: syncResult.failedCount
            )

            try? resultStore?.save(result)
            publishWidgetSnapshot(from: snapshot, syncedAt: now)
            await staleSyncReminderScheduler?.updateReminder(for: result)
            await backgroundRefreshScheduler?.scheduleNextRefresh(after: now)

            return EarlyOtterRefreshOutcome(snapshot: snapshot, result: result)
        } catch {
            publishStaleWidgetSnapshot(lastUpdatedAt: now, detailText: error.localizedDescription)
            throw error
        }
    }
}

private extension EarlyOtterRefreshService {
    func startOfDashboardWeek(
        containing date: Date,
        calendar: Calendar
    ) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromSunday = weekday - 1

        return calendar.date(byAdding: .day, value: -daysFromSunday, to: startOfDay)
            ?? startOfDay
    }

    func publishWidgetSnapshot(
        from snapshot: EarlyOtterRefreshSnapshot,
        syncedAt: Date
    ) {
        let widgetSnapshot = makeWidgetSnapshot(from: snapshot, syncedAt: syncedAt)
        try? widgetSnapshotStore?.save(widgetSnapshot)
        reloadWidgetTimelines()
    }

    func publishStaleWidgetSnapshot(
        lastUpdatedAt: Date,
        detailText: String
    ) {
        guard let widgetSnapshotStore else {
            return
        }

        let previousSnapshot = try? widgetSnapshotStore.load()
        let staleSnapshot = NextAlarmWidgetSnapshot.stale(
            nextAlarmDate: previousSnapshot?.nextAlarmDate,
            eventTitle: previousSnapshot?.eventTitle,
            context: previousSnapshot?.context,
            detailText: detailText,
            lastUpdatedAt: lastUpdatedAt
        )

        try? widgetSnapshotStore.save(staleSnapshot)
        reloadWidgetTimelines()
    }

    func makeWidgetSnapshot(
        from snapshot: EarlyOtterRefreshSnapshot,
        syncedAt: Date
    ) -> NextAlarmWidgetSnapshot {
        let plansByID = Dictionary(uniqueKeysWithValues: snapshot.displayPlans.map { ($0.id, $0) })

        if let nextRecord = snapshot.syncResult.records.first {
            let plan = plansByID[nextRecord.planID]

            return .scheduled(
                nextAlarmDate: nextRecord.scheduledWakeTime,
                eventTitle: plan?.targetEvent?.title,
                context: widgetContext(for: plan),
                detailText: nil,
                lastUpdatedAt: syncedAt
            )
        }

        return .empty(
            detailText: widgetEmptyDetail(for: snapshot.permissions),
            lastUpdatedAt: syncedAt
        )
    }

    func widgetContext(for plan: WakeUpPlan?) -> String? {
        guard let plan else {
            return nil
        }

        if let event = plan.targetEvent {
            return event.startDate.formatted(date: .omitted, time: .shortened)
        }

        return "Fixed alarm"
    }

    func widgetEmptyDetail(for permissions: PermissionSnapshot) -> String {
        if permissions.calendar == .denied || permissions.calendar == .restricted {
            return "Calendar access needed"
        }

        if permissions.alarm == .denied || permissions.alarm == .notDetermined {
            return "Alarm access needed"
        }

        return "No upcoming alarms."
    }

    func reloadWidgetTimelines() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfiguration.nextAlarmWidgetKind)
#endif
    }
}

final class UserDefaultsEarlyOtterRefreshResultStore: EarlyOtterRefreshResultStoring {
    private let key = "wakeplan.lastRefreshResult"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> EarlyOtterRefreshResult? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try decoder.decode(EarlyOtterRefreshResult.self, from: data)
    }

    func save(_ result: EarlyOtterRefreshResult) throws {
        let data = try encoder.encode(result)
        defaults.set(data, forKey: key)
    }

    func clear() throws {
        defaults.removeObject(forKey: key)
    }
}
