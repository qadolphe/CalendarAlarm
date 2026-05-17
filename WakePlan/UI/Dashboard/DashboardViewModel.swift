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

        var displayedEvent: ParsedEvent? {
            plan.firstEventOfDay ?? plan.targetEvent
        }

        var eventDate: Date? {
            displayedEvent?.startDate
        }

        var hasConnectedMarkers: Bool {
            plan.reason == .event
                && plan.targetEvent?.id == displayedEvent?.id
                && alarmDate != nil
                && eventDate != nil
        }

        var latestRelevantDate: Date? {
            [alarmDate, eventDate].compactMap { $0 }.max()
        }
    }

    struct WeekPage: Identifiable, Equatable {
        let index: Int
        let entries: [WeekEntry]

        var id: Int {
            index
        }

        var startDate: Date? {
            entries.first?.targetDay.date
        }

        var endDate: Date? {
            entries.last?.targetDay.date
        }
    }

    struct VisibleTimeWindow: Equatable {
        let startSeconds: TimeInterval
        let endSeconds: TimeInterval

        var spanSeconds: TimeInterval {
            max(endSeconds - startSeconds, 60 * 60)
        }
    }

    let appState: AppState
    private let calendar: Calendar
    private let now: Date

    init(appState: AppState, calendar: Calendar = .current, now: Date = Date()) {
        self.appState = appState
        self.calendar = calendar
        self.now = now
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
        let planningCount = max(AppConfiguration.dashboardPlanningCount, 1)
        let plansByDay = Dictionary(uniqueKeysWithValues: appState.dailyPlans.map { ($0.targetDay.date, $0) })
        let startDate = appState.dailyPlans.first?.targetDay.date ?? startOfWeek(containing: now)

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

    var weekPages: [WeekPage] {
        stride(from: 0, to: weekEntries.count, by: AppConfiguration.dashboardWeekLength).map { startIndex in
            let entries = Array(
                weekEntries[startIndex..<min(startIndex + AppConfiguration.dashboardWeekLength, weekEntries.count)]
            )

            return WeekPage(
                index: startIndex / AppConfiguration.dashboardWeekLength,
                entries: entries
            )
        }
    }

    var defaultWeekPageIndex: Int {
        guard weekPages.count > 1 else {
            return 0
        }

        let today = calendar.startOfDay(for: now)

        guard calendar.component(.weekday, from: today) == 7,
              let saturdayEntry = weekEntries.first(where: {
                  calendar.isDate($0.targetDay.date, inSameDayAs: today)
              }),
              saturdayEntry.latestRelevantDate != nil,
              isElapsed(saturdayEntry) else {
            return 0
        }

        return 1
    }

    var visibleTimeWindow: VisibleTimeWindow {
        let defaultStart: TimeInterval = 5 * 60 * 60
        let defaultEnd: TimeInterval = 11 * 60 * 60
        let extensionAmount: TimeInterval = 60 * 60
        let dayLength: TimeInterval = 24 * 60 * 60

        let markerSeconds = weekEntries.flatMap { entry in
            let markerDates: [Date] = [entry.alarmDate, entry.eventDate].compactMap { $0 }
            return markerDates.map { date in
                timeOfDaySeconds(for: date, on: entry.targetDay)
            }
        }

        guard let earliest = markerSeconds.min(),
              let latest = markerSeconds.max() else {
            return VisibleTimeWindow(startSeconds: defaultStart, endSeconds: defaultEnd)
        }

        let start = min(defaultStart, max(0, earliest - extensionAmount))
        let end = max(defaultEnd, min(dayLength, latest + extensionAmount))

        return VisibleTimeWindow(startSeconds: start, endSeconds: end)
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

    func entry(for plan: WakeUpPlan, alarmStatus: AlarmScheduleStatus?) -> WeekEntry {
        if let existing = weekEntries.first(where: { $0.plan.id == plan.id }) {
            return existing
        }

        return WeekEntry(
            targetDay: plan.targetDay,
            plan: plan,
            alarmStatus: alarmStatus ?? self.alarmStatus(for: plan)
        )
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

    func accessibilityLabel(for entry: WeekEntry) -> String {
        let day = entry.targetDay.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())

        if let event = entry.displayedEvent,
           let alarmDate = entry.alarmDate {
            if entry.hasConnectedMarkers {
                return "\(day), alarm \(alarmDate.formatted(date: .omitted, time: .shortened)) linked to \(event.title) at \(event.startDate.formatted(date: .omitted, time: .shortened))."
            }

            return "\(day), alarm \(alarmDate.formatted(date: .omitted, time: .shortened)) and first event \(event.title) at \(event.startDate.formatted(date: .omitted, time: .shortened))."
        }

        if let event = entry.displayedEvent {
            return "\(day), first event \(event.title) at \(event.startDate.formatted(date: .omitted, time: .shortened))."
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

    func markerFraction(for date: Date?, on targetDay: TargetDay) -> CGFloat? {
        guard let date else { return nil }

        let seconds = timeOfDaySeconds(for: date, on: targetDay)
        let window = visibleTimeWindow
        let normalized = (seconds - window.startSeconds) / window.spanSeconds

        return CGFloat(min(max(normalized, 0), 1))
    }

    func weekRangeTitle(for page: WeekPage) -> String {
        guard let startDate = page.startDate,
              let endDate = page.endDate else {
            return ""
        }

        let sameYear = calendar.component(.year, from: startDate) == calendar.component(.year, from: endDate)
        let sameMonth = sameYear && calendar.component(.month, from: startDate) == calendar.component(.month, from: endDate)

        if sameMonth {
            return "\(startDate.formatted(.dateTime.month(.abbreviated).day())) - \(endDate.formatted(.dateTime.day()))"
        }

        if sameYear {
            return "\(startDate.formatted(.dateTime.month(.abbreviated).day())) - \(endDate.formatted(.dateTime.month(.abbreviated).day()))"
        }

        return "\(startDate.formatted(.dateTime.year().month(.abbreviated).day())) - \(endDate.formatted(.dateTime.year().month(.abbreviated).day()))"
    }

    func isElapsed(_ entry: WeekEntry) -> Bool {
        let today = calendar.startOfDay(for: now)

        if entry.targetDay.date < today {
            return true
        }

        if calendar.isDate(entry.targetDay.date, inSameDayAs: now),
           let latestRelevantDate = entry.latestRelevantDate {
            return latestRelevantDate <= now
        }

        return false
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

    private func startOfWeek(containing date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromSunday = weekday - 1

        return calendar.date(byAdding: .day, value: -daysFromSunday, to: startOfDay)
            ?? startOfDay
    }

    private func timeOfDaySeconds(for date: Date, on targetDay: TargetDay) -> TimeInterval {
        let dayLength: TimeInterval = 24 * 60 * 60
        return min(max(date.timeIntervalSince(targetDay.date), 0), dayLength)
    }
}
