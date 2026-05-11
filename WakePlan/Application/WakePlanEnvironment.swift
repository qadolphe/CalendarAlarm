import BackgroundTasks
import Foundation
import UserNotifications

#if canImport(AppIntents)
import AppIntents
#endif

actor BackgroundAlarmRefreshService: BackgroundAlarmRefreshScheduling {
    private let taskIdentifier: String
    private let makeRefreshService: () -> WakePlanRefreshService

    init(
        taskIdentifier: String = AppConfiguration.backgroundRefreshTaskIdentifier,
        makeRefreshService: @escaping () -> WakePlanRefreshService
    ) {
        self.taskIdentifier = taskIdentifier
        self.makeRefreshService = makeRefreshService
    }

    func handleAppRefresh() async {
        do {
            _ = try await MainActor.run {
                makeRefreshService()
            }.refreshAndSync(reason: .background)
        } catch {
            await scheduleNextRefresh(after: Date())
        }
    }

    func scheduleNextRefresh(after date: Date) async {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = date.addingTimeInterval(AppConfiguration.backgroundRefreshEarliestInterval)

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        try? BGTaskScheduler.shared.submit(request)
    }
}

actor StaleSyncReminderService: StaleSyncReminderScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func updateReminder(for result: WakePlanRefreshResult) async {
        let settings = await center.notificationSettingsAsync()

        switch settings.authorizationStatus {
        case .authorized, .ephemeral, .provisional:
            break
        case .denied, .notDetermined:
            return
        @unknown default:
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: [AppConfiguration.staleSyncReminderIdentifier])

        let reminderDate = nextReminderDate(after: result.syncedAt)
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let content = UNMutableNotificationContent()
        content.title = AppConfiguration.staleSyncReminderTitle
        content.body = AppConfiguration.staleSyncReminderBody
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: AppConfiguration.staleSyncReminderIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        )

        try? await center.addAsync(request)
    }

    private func nextReminderDate(after date: Date, calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
        let components = calendar.dateComponents([.year, .month, .day], from: tomorrow)

        return calendar.date(
            from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: AppConfiguration.staleSyncReminderHour,
                minute: 0
            )
        ) ?? tomorrow
    }
}

struct WakePlanEnvironment {
    let accountStore: UserDefaultsAccountStore
    let accountService: AccountService
    let preferencesStore: UserDefaultsPreferencesStore
    let alarmStore: UserDefaultsScheduledAlarmStore
    let refreshResultStore: UserDefaultsWakePlanRefreshResultStore
    let calendarReader: EventKitCalendarReader
    let alarmScheduler: AlarmKitScheduler
    let wakePlanService: WakePlanService
    let permissionService: PermissionService
    let alarmSyncService: AlarmSyncService
    let refreshService: WakePlanRefreshService
    let backgroundRefreshService: BackgroundAlarmRefreshService
    let staleSyncReminderService: StaleSyncReminderService

    @MainActor
    static func live() -> WakePlanEnvironment {
        let accountStore = UserDefaultsAccountStore()
        let googleAuthenticator = GoogleSignInAuthenticator()
        let accountService = AccountService(
            accountStore: accountStore,
            googleAuthenticator: googleAuthenticator
        )
        let preferencesStore = UserDefaultsPreferencesStore()
        let alarmStore = UserDefaultsScheduledAlarmStore()
        let refreshResultStore = UserDefaultsWakePlanRefreshResultStore()
        let calendarReader = EventKitCalendarReader()
        let calendarProvider = CompositeCalendarProvider(
            providers: [
                AppleCalendarProvider(calendarReader: calendarReader, accountStore: accountStore),
                GoogleCalendarProvider(accountStore: accountStore)
            ]
        )
        let alarmScheduler = AlarmKitScheduler()
        let wakePlanService = WakePlanService(
            calendarProvider: calendarProvider,
            preferencesStore: preferencesStore
        )
        let permissionService = PermissionService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler
        )
        let alarmSyncService = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: alarmStore
        )
        let staleSyncReminderService = StaleSyncReminderService()
        let backgroundRefreshService = BackgroundAlarmRefreshService {
            WakePlanEnvironment.live().refreshService
        }
        let refreshService = WakePlanRefreshService(
            wakePlanService: wakePlanService,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService,
            resultStore: refreshResultStore,
            backgroundRefreshScheduler: backgroundRefreshService,
            staleSyncReminderScheduler: staleSyncReminderService
        )

        return WakePlanEnvironment(
            accountStore: accountStore,
            accountService: accountService,
            preferencesStore: preferencesStore,
            alarmStore: alarmStore,
            refreshResultStore: refreshResultStore,
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler,
            wakePlanService: wakePlanService,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService,
            refreshService: refreshService,
            backgroundRefreshService: backgroundRefreshService,
            staleSyncReminderService: staleSyncReminderService
        )
    }

    @MainActor
    func makeAppState() -> AppState {
        AppState(
            accountStore: accountStore,
            accountService: accountService,
            preferencesStore: preferencesStore,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService,
            refreshService: refreshService
        )
    }
}

private extension UNUserNotificationCenter {
    func notificationSettingsAsync() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            getNotificationSettings { continuation.resume(returning: $0) }
        }
    }

    func addAsync(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

#if canImport(AppIntents)
@available(iOS 16.0, *)
struct RefreshWakePlanAlarmsIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Alarms"
    static var description = IntentDescription(
        "Refresh EarlyOtter's rolling wake-up alarms using your latest calendar events."
    )
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let environment = await MainActor.run {
            WakePlanEnvironment.live()
        }
        let outcome = try await environment.refreshService.refreshAndSync(reason: .shortcut)
        let alarmLabel = outcome.result.scheduledCount == 1 ? "alarm" : "alarms"
        let planLabel = outcome.result.plannedDays == 1 ? "wake plan" : "wake plans"

        return .result(
            dialog: IntentDialog(
                "Updated \(outcome.result.scheduledCount) \(alarmLabel) across \(outcome.result.plannedDays) upcoming \(planLabel)."
            )
        )
    }
}

@available(iOS 16.0, *)
struct WakePlanShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshWakePlanAlarmsIntent(),
            phrases: [
                "Refresh alarms in \(.applicationName)",
                "Refresh my alarms in \(.applicationName)"
            ],
            shortTitle: "Refresh Alarms",
            systemImageName: "alarm"
        )
    }
}
#endif
