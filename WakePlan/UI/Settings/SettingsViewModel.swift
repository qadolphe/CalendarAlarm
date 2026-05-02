import Foundation

@MainActor
struct SettingsViewModel {
    let appState: AppState

    let weekdayOptions: [(label: String, weekday: Int)] = [
        ("MON", 2),
        ("TUE", 3),
        ("WED", 4),
        ("THU", 5),
        ("FRI", 6),
        ("SAT", 7),
        ("SUN", 1)
    ]

    var selectedCalendarsSummary: String {
        let count = appState.calendars.filter(\.isSelected).count

        if count == appState.calendars.count || appState.preferences.selectedCalendarIDs.isEmpty {
            return "All calendars"
        }

        if count == 1 {
            return "1 calendar selected"
        }

        return "\(count) calendars selected"
    }

    var needsPermissions: Bool {
        appState.permissions.calendar != .authorized || appState.permissions.alarm != .authorized
    }

    var permissionsSummary: String {
        if !needsPermissions {
            return "Calendar and alarm access granted"
        }

        if appState.permissions.calendar != .authorized, appState.permissions.alarm != .authorized {
            return "Calendar and alarm access still needed"
        }

        if appState.permissions.calendar != .authorized {
            return "Calendar access still needed"
        }

        return "Alarm access still needed"
    }

    var timingSummary: String {
        let latestWakeTime = appState.preferences.latestWakeTime.date(on: TargetDay(date: Date()))
            .formatted(date: .omitted, time: .shortened)

        return "Prep \(appState.preferences.prepTime.rawValue) min · Commute \(appState.preferences.defaultCommuteTime.rawValue) min · Latest \(latestWakeTime)"
    }

    var activeDaysSummary: String {
        let count = appState.preferences.activeDays.count

        if count == 7 {
            return "7 days active"
        }

        if count == 5 && Set([2, 3, 4, 5, 6]).isSubset(of: appState.preferences.activeDays) {
            return "5 days active"
        }

        if count == 1, let day = weekdayOptions.first(where: { appState.preferences.activeDays.contains($0.weekday) }) {
            return "Only \(day.label) active"
        }

        return "\(count) days active"
    }

    var activeRoutineTitle: String {
        appState.preferences.isEnabled ? "Weekday Routine Active" : "Auto-Pilot Paused"
    }

    var activeRoutineSummary: String {
        let latestWakeTime = appState.preferences.latestWakeTime.date(on: TargetDay(date: Date()))
            .formatted(date: .omitted, time: .shortened)

        if !appState.preferences.isEnabled {
            return "WakePlan will stay idle until you re-enable Auto-Pilot."
        }

        return "Auto-Pilot will gently wake you at \(latestWakeTime) and initiate your morning sequence on \(activeDaysSummary.lowercased())."
    }

    var alarmListSummary: String {
        if !appState.preferences.isEnabled {
            return "Paused"
        }

        return activeDaysSummary
    }
}
