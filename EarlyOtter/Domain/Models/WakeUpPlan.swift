import Foundation

enum EarlyOtterReason: String, Codable, Equatable, Sendable {
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
    let id: EarlyOtterID

    let targetDay: TargetDay
    let targetEvent: ParsedEvent?
    let firstEventOfDay: ParsedEvent?

    let calculatedWakeTime: Date
    let eventStartTime: Date?

    let prepTime: Minutes
    let commuteTime: Minutes
    let alarmSettings: RuleAlarmSettings

    let isFallback: Bool
    let reason: EarlyOtterReason

    /// Name of the rule that produced the chosen wake time.
    var appliedRuleName: String?

    /// Names of all rules that matched the chosen event (only populated when >1 rule matched).
    let matchedRuleNames: [String]

    init(
        id: EarlyOtterID,
        targetDay: TargetDay,
        targetEvent: ParsedEvent?,
        firstEventOfDay: ParsedEvent? = nil,
        calculatedWakeTime: Date,
        eventStartTime: Date?,
        prepTime: Minutes,
        commuteTime: Minutes,
        alarmSettings: RuleAlarmSettings,
        isFallback: Bool,
        reason: EarlyOtterReason,
        appliedRuleName: String?,
        matchedRuleNames: [String]
    ) {
        self.id = id
        self.targetDay = targetDay
        self.targetEvent = targetEvent
        self.firstEventOfDay = firstEventOfDay ?? targetEvent
        self.calculatedWakeTime = calculatedWakeTime
        self.eventStartTime = eventStartTime
        self.prepTime = prepTime
        self.commuteTime = commuteTime
        self.alarmSettings = alarmSettings
        self.isFallback = isFallback
        self.reason = reason
        self.appliedRuleName = appliedRuleName
        self.matchedRuleNames = matchedRuleNames
    }
}
