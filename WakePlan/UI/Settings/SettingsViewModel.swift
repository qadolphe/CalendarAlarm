import Foundation

@MainActor
struct SettingsViewModel {
    let appState: AppState

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
}
