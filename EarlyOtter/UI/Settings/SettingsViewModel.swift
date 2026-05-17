import Foundation

struct WeekdayOption: Identifiable, Equatable, Sendable {
    let weekday: Int
    let shortLabel: String
    let fullLabel: String

    var id: Int { weekday }
}

enum RulesDestination: Hashable, Identifiable, Sendable {
    case timing
    case calendars
    case filters
    case keywords

    var id: Self { self }
}

struct RuleEditorDescriptor: Identifiable, Equatable, Sendable {
    let destination: RulesDestination
    let title: String
    let icon: String
    let helperText: String

    var id: RulesDestination { destination }
}

enum WakePlanUIConfiguration {
    static let sundayFirstWeekdays: [WeekdayOption] = [
        WeekdayOption(weekday: 1, shortLabel: "SUN", fullLabel: "Sunday"),
        WeekdayOption(weekday: 2, shortLabel: "MON", fullLabel: "Monday"),
        WeekdayOption(weekday: 3, shortLabel: "TUE", fullLabel: "Tuesday"),
        WeekdayOption(weekday: 4, shortLabel: "WED", fullLabel: "Wednesday"),
        WeekdayOption(weekday: 5, shortLabel: "THU", fullLabel: "Thursday"),
        WeekdayOption(weekday: 6, shortLabel: "FRI", fullLabel: "Friday"),
        WeekdayOption(weekday: 7, shortLabel: "SAT", fullLabel: "Saturday")
    ]

    static let editableRules: [RuleEditorDescriptor] = [
        RuleEditorDescriptor(
            destination: .timing,
            title: "Timing",
            icon: "clock.badge.checkmark",
            helperText: "Prep time, commute buffer, and fixed alarm time."
        ),
        RuleEditorDescriptor(
            destination: .calendars,
            title: "Calendars",
            icon: "calendar.badge.clock",
            helperText: "Choose which calendars count as alarm-worthy events."
        ),
        RuleEditorDescriptor(
            destination: .filters,
            title: "Event Filters",
            icon: "line.3.horizontal.decrease.circle",
            helperText: "Ignore event types that should never trigger an alarm."
        ),
        RuleEditorDescriptor(
            destination: .keywords,
            title: "Title Keywords",
            icon: "text.badge.plus",
            helperText: "Block or explicitly allow titles with keyword rules."
        )
    ]
}

enum WakePlanSummaryFormatter {
    static func selectedCalendarsSummary(calendars: [CalendarSource], preferences: AlarmPreferences) -> String {
        let count = calendars.filter(\.isSelected).count

        if count == calendars.count || preferences.selectedCalendarIDs.isEmpty {
            return "All calendars"
        }

        if count == 1 {
            return "1 calendar selected"
        }

        return "\(count) calendars selected"
    }

    static func activeDaysSummary(_ activeDays: Set<Int>) -> String {
        if activeDays.count == 7 {
            return "Every day"
        }

        if activeDays == Set([2, 3, 4, 5, 6]) {
            return "Weekdays"
        }

        if activeDays == Set([1, 7]) {
            return "Weekends"
        }

        if activeDays.count == 1,
           let option = WakePlanUIConfiguration.sundayFirstWeekdays.first(where: { activeDays.contains($0.weekday) }) {
            return option.fullLabel
        }

        return labels(for: activeDays).joined(separator: ", ")
    }

    static func shortActiveDaysSummary(_ activeDays: Set<Int>) -> String {
        if activeDays == Set(1...7) {
            return "Every day"
        }

        return labels(for: activeDays).joined(separator: ", ")
    }

    static func filtersSummary(_ preferences: AlarmPreferences) -> String {
        var parts: [String] = []

        if preferences.ignoreAllDayEvents {
            parts.append("All-day")
        }
        if preferences.ignoreTentativeEvents {
            parts.append("Tentative")
        }
        if preferences.ignoreCanceledEvents {
            parts.append("Canceled")
        }
        if preferences.ignoreFreeEvents {
            parts.append("Free")
        }

        if parts.isEmpty {
            return "No event types ignored"
        }

        return "Ignoring \(parts.joined(separator: ", "))"
    }

    static func keywordSummary(_ preferences: AlarmPreferences) -> String {
        let blockedCount = preferences.titleBlocklist.count
        let allowedCount = preferences.titleAllowlist.count

        if blockedCount == 0, allowedCount == 0 {
            return "No keyword rules"
        }

        if blockedCount > 0, allowedCount > 0 {
            return "\(blockedCount) blocked, \(allowedCount) allowed"
        }

        if blockedCount > 0 {
            return "\(blockedCount) blocked keywords"
        }

        return "\(allowedCount) allowed keywords"
    }

    private static func labels(for activeDays: Set<Int>) -> [String] {
        WakePlanUIConfiguration.sundayFirstWeekdays.compactMap {
            activeDays.contains($0.weekday) ? $0.shortLabel.capitalized : nil
        }
    }
}

@MainActor
struct ScheduleViewModel {
    let appState: AppState

    var weekdayOptions: [WeekdayOption] {
        WakePlanUIConfiguration.sundayFirstWeekdays
    }

    var scheduleStateTitle: String {
        appState.preferences.isEnabled ? "Auto-Pilot is On" : "Auto-Pilot is Paused"
    }

    var scheduleStateSummary: String {
        let days = WakePlanSummaryFormatter.activeDaysSummary(appState.preferences.activeDays).lowercased()
        let fallback = appState.preferences.latestWakeTime
            .date(on: TargetDay(date: Date()))
            .formatted(date: .omitted, time: .shortened)

        if !appState.preferences.isEnabled {
            return "EarlyOtter will not calculate or schedule alarms until Auto-Pilot is re-enabled."
        }

        return "EarlyOtter can schedule alarms on \(days) and use a fixed alarm time of \(fallback) when no event matches."
    }

    var activeDaysSummary: String {
        WakePlanSummaryFormatter.activeDaysSummary(appState.preferences.activeDays)
    }

    var latestWakeSummary: String {
        appState.preferences.latestWakeTime
            .date(on: TargetDay(date: Date()))
            .formatted(date: .omitted, time: .shortened)
    }
}

@MainActor
struct SettingsViewModel {
    let appState: AppState

    var accountsSummary: String {
        let googleAccounts = appState.accounts.filter { $0.provider == .google }

        if googleAccounts.isEmpty {
            return "Apple Calendar plus Google connect option"
        }

        let enabledCount = googleAccounts.filter(\.isEnabled).count
        return "Apple Calendar + \(googleAccounts.count) Google account\(googleAccounts.count == 1 ? "" : "s") (\(enabledCount) enabled)"
    }

    var needsPermissions: Bool {
        appState.permissions.calendar != .authorized || appState.permissions.alarm != .authorized
    }

    var permissionsSummary: String {
        if !needsPermissions {
            return "Calendar and alarm access granted"
        }

        if appState.permissions.calendar != .authorized,
           appState.permissions.alarm != .authorized {
            return "Calendar and alarm access still needed"
        }

        if appState.permissions.calendar != .authorized {
            return "Calendar access still needed"
        }

        return "Alarm access still needed"
    }

    var storageSummary: String {
        "Rules and alarm planning stay on-device."
    }
}
