import Foundation

@MainActor
struct CalendarSelectionViewModel {
    let appState: AppState

    var helperText: String {
        if appState.preferences.selectedCalendarIDs.isEmpty {
            return "All calendars are currently selected."
        }

        return "Choose which calendars count toward tomorrow's first alarm-worthy event."
    }
}
