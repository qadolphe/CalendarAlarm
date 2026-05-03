import Foundation
import Observation

struct WakePlanViewState: Equatable {
    let plan: WakeUpPlan
    let alarmStatus: AlarmScheduleStatus
}

enum DashboardState: Equatable {
    case loading
    case needsCalendarPermission
    case needsAlarmPermission(WakePlanViewState)
    case ready(WakePlanViewState)
    case emptyFallback(WakePlanViewState)
    case error(String)
}

@MainActor
@Observable
final class AppState {
    var preferences: AlarmPreferences = .default
    var calendars: [CalendarSource] = []
    var accounts: [ConnectedCalendarAccount] = []
    var permissions: PermissionSnapshot = .initial
    var dashboardState: DashboardState = .loading
    var upcomingPlans: [WakeUpPlan] = []
    var noticeMessage: String?

    private let accountStore: AccountStoring
    private let accountService: AccountService
    private let preferencesStore: PreferencesStoring
    private let wakePlanService: WakePlanService
    private let permissionService: PermissionService
    private let alarmSyncService: AlarmSyncService
    private var hasLoaded = false

    var hasLoadedInitialState: Bool {
        hasLoaded
    }

    var errorMessage: String? {
        guard case let .error(message) = dashboardState else { return nil }
        return message
    }

    init(
        accountStore: AccountStoring,
        accountService: AccountService,
        preferencesStore: PreferencesStoring,
        wakePlanService: WakePlanService,
        permissionService: PermissionService,
        alarmSyncService: AlarmSyncService
    ) {
        self.accountStore = accountStore
        self.accountService = accountService
        self.preferencesStore = preferencesStore
        self.wakePlanService = wakePlanService
        self.permissionService = permissionService
        self.alarmSyncService = alarmSyncService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        hasLoaded = true
        dashboardState = .loading
        noticeMessage = nil

        do {
            preferences = try preferencesStore.load()
            try await refreshDashboard()
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func updatePreferences(_ newPreferences: AlarmPreferences) async {
        noticeMessage = nil

        do {
            preferences = newPreferences
            try preferencesStore.save(newPreferences)
            dashboardState = .loading
            try await refreshDashboard()
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func refreshPlan() async {
        noticeMessage = nil

        do {
            dashboardState = .loading
            try await refreshDashboard()
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func refreshOnAppOpen() async {
        guard hasLoaded else { return }
        guard dashboardState != .loading else { return }

        noticeMessage = nil

        do {
            try await refreshDashboard()
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func requestCalendarAccess() async {
        noticeMessage = nil

        do {
            _ = try await permissionService.requestCalendarAccess()
            await load()
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func requestAlarmAccess() async {
        noticeMessage = nil

        do {
            let requestedState = try await permissionService.requestAlarmAccess()
            dashboardState = .loading
            try await refreshDashboard()

            if requestedState == .notDetermined, permissions.alarm == .notDetermined {
                noticeMessage = "Alarm access is still pending."
            }
        } catch {
            dashboardState = .error(format(error))
        }
    }

#if DEBUG
    func scheduleTestAlarm() async {
        noticeMessage = nil

        do {
            let status = try await alarmSyncService.scheduleTestAlarm()

            switch status {
            case .needsPermission:
                noticeMessage = AppConfiguration.alarmPermissionExplanation
            case .scheduled(let record):
                noticeMessage = AppConfiguration.testAlarmScheduledMessage(
                    for: record.scheduledWakeTime
                )
            case .failed(let message):
                dashboardState = .error(message)
            case .disabled, .notScheduled:
                noticeMessage = "Test alarm was not scheduled."
            }
        } catch {
            dashboardState = .error(format(error))
        }
    }
#endif

    func toggleCalendarSelection(id: String) async {
        let allIDs = Set(calendars.map(\.id))
        guard !allIDs.isEmpty else { return }

        var nextPreferences = preferences

        if nextPreferences.selectedCalendarIDs.isEmpty {
            nextPreferences.selectedCalendarIDs = allIDs
        }

        if nextPreferences.selectedCalendarIDs.contains(id) {
            guard nextPreferences.selectedCalendarIDs.count > 1 else { return }
            nextPreferences.selectedCalendarIDs.remove(id)
        } else {
            nextPreferences.selectedCalendarIDs.insert(id)
        }

        if nextPreferences.selectedCalendarIDs == allIDs {
            nextPreferences.selectedCalendarIDs = []
        }

        await updatePreferences(nextPreferences)
    }

    func selectAllCalendars() async {
        var nextPreferences = preferences
        nextPreferences.selectedCalendarIDs = []
        await updatePreferences(nextPreferences)
    }

    func addGoogleAccount() async {
        noticeMessage = nil

        do {
            accounts = try await accountService.connectGoogleAccount()
            noticeMessage = "Google account connected."
            try await refreshDashboard()
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func setAccountEnabled(id: CalendarAccountID, isEnabled: Bool) async {
        noticeMessage = nil

        do {
            var stored = try accountStore.load()
            if let index = stored.firstIndex(where: { $0.id == id }) {
                stored[index].isEnabled = isEnabled
            } else if id == AppleCalendarProvider.appleAccountID {
                stored.append(ConnectedCalendarAccount(
                    id: id,
                    provider: .apple,
                    displayName: "Apple Calendar",
                    isEnabled: isEnabled
                ))
            } else {
                return
            }
            try accountStore.save(stored)
            try await refreshDashboard()
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func removeAccount(id: CalendarAccountID) async {
        noticeMessage = nil

        do {
            var stored = try accountStore.load()
            stored.removeAll(where: { $0.id == id })
            try accountStore.save(stored)
            try await refreshDashboard()
        } catch {
            dashboardState = .error(format(error))
        }
    }

    private func format(_ error: Error) -> String {
        error.localizedDescription
    }

    private func refreshDashboard(targetDay: TargetDay = .tomorrow()) async throws {
        let now = Date()

        permissions = await permissionService.currentStatus()
        accounts = try await wakePlanService.accounts()

        calendars = try await wakePlanService.calendars()
        let displayPlans = try await wakePlanService.makeDisplayPlans(startingAt: now, count: 4)
        let plan: WakeUpPlan
        if let firstDisplayPlan = displayPlans.first {
            plan = firstDisplayPlan
        } else {
            plan = try await wakePlanService.makePlan(targetDay: TargetDay(date: now))
        }
        upcomingPlans = Array(displayPlans.dropFirst())
        let alarmStatus = try await alarmSyncService.sync(plan: plan)
        let viewState = WakePlanViewState(plan: plan, alarmStatus: alarmStatus)

        if alarmStatus == .needsPermission {
            dashboardState = .needsAlarmPermission(viewState)
            return
        }

        if plan.isFallback
            || plan.reason == .disabled
            || plan.reason == .systemDisabled
            || plan.reason == .inactiveDay
            || plan.reason == .noSchedule {
            dashboardState = .emptyFallback(viewState)
            return
        }

        dashboardState = .ready(viewState)
    }
}
