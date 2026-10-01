import GoogleSignIn
import SwiftUI
import UIKit

#if canImport(WidgetKit)
import WidgetKit
#endif

@main
struct EarlyOtterApp: App {
    private static let onboardingStorageKey = "hasCompletedOnboarding"

    @Environment(\.scenePhase) private var scenePhase
    @State private var appState: AppState
    private let backgroundRefreshService: BackgroundAlarmRefreshService

    init() {
        Self.configureNavigationAppearance()

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
        _appState = State(
            initialValue: environment.makeAppState()
        )
    }

    private static func configureNavigationAppearance() {
        let baseFont = UIFont.systemFont(ofSize: 34, weight: .bold)
        let roundedFont = baseFont.fontDescriptor.withDesign(.rounded).map {
            UIFont(descriptor: $0, size: baseFont.pointSize)
        } ?? baseFont

        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: roundedFont,
            .foregroundColor: UIColor(WPStyles.primaryText)
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor(WPStyles.primaryText)
        ]
    }

    var body: some Scene {
        WindowGroup {
            EarlyOtterRootView(appState: appState)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active || newPhase == .background {
                        Task { await appState.flushTelemetry() }
                    }
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
        UserDefaults.standard.removeObject(
            forKey: AppConfiguration.reviewPromptQualifiedOpenCountStorageKey
        )
        UserDefaults.standard.removeObject(
            forKey: AppConfiguration.reviewPromptLastRequestedVersionStorageKey
        )
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [AppConfiguration.staleSyncReminderIdentifier]
        )
        GIDSignIn.sharedInstance.signOut()

    #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfiguration.nextAlarmWidgetKind)
    #endif
    }
}
