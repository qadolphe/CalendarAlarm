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

    let isFallback: Bool
    let reason: WakePlanReason

    /// Name of the rule that produced the chosen wake time.
    var appliedRuleName: String?

    /// Names of all rules that matched the chosen event (only populated when >1 rule matched).
    let matchedRuleNames: [String]
}
