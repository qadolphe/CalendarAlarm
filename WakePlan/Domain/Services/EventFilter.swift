import Foundation

struct EventFilter {
    func shouldInclude(_ event: ParsedEvent, preferences: AlarmPreferences) -> Bool {
        if !preferences.selectedCalendarIDs.isEmpty,
           !preferences.selectedCalendarIDs.contains(event.calendarID) {
            return false
        }

        if preferences.ignoreAllDayEvents && event.isAllDay {
            return false
        }

        if preferences.ignoreTentativeEvents && event.status == .tentative {
            return false
        }

        if preferences.ignoreCanceledEvents && event.status == .canceled {
            return false
        }

        if preferences.ignoreFreeEvents && event.availability == .free {
            return false
        }

        let normalizedTitle = event.title.lowercased()

        if preferences.titleBlocklist.contains(where: { normalizedTitle.contains($0.lowercased()) }) {
            return false
        }

        if !preferences.titleAllowlist.isEmpty {
            return preferences.titleAllowlist.contains { normalizedTitle.contains($0.lowercased()) }
        }

        return true
    }
}
