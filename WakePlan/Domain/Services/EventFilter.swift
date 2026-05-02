import Foundation

struct EventFilter {
    func shouldInclude(_ event: ParsedEvent, preferences: AlarmPreferences) -> Bool {
        let filters = preferences.filters

        if filters.ignoreAllDayEvents && event.isAllDay {
            return false
        }

        if filters.ignoreTentativeEvents && event.status == .tentative {
            return false
        }

        if filters.ignoreCanceledEvents && event.status == .canceled {
            return false
        }

        if filters.ignoreFreeEvents && event.availability == .free {
            return false
        }

        let normalizedTitle = event.title.lowercased()
        let titleKeywords = filters.titleKeywords

        if titleKeywords.blockedKeywords.contains(where: { normalizedTitle.contains($0.lowercased()) }) {
            return false
        }

        if !titleKeywords.allowedKeywords.isEmpty {
            return titleKeywords.allowedKeywords.contains { normalizedTitle.contains($0.lowercased()) }
        }

        return true
    }
}
