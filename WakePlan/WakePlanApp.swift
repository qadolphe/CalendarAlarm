import GoogleSignIn
import SwiftUI

@main
struct WakePlanApp: App {
    @State private var appState: AppState

    init() {
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
                AppleCalendarProvider(calendarReader: calendarReader),
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
}
