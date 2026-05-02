import Foundation

enum WakePlanReason: String, Codable, Equatable, Sendable {
    case event
    case fallback
    case disabled
    case inactiveDay
    case authorizationMissing
    case manualOverride
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
}
