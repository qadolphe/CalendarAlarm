import Foundation

@MainActor
struct DashboardViewModel {
    let appState: AppState

    var statusMessage: String? {
        guard let plan = appState.currentPlan else { return nil }

        switch plan.reason {
        case .event:
            return "First valid event tomorrow."
        case .fallback:
            return "No valid event matched your filters, so the fallback wake time is active."
        case .disabled:
            return "Automatic alarms are turned off."
        case .authorizationMissing:
            return "WakePlan needs alarm access before it can schedule a real alarm."
        case .manualOverride:
            return "A manual override is active."
        }
    }

    var permissionBanner: String? {
        if appState.usesFakeCalendarData {
            return "Fake calendar mode is enabled. Launch without `-useFakeCalendar` to switch back to real calendars."
        }

        if appState.permissions.calendar != .authorized {
            return AppConfiguration.calendarPermissionExplanation
        }

        if appState.permissions.alarm != .authorized {
            return AppConfiguration.alarmPermissionExplanation
        }

        return nil
    }
}
