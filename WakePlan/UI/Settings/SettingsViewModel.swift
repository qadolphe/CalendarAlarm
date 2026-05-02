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
}
