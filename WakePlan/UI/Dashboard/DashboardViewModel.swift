import Foundation

@MainActor
struct DashboardViewModel {
    let appState: AppState

    var title: String {
        "Next Alarm"
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

    var upcomingPlans: [WakeUpPlan] {
        appState.upcomingPlans
    }

    var eventSummary: String? {
        guard let plan else { return nil }

        if let event = plan.targetEvent {
            return "For \(event.title) at \(event.startDate.formatted(date: .omitted, time: .shortened))"
        }

        return "Fallback wake time"
    }

    var heroContext: String {
        guard let plan else { return "Baseline wake limit" }

        if let event = plan.targetEvent {
            return "Based on \"\(event.title)\""
        }

        return "No calendar event found"
    }

    var timeUntilWake: String? {
        guard let plan else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2

        let interval = max(plan.calculatedWakeTime.timeIntervalSinceNow, 0)
        guard let formatted = formatter.string(from: interval), !formatted.isEmpty else {
            return nil
        }

        return "In \(formatted)"
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
            if plan.reason == .inactiveDay {
                return "Auto-Pilot is paused for that day based on your active schedule."
            }
            if plan.reason == .fallback {
                return "Fallback wake time is scheduled."
            }
            return "Alarm scheduled for the next valid event."
        case .needsPermission:
            return "EarlyOtter needs alarm access before it can schedule a real alarm."
        case .disabled:
            return "Automatic alarms are turned off."
        case .failed(let message):
            return "Couldn't schedule alarm: \(message)"
        case .notScheduled:
            return "No scheduled events or fallback."
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

    func dayLabel(for plan: WakeUpPlan) -> String {
        plan.targetDay.date.formatted(.dateTime.weekday(.wide))
    }

    func upcomingTitle(for plan: WakeUpPlan) -> String {
        if let event = plan.targetEvent {
            return event.title
        }

        switch plan.reason {
        case .inactiveDay:
            return "Inactive day"
        case .noSchedule:
            return "No scheduled alarm"
        case .disabled:
            return "Auto-Pilot paused"
        case .systemDisabled:
            return "System disabled"
        case .fallback, .authorizationMissing, .manualOverride, .event:
            return "Fallback wake time"
        }
    }

    func upcomingSubtitle(for plan: WakeUpPlan) -> String {
        if let event = plan.targetEvent {
            return event.startDate.formatted(date: .omitted, time: .shortened)
        }

        switch plan.reason {
        case .inactiveDay:
            return "Not scheduled on this weekday"
        case .noSchedule:
            return "No scheduled events or fallback"
        case .disabled:
            return "Turn Auto-Pilot back on in Schedule"
        case .systemDisabled:
            return "Turn system on in Settings to reactivate"
        case .fallback, .authorizationMissing, .manualOverride, .event:
            return "No matching event found"
        }
    }
}
