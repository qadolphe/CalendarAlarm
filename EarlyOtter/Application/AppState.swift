import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

struct EarlyOtterViewState: Equatable {
    let plan: WakeUpPlan
    let alarmStatus: AlarmScheduleStatus
}

enum DashboardState: Equatable {
    case loading
    case needsCalendarPermission
    case needsAlarmPermission(EarlyOtterViewState)
    case ready(EarlyOtterViewState)
    case emptyFallback(EarlyOtterViewState)
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
    var tomorrowPlanPreview: WakeUpPlan?
    var dailyPlans: [WakeUpPlan] = []
    var displayPlans: [WakeUpPlan] = []
    var upcomingPlans: [WakeUpPlan] = []
    var alarmStatusesByPlanID: [EarlyOtterID: AlarmScheduleStatus] = [:]
    var noticeMessage: String?
    var settingsAlertMessage: String?

    private let accountStore: AccountStoring
    private let accountService: AccountService
    private let preferencesStore: PreferencesStoring
    private let permissionService: PermissionService
    private let alarmSyncService: AlarmSyncService
    private let refreshService: EarlyOtterRefreshService
    private let openAppSettings: @MainActor () -> Void
    private var hasLoaded = false
    private var refreshGeneration = 0

    var hasLoadedInitialState: Bool {
        hasLoaded
    }

    var hasAccessibleCalendars: Bool {
        !calendars.isEmpty
    }

    var shouldShowCalendarAccessPrompt: Bool {
        !hasAccessibleCalendars && permissions.calendar != .authorized
    }

    var errorMessage: String? {
        guard case let .error(message) = dashboardState else { return nil }
        return message
    }

