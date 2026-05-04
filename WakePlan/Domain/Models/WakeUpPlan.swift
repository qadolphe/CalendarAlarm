import Foundation

enum WakePlanReason: String, Codable, Equatable, Sendable {
    case event
    case fallback
    case noSchedule
    case disabled
    case inactiveDay
    case authorizationMissing
    case manualOverride
    case systemDisabled
}

struct WakeUpPlan: Codable, Equatable, Identifiable, Sendable {
    let id: WakePlanID

    let targetDay: TargetDay
    let targetEvent: ParsedEvent?

    let calculatedWakeTime: Date
    let eventStartTime: Date?

    let prepTime: Minutes
    let commuteTime: Minutes
    let alarmSettings: RuleAlarmSettings

    let isFallback: Bool
    let reason: WakePlanReason

    /// Name of the rule that produced the chosen wake time.
    var appliedRuleName: String?

    /// Names of all rules that matched the chosen event (only populated when >1 rule matched).
    let matchedRuleNames: [String]
}

extension WakeUpPlan {
    var alarmDebugSummary: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        func formatted(_ date: Date?) -> String {
            guard let date else { return "nil" }
            return formatter.string(from: date)
        }

        return [
            "planID=\(id.rawValue)",
            "reason=\(reason.rawValue)",
            "isFallback=\(isFallback)",
            "targetDay=\(formatted(targetDay.date))",
            "wakeTime=\(formatted(calculatedWakeTime))",
            "eventID=\(targetEvent?.id ?? "nil")",
            "eventStart=\(formatted(eventStartTime))",
            "eventTitle=\(targetEvent?.title ?? "nil")",
            "appliedRule=\(appliedRuleName ?? "nil")",
            "prepMinutes=\(prepTime.rawValue)",
            "commuteMinutes=\(commuteTime.rawValue)",
            "sound=\(alarmSettings.sound.rawValue)",
            "snoozeEnabled=\(alarmSettings.snoozeEnabled)",
            "snoozeMinutes=\(alarmSettings.snoozeDuration.rawValue)"
        ].joined(separator: ", ")
    }
}
