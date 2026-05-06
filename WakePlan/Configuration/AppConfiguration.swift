import Foundation

enum AppConfiguration {
    static let appName = "EarlyOtter"
    static let genericAlarmTitle = "Wake up"
    static let testAlarmButtonTitle = "Test Alarm in 1 Minute"
    static let testAlarmDescription =
        "Creates a one-time test alarm without changing tomorrow's managed wake-up alarm."

    static let calendarPermissionExplanation =
        "\(appName) needs calendar access to find your first event tomorrow and calculate your wake-up time."

    static let alarmPermissionExplanation =
        "Alarm access lets \(appName) schedule real wake-up alarms for your calendar events. You can enable it later in Settings."

    static let onboardingAlarmPermissionExplanation =
        "Alarm access is optional during setup. Enable it now to let \(appName) schedule wake-up alarms automatically, or continue and turn it on later in Settings."

    static func alarmTitle(for eventTitle: String?) -> String {
        guard let eventTitle, !eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return genericAlarmTitle
        }

        return "Wake up for \(eventTitle)"
    }

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
