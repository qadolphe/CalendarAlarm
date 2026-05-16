import Foundation

@MainActor
struct DashboardViewModel {
    struct WeekEntry: Identifiable, Equatable {
        let targetDay: TargetDay
        let plan: WakeUpPlan
        let alarmStatus: AlarmScheduleStatus?

        var id: Date {
            targetDay.date
        }

        var alarmDate: Date? {
            switch plan.reason {
            case .disabled, .inactiveDay, .noSchedule, .systemDisabled:
                return nil
            case .event, .fallback, .authorizationMissing, .manualOverride:
                return plan.calculatedWakeTime
            }
        }

        var eventDate: Date? {
            plan.targetEvent?.startDate
        }

        var hasConnectedMarkers: Bool {
            plan.reason == .event && alarmDate != nil && eventDate != nil
        }
    }

    let appState: AppState
    private let calendar: Calendar

    init(appState: AppState, calendar: Calendar = .current) {
        self.appState = appState
        self.calendar = calendar
    }

    var title: String {
        "Week View"
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

    var weekEntries: [WeekEntry] {
        let planningCount = max(AppConfiguration.managedAlarmPlanningCount, 1)
        let plansByDay = Dictionary(uniqueKeysWithValues: appState.dailyPlans.map { ($0.targetDay.date, $0) })
        let startDate = appState.dailyPlans.first?.targetDay.date ?? calendar.startOfDay(for: Date())

        return (0..<planningCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let targetDay = TargetDay(date: date, calendar: calendar)
            let plan = plansByDay[targetDay.date] ?? fallbackPlan(for: targetDay)

            return WeekEntry(
                targetDay: targetDay,
                plan: plan,
                alarmStatus: alarmStatus(for: plan)
            )
        }
    }

    var upcomingPlans: [WakeUpPlan] {
        appState.upcomingPlans
    }

    var summaryHeadline: String {
        guard let nextPlan = appState.displayPlans.first else {
            return "No managed alarms this week"
        }

        return "Next alarm \(nextPlan.calculatedWakeTime.formatted(date: .omitted, time: .shortened))"
    }

    var summaryMessage: String {
        guard let nextPlan = appState.displayPlans.first else {
            return "Each day spans a full pill. Tap any day to inspect its alarm and event details."
        }

        if let event = nextPlan.targetEvent {
            return "Based on \(event.title) at \(event.startDate.formatted(date: .omitted, time: .shortened)) on \(nextPlan.targetDay.date.formatted(.dateTime.weekday(.wide)))."
        }

        switch nextPlan.reason {
        case .fallback:
            return "Using your fallback alarm on \(nextPlan.targetDay.date.formatted(.dateTime.weekday(.wide)))."
        case .authorizationMissing:
            return "EarlyOtter calculated the wake time, but alarm access is still needed to sync it."
        case .manualOverride:
            return "A manual alarm setup is taking priority for that day."
        case .event:
            return "Auto alarm is linked to the first matching event for that day."
        case .disabled:
            return "Automatic alarms are turned off."
        case .inactiveDay:
            return "Auto-Pilot is paused for some weekdays."
        case .noSchedule:
            return "No matching event or fallback alarm is available in the current planning window."
        case .systemDisabled:
            return "EarlyOtter is currently disabled."
        }
    }

    var statusPillText: String? {
        guard let viewState else { return nil }

        switch viewState.alarmStatus {
        case .scheduled:
            return "Synced"
        case .needsPermission:
            return "Alarm Access Needed"
        case .disabled:
            return "Paused"
        case .failed:
            return "Needs Attention"
        case .notScheduled:
            return "No Alarm"
        }
    }

    var eventSummary: String? {
        guard let plan else { return nil }

        if let event = plan.targetEvent {
            return "For \(event.title) at \(event.startDate.formatted(date: .omitted, time: .shortened))"
        }

        return "Fixed alarm"
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
                return "Fixed alarm is scheduled."
            }
            return "Alarm scheduled for the next valid event."
        case .needsPermission:
            return "EarlyOtter needs alarm access before it can schedule a real alarm."
        case .disabled:
            return "Automatic alarms are turned off."
        case .failed(let message):
            return "Couldn't schedule alarm: \(message)"
        case .notScheduled:
            return "No scheduled events or fixed alarm."
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

    func isPrimary(_ entry: WeekEntry) -> Bool {
        appState.displayPlans.first?.id == entry.plan.id
    }

    func daySymbol(for date: Date) -> String {
        switch calendar.component(.weekday, from: date) {
        case 1:
            return "S"
        case 2:
            return "M"
        case 3:
            return "T"
        case 4:
            return "W"
        case 5:
            return "Th"
        case 6:
            return "F"
        case 7:
            return "S"
        default:
            return date.formatted(.dateTime.weekday(.narrow))
        }
    }

    func footerText(for entry: WeekEntry) -> String {
        switch entry.plan.reason {
        case .event, .fallback, .authorizationMissing, .manualOverride:
            return entry.plan.calculatedWakeTime.formatted(date: .omitted, time: .shortened)
        case .disabled, .inactiveDay, .systemDisabled:
            return "Off"
        case .noSchedule:
            return "None"
        }
    }

    func accessibilityLabel(for entry: WeekEntry) -> String {
        let day = entry.targetDay.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())

        if let event = entry.plan.targetEvent,
           let alarmDate = entry.alarmDate {
            return "\(day), alarm \(alarmDate.formatted(date: .omitted, time: .shortened)) linked to \(event.title) at \(event.startDate.formatted(date: .omitted, time: .shortened))."
        }

        if let alarmDate = entry.alarmDate {
            return "\(day), fallback alarm at \(alarmDate.formatted(date: .omitted, time: .shortened))."
        }

        switch entry.plan.reason {
        case .inactiveDay:
            return "\(day), Auto-Pilot is paused for this day."
        case .disabled:
            return "\(day), automatic alarms are turned off."
        case .systemDisabled:
            return "\(day), EarlyOtter is disabled."
        case .noSchedule:
            return "\(day), no event or fallback alarm is scheduled."
        case .event, .fallback, .authorizationMissing, .manualOverride:
            return day
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
            return "Fixed alarm"
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
            return "No scheduled events or fixed alarm"
        case .disabled:
            return "Turn Auto-Pilot back on in Schedule"
        case .systemDisabled:
            return "Turn system on in Settings to reactivate"
        case .fallback, .authorizationMissing, .manualOverride, .event:
            return "No matching event found"
        }
    }

    private func alarmStatus(for plan: WakeUpPlan) -> AlarmScheduleStatus? {
        if let status = appState.alarmStatusesByPlanID[plan.id] {
            return status
        }

        switch plan.reason {
        case .noSchedule:
            return .notScheduled
        case .disabled, .inactiveDay, .systemDisabled:
            return .disabled
        case .event, .fallback, .authorizationMissing, .manualOverride:
            return nil
        }
    }

    private func fallbackPlan(for targetDay: TargetDay) -> WakeUpPlan {
        WakeUpPlan(
            id: WakePlanID(rawValue: "dashboard-week-\(Int(targetDay.date.timeIntervalSince1970))"),
            targetDay: targetDay,
            targetEvent: nil,
            calculatedWakeTime: targetDay.date,
            eventStartTime: nil,
            prepTime: Minutes(0),
            commuteTime: Minutes(0),
            alarmSettings: .default,
            isFallback: false,
            reason: .noSchedule,
            appliedRuleName: nil,
            matchedRuleNames: []
        )
    }
}
