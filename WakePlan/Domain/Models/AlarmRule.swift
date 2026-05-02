import Foundation

// A condition that must be true for an AlarmRule to apply to an event.
enum AlarmRuleCondition: Codable, Equatable, Sendable {
    case titleContains(String)
    case locationContains(String)

    var displayLabel: String {
        switch self {
        case .titleContains(let keyword):   return "Title contains \"\(keyword)\""
        case .locationContains(let place):  return "Location contains \"\(place)\""
        }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey { case type, value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let value = try container.decode(String.self, forKey: .value)
        switch type {
        case "locationContains": self = .locationContains(value)
        default:                 self = .titleContains(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .titleContains(let v):
            try container.encode("titleContains", forKey: .type)
            try container.encode(v, forKey: .value)
        case .locationContains(let v):
            try container.encode("locationContains", forKey: .type)
            try container.encode(v, forKey: .value)
        }
    }
}

// A user-created alarm rule. The first matching rule (in order) wins.
// The Default rule always matches and must be present exactly once.
struct AlarmRule: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    /// When true this rule matches every event (no conditions evaluated).
    var isDefault: Bool
    var selectedCalendarIDs: Set<String>
    var conditions: [AlarmRuleCondition]
    var prepTime: Minutes
    var commuteTime: Minutes

    static func makeDefault(
        prepTime: Minutes = Minutes(45),
        commuteTime: Minutes = Minutes(20),
        selectedCalendarIDs: Set<String> = []
    ) -> AlarmRule {
        AlarmRule(
            id: UUID(),
            name: "Default",
            isDefault: true,
            selectedCalendarIDs: selectedCalendarIDs,
            conditions: [],
            prepTime: prepTime,
            commuteTime: commuteTime
        )
    }

    /// Returns true when this rule should apply to a given event.
    func matches(event: ParsedEvent) -> Bool {
        if !selectedCalendarIDs.isEmpty,
           !selectedCalendarIDs.contains(event.calendarID) {
            return false
        }

        if isDefault { return true }
        guard !conditions.isEmpty else { return true }
        return conditions.allSatisfy { condition in
            switch condition {
            case .titleContains(let keyword):
                return event.title.localizedCaseInsensitiveContains(keyword)
            case .locationContains(let place):
                return event.location?.localizedCaseInsensitiveContains(place) ?? false
            }
        }
    }
}
