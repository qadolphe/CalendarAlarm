import GoogleSignIn
import SwiftUI

@main
struct WakePlanApp: App {
    private static let onboardingStorageKey = "hasCompletedOnboarding"

    @State private var appState: AppState

    init() {
        let launchArguments = ProcessInfo.processInfo.arguments
        let accountStore = UserDefaultsAccountStore()
        let googleAuthenticator = GoogleSignInAuthenticator()
        let accountService = AccountService(
            accountStore: accountStore,
            googleAuthenticator: googleAuthenticator
        )
        let preferencesStore = UserDefaultsPreferencesStore()
        let alarmStore = UserDefaultsScheduledAlarmStore()
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

        if launchArguments.contains(LaunchArguments.resetAppData) {
            Self.resetPersistedAppState(
                accountStore: accountStore,
                preferencesStore: preferencesStore,
                alarmStore: alarmStore,
                alarmScheduler: alarmScheduler
            )
        }

        _appState = State(
            initialValue: AppState(
                accountStore: accountStore,
                accountService: accountService,
                preferencesStore: preferencesStore,
                wakePlanService: wakePlanService,
                permissionService: permissionService,
                alarmSyncService: alarmSyncService
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            WakePlanRootView(appState: appState)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    private static func resetPersistedAppState(
        accountStore: UserDefaultsAccountStore,
        preferencesStore: UserDefaultsPreferencesStore,
        alarmStore: UserDefaultsScheduledAlarmStore,
        alarmScheduler: AlarmKitScheduler
    ) {
        if let existingRecord = try? alarmStore.load() {
            Task {
                try? await alarmScheduler.cancel(nativeAlarmID: existingRecord.nativeAlarmID)
            }
        }

        preferencesStore.clear()
        accountStore.clear()
        try? accountStore.save([
            ConnectedCalendarAccount(
                id: AppleCalendarProvider.appleAccountID,
                provider: .apple,
                displayName: "Apple Calendar",
                isEnabled: false
            )
        ])
        try? alarmStore.clear()
        UserDefaults.standard.removeObject(forKey: Self.onboardingStorageKey)
        GIDSignIn.sharedInstance.signOut()
    }
}
