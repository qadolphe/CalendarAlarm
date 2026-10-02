import Foundation

enum AlarmSoundOption: String, Codable, CaseIterable, Equatable, Sendable {
    // Resolved by the system alarm process when the alarm fires, so it has no
    // file this app can reach. Kept first in the list as the standard choice.
    case `default`
    case sunrise
    case starlight
    case otter
    case tide
    case classic

    // Where settings saved against a retired tone land.
    static let standard: AlarmSoundOption = .default

    var displayName: String {
        switch self {
        case .default:      return "Default"
        case .sunrise:      return "Sunrise"
        case .starlight:    return "Starlight"
        case .otter:        return "Otter"
        case .tide:         return "Tide"
        case .classic:      return "Classic"
        }
    }

    // File name handed to AlarmKit's `AlertSound.named(_:)` and to the picker's
    // preview player, both of which resolve it against the app bundle. `nil`
    // means the system alarm sound, which only iOS itself can play.
    var resourceName: String? {
        switch self {
        case .default:      return nil
        default:            return "Alarm\(rawValue.capitalized).wav"
        }
    }

    // Shown under the row name to explain why tapping it stays silent.
    var subtitle: String? {
        switch self {
        case .default:  return "Played by iOS when the alarm fires"
        default:        return nil
        }
    }

    // Preferences saved before the sound list was trimmed may still name a tone
    // that no longer ships, so decode unknown names to the standard tone rather
    // than failing the whole preferences load.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AlarmSoundOption(rawValue: raw) ?? .standard
    }
}

struct RuleAlarmSettings: Codable, Equatable, Sendable {
    var sound: AlarmSoundOption
    var snoozeEnabled: Bool
    var snoozeDuration: Minutes

    static let `default` = RuleAlarmSettings(
        sound: .standard,
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

    var titleKeyword: String? {
        if case .titleContains(let keyword) = self { return keyword }
        return nil
    }

    var locationKeyword: String? {
        if case .locationContains(let place) = self { return place }
        return nil
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
/// How a rule is represented in lists. Semantic cases; the UI maps them to symbols.
enum RuleSymbol: String, Codable, CaseIterable, Sendable {
    case general, school, work, flight, gym, run, medical, meeting, drive, study, music, sun
}

struct AlarmRule: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    /// When true this rule matches every event (no conditions evaluated).
    var isDefault: Bool
    var isEnabled: Bool
    var activeWeekdays: Set<Int>
    var selectedCalendarIDs: Set<String>
    var conditions: [AlarmRuleCondition]
    var prepTime: Minutes
    var commuteTime: Minutes
    var alarmSettings: RuleAlarmSettings
    var extraAlarms: ExtraAlarms
    var symbol: RuleSymbol

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
            isEnabled: true,
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
        guard isEnabled || isDefault else {
            return false
        }

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
        case isEnabled
        case activeWeekdays
        case selectedCalendarIDs
        case conditions
        case prepTime
        case commuteTime
        case alarmSettings
        case extraAlarms
        case symbol
    }

    init(
        id: UUID,
        name: String,
        isDefault: Bool,
        isEnabled: Bool = true,
        activeWeekdays: Set<Int>,
        selectedCalendarIDs: Set<String>,
        conditions: [AlarmRuleCondition],
        prepTime: Minutes,
        commuteTime: Minutes,
        alarmSettings: RuleAlarmSettings,
        extraAlarms: ExtraAlarms = .none,
        symbol: RuleSymbol = .general
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.isEnabled = isEnabled
        self.activeWeekdays = activeWeekdays
        self.selectedCalendarIDs = selectedCalendarIDs
        self.conditions = conditions
        self.prepTime = prepTime
        self.commuteTime = commuteTime
        self.alarmSettings = alarmSettings
        self.extraAlarms = extraAlarms
        self.symbol = symbol
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        activeWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .activeWeekdays) ?? Set(1...7)
        selectedCalendarIDs = try container.decodeIfPresent(Set<String>.self, forKey: .selectedCalendarIDs) ?? []
        conditions = try container.decodeIfPresent([AlarmRuleCondition].self, forKey: .conditions) ?? []
        prepTime = try container.decodeIfPresent(Minutes.self, forKey: .prepTime) ?? Minutes(45)
        commuteTime = try container.decodeIfPresent(Minutes.self, forKey: .commuteTime) ?? Minutes(20)
        alarmSettings = try container.decodeIfPresent(RuleAlarmSettings.self, forKey: .alarmSettings) ?? .default
        extraAlarms = try container.decodeIfPresent(ExtraAlarms.self, forKey: .extraAlarms) ?? .none
        // Rules saved before icons existed, or with an unknown icon, fall back to the generic one.
        symbol = (try? container.decodeIfPresent(RuleSymbol.self, forKey: .symbol)) ?? .general
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(activeWeekdays, forKey: .activeWeekdays)
        try container.encode(selectedCalendarIDs, forKey: .selectedCalendarIDs)
        try container.encode(conditions, forKey: .conditions)
        try container.encode(prepTime, forKey: .prepTime)
        try container.encode(commuteTime, forKey: .commuteTime)
        try container.encode(alarmSettings, forKey: .alarmSettings)
        try container.encode(extraAlarms, forKey: .extraAlarms)
        try container.encode(symbol, forKey: .symbol)
    }
}
