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
    let dailyPlans: [WakeUpPlan]
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
    private let widgetSnapshotStore: NextAlarmWidgetSnapshotStoring?
    private let backgroundRefreshScheduler: BackgroundAlarmRefreshScheduling?
    private let staleSyncReminderScheduler: StaleSyncReminderScheduling?
    private let planningWindowCount: Int

    init(
        wakePlanService: WakePlanService,
        permissionService: PermissionService,
        alarmSyncService: AlarmSyncService,
        resultStore: WakePlanRefreshResultStoring? = nil,
        widgetSnapshotStore: NextAlarmWidgetSnapshotStoring? = nil,
        backgroundRefreshScheduler: BackgroundAlarmRefreshScheduling? = nil,
        staleSyncReminderScheduler: StaleSyncReminderScheduling? = nil,
        planningWindowCount: Int = AppConfiguration.managedAlarmPlanningCount
    ) {
        self.wakePlanService = wakePlanService
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
    ) async throws -> WakePlanRefreshOutcome {
        _ = reason

        do {
            let permissions = await permissionService.currentStatus()
            let accounts = try await wakePlanService.accounts()
            let calendars = try await wakePlanService.calendars()
            let dashboardStart = startOfDashboardWeek(containing: now, calendar: calendar)
            let dailyPlans = try await wakePlanService.makeDailyPlans(
                startingAt: dashboardStart,
                count: AppConfiguration.dashboardPlanningCount,
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
            let displayPlans = Array(
                wakePlanService.displayPlans(from: dailyPlans, now: now)
                    .prefix(planningWindowCount)
            )
            let syncResult = try await alarmSyncService.sync(plans: displayPlans)

            let snapshot = WakePlanRefreshSnapshot(
                permissions: permissions,
                accounts: accounts,
                calendars: calendars,
                tomorrowPlan: tomorrowPlan,
                dailyPlans: dailyPlans,
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
            publishWidgetSnapshot(from: snapshot, syncedAt: now)
            await staleSyncReminderScheduler?.updateReminder(for: result)
            await backgroundRefreshScheduler?.scheduleNextRefresh(after: now)

            return WakePlanRefreshOutcome(snapshot: snapshot, result: result)
        } catch {
            publishStaleWidgetSnapshot(lastUpdatedAt: now, detailText: error.localizedDescription)
            throw error
        }
    }
}

private extension WakePlanRefreshService {
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
        from snapshot: WakePlanRefreshSnapshot,
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
        from snapshot: WakePlanRefreshSnapshot,
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
