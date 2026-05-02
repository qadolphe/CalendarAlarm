import Foundation

@MainActor
struct DashboardViewModel {
    let appState: AppState

    var title: String {
        "Tomorrow's Alarm"
    }

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

    var plan: WakeUpPlan? {
        viewState?.plan
    }

    var eventSummary: String? {
        guard let plan else { return nil }

        if let event = plan.targetEvent {
            return "For \(event.title) at \(event.startDate.formatted(date: .omitted, time: .shortened))"
        }

        return "Fallback wake time for tomorrow"
    }

    var timingSummary: String? {
        guard let plan else { return nil }
        return "\(plan.prepTime.rawValue) min prep · \(plan.commuteTime.rawValue) min commute"
    }

    var calendarSummary: String? {
        guard let plan else { return nil }

        if let event = plan.targetEvent,
           let title = appState.calendars.first(where: { $0.id == event.calendarID })?.title {
            return title
        }

        let selectedCalendars = appState.calendars.filter(\.isSelected)

        if selectedCalendars.count == 1 {
            return selectedCalendars[0].title
        }

        if selectedCalendars.isEmpty {
            return nil
        }

        return "\(selectedCalendars.count) calendars"
    }

    var statusTitle: String {
        guard let viewState else { return "Loading" }

        switch viewState.alarmStatus {
        case .scheduled:
            return "Scheduled"
        case .needsPermission:
            return "Needs Permission"
        case .disabled:
            return "Disabled"
        case .failed:
            return "Schedule Failed"
        case .notScheduled:
            return "Not Scheduled"
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
