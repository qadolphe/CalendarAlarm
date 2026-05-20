import GoogleSignIn
import SwiftUI

#if canImport(WidgetKit)
import WidgetKit
#endif

@main
struct EarlyOtterApp: App {
    private static let onboardingStorageKey = "hasCompletedOnboarding"

    @Environment(\.scenePhase) private var scenePhase
    @State private var appState: AppState
    private let backgroundRefreshService: BackgroundAlarmRefreshService
    private let alarmScheduler: AlarmKitScheduler
    private let alarmStore: UserDefaultsScheduledAlarmStore

    init() {
        let launchArguments = ProcessInfo.processInfo.arguments
        let environment = EarlyOtterEnvironment.live()

        if launchArguments.contains(LaunchArguments.resetAppData) {
            Self.resetPersistedAppState(
                accountStore: environment.accountStore,
                preferencesStore: environment.preferencesStore,
                alarmStore: environment.alarmStore,
                refreshResultStore: environment.refreshResultStore,
                widgetSnapshotStore: environment.widgetSnapshotStore,
                alarmScheduler: environment.alarmScheduler
            )
        }

        backgroundRefreshService = environment.backgroundRefreshService
        alarmScheduler = environment.alarmScheduler
        alarmStore = environment.alarmStore
        _appState = State(
            initialValue: environment.makeAppState()
        )

        Self.sweepOrphanedLiveActivities(
            alarmScheduler: environment.alarmScheduler,
            alarmStore: environment.alarmStore
        )
    }

    var body: some Scene {
        WindowGroup {
            EarlyOtterRootView(appState: appState)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Self.sweepOrphanedLiveActivities(
                            alarmScheduler: alarmScheduler,
                            alarmStore: alarmStore
                        )
                    }
                }
        }
        .backgroundTask(.appRefresh(AppConfiguration.backgroundRefreshTaskIdentifier)) {
            await backgroundRefreshService.handleAppRefresh()
        }
    }

    /// Best-effort cleanup of any AlarmKit Live Activities that no longer
    /// match a scheduled alarm. Runs at launch and whenever the scene becomes
    /// active so the Dynamic Island doesn't display stale alarm presentations.
    private static func sweepOrphanedLiveActivities(
        alarmScheduler: AlarmKitScheduler,
        alarmStore: UserDefaultsScheduledAlarmStore
    ) {
        let keep = Set(((try? alarmStore.load()) ?? []).map(\.nativeAlarmID))
        Task.detached(priority: .utility) {
            await alarmScheduler.endOrphanedLiveActivities(keepingNativeAlarmIDs: keep)
        }
    }

    private static func resetPersistedAppState(
        accountStore: UserDefaultsAccountStore,
        preferencesStore: UserDefaultsPreferencesStore,
        alarmStore: UserDefaultsScheduledAlarmStore,
        refreshResultStore: UserDefaultsEarlyOtterRefreshResultStore,
        widgetSnapshotStore: UserDefaultsNextAlarmWidgetSnapshotStore,
        alarmScheduler: AlarmKitScheduler
    ) {
        let existingRecords = (try? alarmStore.load()) ?? []

        if !existingRecords.isEmpty {
            Task {
                for record in existingRecords {
                    try? await alarmScheduler.cancel(nativeAlarmID: record.nativeAlarmID)
                }
            }
        }

        preferencesStore.clear()
        accountStore.clear()
        try? alarmStore.clear()
        try? refreshResultStore.clear()
        try? widgetSnapshotStore.clear()
        UserDefaults.standard.removeObject(forKey: Self.onboardingStorageKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [AppConfiguration.staleSyncReminderIdentifier]
        )
        GIDSignIn.sharedInstance.signOut()

    #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfiguration.nextAlarmWidgetKind)
    #endif
    }
}