    init(
        accountStore: AccountStoring,
        accountService: AccountService,
        preferencesStore: PreferencesStoring,
        permissionService: PermissionService,
        alarmSyncService: AlarmSyncService,
        refreshService: EarlyOtterRefreshService,
        openAppSettings: @escaping @MainActor () -> Void = { AppState.defaultOpenAppSettings() }
    ) {
        self.accountStore = accountStore
        self.accountService = accountService
        self.preferencesStore = preferencesStore
        self.permissionService = permissionService
        self.alarmSyncService = alarmSyncService
        self.refreshService = refreshService
        self.openAppSettings = openAppSettings
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        hasLoaded = true
        dashboardState = .loading
        tomorrowPlanPreview = nil
        dailyPlans = []
        displayPlans = []
        upcomingPlans = []
        alarmStatusesByPlanID = [:]
        noticeMessage = nil
        settingsAlertMessage = nil

        do {
            preferences = try preferencesStore.load()
            try await refreshDashboard(reason: .appOpen)
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func updatePreferences(_ newPreferences: AlarmPreferences) async {
        noticeMessage = nil
        settingsAlertMessage = nil

        do {
            preferences = newPreferences
            try preferencesStore.save(newPreferences)
            dashboardState = .loading
            try await refreshDashboard(reason: .manual)
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func refreshPlan() async {
        let previousDashboardState = dashboardState
        noticeMessage = nil
        settingsAlertMessage = nil

        do {
            try await refreshDashboard(reason: .manual)
        } catch is CancellationError {
            dashboardState = previousDashboardState
        } catch {
            dashboardState = previousDashboardState
        }
    }

    func refreshOnAppOpen() async {
        guard hasLoaded else { return }

        let previousDashboardState = dashboardState
        noticeMessage = nil
        settingsAlertMessage = nil

        do {
            try await refreshDashboard(reason: .appOpen)
        } catch is CancellationError {
            dashboardState = previousDashboardState
        } catch {
            dashboardState = previousDashboardState
        }
    }

    func refreshPermissions() async {
        permissions = await permissionService.currentStatus()
    }

    func requestCalendarAccess() async {
        noticeMessage = nil
        settingsAlertMessage = nil

        do {
            let currentPermissions = await permissionService.currentStatus()
            permissions = currentPermissions

            if currentPermissions.calendar == .denied || currentPermissions.calendar == .restricted {
                showSettingsNotice("Calendar access was previously denied. Enable it in Settings to connect Apple Calendar.")
                return
            }

            let requestedState = try await permissionService.requestCalendarAccess()
            await refreshPermissions()

            if requestedState != .authorized {
                noticeMessage = "Calendar access is still needed to use Apple Calendar."
            }

            await load()
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func requestAlarmAccess() async {
        noticeMessage = nil
        settingsAlertMessage = nil

        do {
            let currentPermissions = await permissionService.currentStatus()
            permissions = currentPermissions

            if currentPermissions.alarm == .denied {
                showSettingsNotice("Alarm access was previously denied. Enable it in Settings to schedule wake-up alarms.")
                return
            }

            let requestedState = try await permissionService.requestAlarmAccess()
            await refreshPermissions()
            dashboardState = .loading
            try await refreshDashboard(reason: .manual)

            if requestedState == .notDetermined, permissions.alarm == .notDetermined {
                noticeMessage = "Alarm access is still pending."
            } else if requestedState == .denied {
                noticeMessage = "Alarm access is still needed to schedule wake-up alarms."
            }
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func requestNotificationAccess() async {
        noticeMessage = nil
        settingsAlertMessage = nil

        do {
            let currentPermissions = await permissionService.currentStatus()
            permissions = currentPermissions

            if currentPermissions.notification == .denied {
                showSettingsNotice("Notification access was previously denied. Enable it in Settings.")
                return
            }

            let requestedState = try await permissionService.requestNotificationAccess()
            await refreshPermissions()

            if requestedState == .notDetermined, permissions.notification == .notDetermined {
                noticeMessage = "Notification access is still pending."
            } else if requestedState == .denied {
                noticeMessage = "Notification access is still needed."
            }
        } catch {
            dashboardState = .error(format(error))
        }
    }

#if DEBUG
    func scheduleTestAlarm() async {
        noticeMessage = nil
        settingsAlertMessage = nil

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
        settingsAlertMessage = nil

        do {
            accounts = try await accountService.connectGoogleAccount()
            try await refreshDashboard(reason: .manual)
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func connectAppleCalendar() async {
        noticeMessage = nil
        settingsAlertMessage = nil

        do {
            let currentPermissions = await permissionService.currentStatus()
            permissions = currentPermissions

            let authorizationState: CalendarAuthorizationState
            if currentPermissions.calendar == .authorized {
                authorizationState = .authorized
            } else if currentPermissions.calendar == .denied || currentPermissions.calendar == .restricted {
                showSettingsNotice("Calendar access was previously denied. Enable it in Settings to connect Apple Calendar.")
                return
            } else {
                authorizationState = try await permissionService.requestCalendarAccess()
                await refreshPermissions()
            }

            guard authorizationState == .authorized else {
                if authorizationState == .denied {
                    noticeMessage = "Calendar access is still needed to use Apple Calendar."
                }
                await load()
                return
            }

            var stored = try accountStore.load()
            if let index = stored.firstIndex(where: { $0.id == AppleCalendarProvider.appleAccountID }) {
                stored[index].isEnabled = true
            } else {
                stored.append(ConnectedCalendarAccount(
                    id: AppleCalendarProvider.appleAccountID,
                    provider: .apple,
                    displayName: "Apple Calendar",
                    isEnabled: true
                ))
            }
            try accountStore.save(stored)
            try await refreshDashboard(reason: .manual)
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func setAccountEnabled(id: CalendarAccountID, isEnabled: Bool) async {
        noticeMessage = nil
        settingsAlertMessage = nil

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
            try await refreshDashboard(reason: .manual)
        } catch {
            dashboardState = .error(format(error))
        }
    }

    func removeAccount(id: CalendarAccountID) async {
        noticeMessage = nil
        settingsAlertMessage = nil

        do {
            var stored = try accountStore.load()
            stored.removeAll(where: { $0.id == id })
            try accountStore.save(stored)
            try await refreshDashboard(reason: .manual)
        } catch {
            dashboardState = .error(format(error))
        }
    }

    private func format(_ error: Error) -> String {
        error.localizedDescription
    }

    private func refreshDashboard(reason: RefreshReason) async throws {
        let refreshGeneration = beginRefresh()
        let now = Date()
        let calendar = Calendar.current
        let currentPermissions = await permissionService.currentStatus()

        guard isCurrentRefresh(refreshGeneration) else { return }

        permissions = currentPermissions

        let outcome = try await refreshService.refreshAndSync(
            reason: reason,
            now: now,
            calendar: calendar
        )

        guard isCurrentRefresh(refreshGeneration) else { return }

        let snapshot = outcome.snapshot
        let plan = Self.primaryDashboardPlan(
            from: snapshot.displayPlans,
            now: now,
            calendar: calendar
        )
        let alarmStatus = Self.primaryAlarmStatus(
            for: plan,
            syncResult: snapshot.syncResult
        )

        guard isCurrentRefresh(refreshGeneration) else { return }

        permissions = snapshot.permissions
        accounts = snapshot.accounts
        calendars = snapshot.calendars
        tomorrowPlanPreview = snapshot.tomorrowPlan
        dailyPlans = snapshot.dailyPlans
        displayPlans = snapshot.displayPlans
        upcomingPlans = Array(snapshot.displayPlans.dropFirst().prefix(AppConfiguration.dashboardUpcomingDisplayCount))
        alarmStatusesByPlanID = snapshot.syncResult.statusesByPlanID
        let viewState = EarlyOtterViewState(plan: plan, alarmStatus: alarmStatus)

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

    private func beginRefresh() -> Int {
        refreshGeneration += 1
        return refreshGeneration
    }

    private func isCurrentRefresh(_ generation: Int) -> Bool {
        generation == refreshGeneration
    }

    private func showSettingsNotice(_ message: String) {
        settingsAlertMessage = message
    }

    func openSettings() {
        openAppSettings()
    }

    private static func defaultOpenAppSettings() {
#if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            return
        }

        UIApplication.shared.open(url)
#endif
    }

    static func primaryDashboardPlan(
        from displayPlans: [WakeUpPlan],
        now: Date,
        calendar: Calendar = .current
    ) -> WakeUpPlan {
        if let firstDisplayPlan = displayPlans.first {
            return firstDisplayPlan
        }

        let nextDay = TargetDay.tomorrow(from: now, calendar: calendar)
        return WakeUpPlan(
            id: EarlyOtterID(rawValue: "dashboard-empty-\(Int(nextDay.date.timeIntervalSince1970))"),
            targetDay: nextDay,
            targetEvent: nil,
            calculatedWakeTime: nextDay.date,
            eventStartTime: nil,
            prepTime: Minutes(0),
            commuteTime: Minutes(0),
            alarmSettings: .default,
            isFallback: false,
            reason: .noSchedule,
            appliedRuleName: nil,
            matchedRuleNames: []
        )
    }

    static func primaryAlarmStatus(
        for plan: WakeUpPlan,
        syncResult: AlarmSyncResult
    ) -> AlarmScheduleStatus {
        if let status = syncResult.statusesByPlanID[plan.id] {
            return status
        }

        switch plan.reason {
        case .noSchedule:
            return .notScheduled
        case .disabled, .inactiveDay, .systemDisabled:
            return .disabled
        case .event, .fallback, .authorizationMissing, .manualOverride:
            return .failed("Alarm status unavailable.")
        }
    }
}
