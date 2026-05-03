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
        "\(appName) needs alarm access to schedule real wake-up alarms for your calendar events."

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
