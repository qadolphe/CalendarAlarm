import Foundation

@MainActor
struct DashboardViewModel {
    let appState: AppState

    var viewState: WakePlanViewState? {
        switch appState.dashboardState {
        case .needsAlarmPermission(let viewState),
             .ready(let viewState),
             .emptyFallback(let viewState):
            return viewState
        case .loading, .needsCalendarPermission, .error:
            return nil
        }
    }

    var statusMessage: String? {
        guard let viewState else { return nil }
        let plan = viewState.plan

        switch viewState.alarmStatus {
        case .scheduled:
            if plan.reason == .fallback {
                return "Fallback wake time is scheduled because no event matched your filters."
            }
            return "Alarm scheduled for the first valid event tomorrow."
        case .needsPermission:
            return "WakePlan needs alarm access before it can schedule a real alarm."
        case .disabled:
            return "Automatic alarms are turned off."
        case .failed(let message):
            return "Couldn't schedule alarm: \(message)"
        case .notScheduled:
            return "No alarm is currently scheduled."
        }
    }

    var permissionBanner: String? {
        switch appState.dashboardState {
        case .needsCalendarPermission:
            return AppConfiguration.calendarPermissionExplanation
        case .needsAlarmPermission:
            return AppConfiguration.alarmPermissionExplanation
        case .loading, .ready, .emptyFallback, .error:
            return nil
        }
    }
}
