import Foundation

enum AppConfiguration {
    static let appName = "EarlyOtter"
    static let nextAlarmWidgetKind = "com.quentinadolphe.wakeplan.nextAlarmWidget"
    static let widgetAppGroupIdentifier = "group.com.quentinadolphe.wakeplan.widget"
    static let genericAlarmTitle = String(localized: "Wake up")
    static let feedbackEndpointURL = URL(string: "https://earlyotter.com/api/feedback")!
    static let telemetryEndpointURL = URL(string: "https://earlyotter.com/api/telemetry")!
    static let telemetryConsentStorageKey = "earlyotter.telemetry.shareUsageData"
    static let telemetryInstallIDStorageKey = "earlyotter.telemetry.installID"
    static let testAlarmButtonTitle = String(localized: "Test Alarm in 1 Minute")
    static let testAlarmDescription =
        String(localized: "Creates a one-time test alarm without changing tomorrow's managed wake-up alarm.")
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

    static let privacyPolicyURL = URL(string: "https://earlyotter.com/privacy")!
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6766083287?action=write-review")!
    static let telemetryInternalDeviceKeychainAccount = "telemetry.internalDevice"

    /// For display, e.g. "1.0.9 (5)".
    static var appVersionWithBuild: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

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
        String(localized: "\(appName) needs calendar access to find your first event tomorrow and calculate your wake-up time.")

    static let alarmPermissionExplanation =
        String(localized: "Alarm access lets \(appName) schedule real wake-up alarms for your calendar events. You can enable it later in Settings.")

    static let onboardingAlarmPermissionExplanation =
        String(localized: "These are optional during setup. Enable them now to let \(appName) schedule alarms and notify you on updates automatically.")

    static let staleSyncReminderTitle = String(localized: "\(appName) may need to refresh your alarms")
    static let staleSyncReminderBody =
        String(localized: "Open the app to keep tomorrow's alarm up to date.")

    static func testAlarmScheduledMessage(for wakeTime: Date) -> String {
        String(localized: "Test alarm scheduled for \(wakeTime.formatted(date: .omitted, time: .shortened)).")
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
