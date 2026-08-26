import Foundation

enum AppConfiguration {
    static let appName = "EarlyOtter"
    static let nextAlarmWidgetKind = "com.quentinadolphe.wakeplan.nextAlarmWidget"
    static let widgetAppGroupIdentifier = "group.com.quentinadolphe.wakeplan.widget"
    static let genericAlarmTitle = "Wake up"
    static let feedbackEndpointURL = URL(string: "https://earlyotter.com/api/feedback")!
    static let testAlarmButtonTitle = "Test Alarm in 1 Minute"
    static let testAlarmDescription =
        "Creates a one-time test alarm without changing tomorrow's managed wake-up alarm."
    static let managedAlarmPlanningCount = 7
    static let dashboardWeekLength = 7
    static let dashboardVisibleWeekCount = 2
    static let dashboardPlanningCount = dashboardWeekLength * dashboardVisibleWeekCount
    static let dashboardUpcomingDisplayCount = 3
    static let backgroundRefreshTaskIdentifier = "com.earlyotter.calendaralarm.refresh"
    static let backgroundRefreshEarliestInterval: TimeInterval = 6 * 60 * 60
    static let staleSyncReminderIdentifier = "com.earlyotter.calendaralarm.stale-sync-reminder"
    static let staleSyncReminderHour = 19
    /// Retire once the app is out of its early period; Settings keeps a permanent entry point.
    static let showsHomeFeedbackFooter = true
    static let reviewPromptQualifiedOpenCountStorageKey =
        "earlyotter.reviewPrompt.qualifiedOpenCount"
    static let reviewPromptLastRequestedVersionStorageKey =
        "earlyotter.reviewPrompt.lastRequestedVersion"

    static var currentAppVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String
        return version ?? build ?? "unknown"
    }

    static let calendarPermissionExplanation =
        "\(appName) needs calendar access to find your first event tomorrow and calculate your wake-up time."

    static let alarmPermissionExplanation =
        "Alarm access lets \(appName) schedule real wake-up alarms for your calendar events. You can enable it later in Settings."

    static let onboardingAlarmPermissionExplanation =
        "These are optional during setup. Enable them now to let \(appName) schedule alarms and notify you on updates automatically."

    static let refreshReliabilityExplanation =
        "\(appName) keeps alarms updated when you open the app and can refresh automatically in the background when iOS allows."

    static let shortcutsExplanation =
        "Add \"Refresh Alarms\" to a Siri Shortcut or automation to keep your alarms synced on your schedule."

    static let staleSyncReminderTitle = "\(appName) may need to refresh your alarms"
    static let staleSyncReminderBody =
        "Open the app to keep tomorrow's alarm up to date."

    static func testAlarmScheduledMessage(for wakeTime: Date) -> String {
        "Test alarm scheduled for \(wakeTime.formatted(date: .omitted, time: .shortened))."
    }
}

enum LaunchArguments {
    static let forceOnboarding = "-EarlyOtterForceOnboarding"
    static let legacyForceOnboarding = "-WakePlanForceOnboarding"
    static let resetAppData = "-EarlyOtterResetAppData"

    static let allForceOnboarding = [
        forceOnboarding,
        legacyForceOnboarding
    ]
}
