import Foundation

enum AlarmSoundOption: String, Codable, CaseIterable, Equatable, Sendable {
    case `default`
    case basso
    case blow
    case bottle
    case frog
    case funk
    case glass
    case hero
    case morse
    case ping
    case pop
    case purr
    case sosumi
    case submarine
    case tink

    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .basso:
            return "Basso"
        case .blow:
            return "Blow"
        case .bottle:
            return "Bottle"
        case .frog:
            return "Frog"
        case .funk:
            return "Funk"
        case .glass:
            return "Glass"
        case .hero:
            return "Hero"
        case .morse:
            return "Morse"
        case .ping:
            return "Ping"
        case .pop:
            return "Pop"
        case .purr:
            return "Purr"
        case .sosumi:
            return "Sosumi"
        case .submarine:
            return "Submarine"
        case .tink:
            return "Tink"
        }
    }

    var resourceName: String? {
        switch self {
        case .default:
            return nil
        case .basso:
            return "Basso.aiff"
        case .blow:
            return "Blow.aiff"
        case .bottle:
            return "Bottle.aiff"
        case .frog:
            return "Frog.aiff"
        case .funk:
            return "Funk.aiff"
        case .glass:
            return "Glass.aiff"
        case .hero:
            return "Hero.aiff"
        case .morse:
            return "Morse.aiff"
        case .ping:
            return "Ping.aiff"
        case .pop:
            return "Pop.aiff"
        case .purr:
            return "Purr.aiff"
        case .sosumi:
            return "Sosumi.aiff"
        case .submarine:
            return "Submarine.aiff"
        case .tink:
            return "Tink.aiff"
        }
    }
}

struct RuleAlarmSettings: Codable, Equatable, Sendable {
    var sound: AlarmSoundOption
    var snoozeEnabled: Bool
    var snoozeDuration: Minutes

    static let `default` = RuleAlarmSettings(
        sound: .default,
        snoozeEnabled: true,
        snoozeDuration: Minutes(10)
    )
}

// A condition that must be true for an AlarmRule to apply to an event.
enum AlarmRuleCondition: Codable, Equatable, Sendable {
    case titleContains(String)
    case locationContains(String)

    var displayLabel: String {
        switch self {
        case .titleContains(let keyword):   return "\"\(keyword)\""
        case .locationContains(let place):  return "\"\(place)\""
        }
    }

    var iconName: String {
        switch self {
        case .titleContains: return "text.quote"
        case .locationContains: return "mappin.and.ellipse"
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
    var activeWeekdays: Set<Int>
    var selectedCalendarIDs: Set<String>
    var conditions: [AlarmRuleCondition]
    var prepTime: Minutes
    var commuteTime: Minutes
    var alarmSettings: RuleAlarmSettings

    static func makeDefault(
        prepTime: Minutes = Minutes(45),
        commuteTime: Minutes = Minutes(20),
        selectedCalendarIDs: Set<String> = [],
        activeWeekdays: Set<Int> = Set(1...7),
        alarmSettings: RuleAlarmSettings = .default
    ) -> AlarmRule {
        AlarmRule(
            id: UUID(),
            name: "Default",
            isDefault: true,
            activeWeekdays: activeWeekdays,
            selectedCalendarIDs: selectedCalendarIDs,
            conditions: [],
            prepTime: prepTime,
            commuteTime: commuteTime,
            alarmSettings: alarmSettings
        )
    }

    /// Returns true when this rule should apply to a given event.
    func matches(
        event: ParsedEvent,
        activeCalendarIDs: Set<String>,
        calendar: Calendar = .current
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: event.startDate)
        guard activeWeekdays.contains(weekday) else {
            return false
        }

        if !selectedCalendarIDs.isEmpty {
            let intersection = selectedCalendarIDs.intersection(activeCalendarIDs)
            // If the explicitly selected calendars are completely disabled,
            // the Default Rule gracefully falls back to matching all active calendars.
            if isDefault && intersection.isEmpty {
                // Fallback to all active calendars
            } else if !selectedCalendarIDs.contains(event.calendarID) {
                return false
            }
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

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case isDefault
        case activeWeekdays
        case selectedCalendarIDs
        case conditions
        case prepTime
        case commuteTime
        case alarmSettings
    }

    init(
        id: UUID,
        name: String,
        isDefault: Bool,
        activeWeekdays: Set<Int>,
        selectedCalendarIDs: Set<String>,
        conditions: [AlarmRuleCondition],
        prepTime: Minutes,
        commuteTime: Minutes,
        alarmSettings: RuleAlarmSettings
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.activeWeekdays = activeWeekdays
        self.selectedCalendarIDs = selectedCalendarIDs
        self.conditions = conditions
        self.prepTime = prepTime
        self.commuteTime = commuteTime
        self.alarmSettings = alarmSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        activeWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .activeWeekdays) ?? Set(1...7)
        selectedCalendarIDs = try container.decodeIfPresent(Set<String>.self, forKey: .selectedCalendarIDs) ?? []
        conditions = try container.decodeIfPresent([AlarmRuleCondition].self, forKey: .conditions) ?? []
        prepTime = try container.decodeIfPresent(Minutes.self, forKey: .prepTime) ?? Minutes(45)
        commuteTime = try container.decodeIfPresent(Minutes.self, forKey: .commuteTime) ?? Minutes(20)
        alarmSettings = try container.decodeIfPresent(RuleAlarmSettings.self, forKey: .alarmSettings) ?? .default
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(activeWeekdays, forKey: .activeWeekdays)
        try container.encode(selectedCalendarIDs, forKey: .selectedCalendarIDs)
        try container.encode(conditions, forKey: .conditions)
        try container.encode(prepTime, forKey: .prepTime)
        try container.encode(commuteTime, forKey: .commuteTime)
        try container.encode(alarmSettings, forKey: .alarmSettings)
    }
}
