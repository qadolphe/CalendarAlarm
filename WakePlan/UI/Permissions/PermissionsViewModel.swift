import Foundation

@MainActor
struct PermissionsViewModel {
    let appState: AppState

    var calendarStatus: String {
        label(for: appState.permissions.calendar)
    }

    var alarmStatus: String {
        label(for: appState.permissions.alarm)
    }

    var notificationStatus: String {
        label(for: appState.permissions.notification)
    }

    private func label(for state: CalendarAuthorizationState) -> String {
        switch state {
        case .notDetermined:
            return "Not requested"
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .unknown:
            return "Unknown"
        }
    }

    private func label(for state: AlarmAuthorizationState) -> String {
        switch state {
        case .notDetermined:
            return "Not requested"
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .unknown:
            return "Unknown"
        }
    }

    private func label(for state: NotificationAuthorizationState) -> String {
        switch state {
        case .notDetermined:
            return "Not requested"
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .unknown:
            return "Unknown"
        }
    }
}
