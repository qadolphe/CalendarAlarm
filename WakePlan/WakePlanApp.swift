import GoogleSignIn
import SwiftUI

#if canImport(WidgetKit)
import WidgetKit
#endif

@main
struct WakePlanApp: App {
    private static let onboardingStorageKey = "hasCompletedOnboarding"

    @State private var appState: AppState
    private let backgroundRefreshService: BackgroundAlarmRefreshService

    init() {
        let launchArguments = ProcessInfo.processInfo.arguments
        let environment = WakePlanEnvironment.live()

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
        _appState = State(
            initialValue: environment.makeAppState()
        )
    }

    var body: some Scene {
        WindowGroup {
            WakePlanRootView(appState: appState)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .backgroundTask(.appRefresh(AppConfiguration.backgroundRefreshTaskIdentifier)) {
            await backgroundRefreshService.handleAppRefresh()
        }
    }

    private static func resetPersistedAppState(
        accountStore: UserDefaultsAccountStore,
        preferencesStore: UserDefaultsPreferencesStore,
        alarmStore: UserDefaultsScheduledAlarmStore,
        refreshResultStore: UserDefaultsWakePlanRefreshResultStore,
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
