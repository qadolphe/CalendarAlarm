import Foundation

enum AppConfiguration {
    static let appName = "WakePlan"
    static let genericAlarmTitle = "Wake up"

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
}
