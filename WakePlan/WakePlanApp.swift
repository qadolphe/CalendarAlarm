import SwiftUI

@main
struct WakePlanApp: App {
    @State private var appState: AppState

    init() {
        let preferencesStore = UserDefaultsPreferencesStore()
        let alarmStore = UserDefaultsScheduledAlarmStore()
        let calendarReader: CalendarReading

        if AppRuntime.usesFakeCalendar {
            calendarReader = FakeCalendarReader()
        } else {
            calendarReader = EventKitCalendarReader()
        }

        let alarmScheduler = AlarmKitScheduler()
        let wakePlanService = WakePlanService(
            calendarReader: calendarReader,
            preferencesStore: preferencesStore
        )
        let permissionService = PermissionService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler
        )
        let alarmSyncService = AlarmSyncService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler,
            preferencesStore: preferencesStore,
            alarmStore: alarmStore
        )

        _appState = State(
            initialValue: AppState(
                preferencesStore: preferencesStore,
                wakePlanService: wakePlanService,
                permissionService: permissionService,
                alarmSyncService: alarmSyncService,
                usesFakeCalendarData: AppRuntime.usesFakeCalendar
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            DashboardView(appState: appState)
        }
    }
}
