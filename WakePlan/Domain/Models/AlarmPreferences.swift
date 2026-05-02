import Foundation

struct LocationRule: Codable, Equatable, Sendable {
    var label: String
    var triggerRadiusMeters: Double
    var prepAdjustment: Minutes
}

struct ScheduleRules: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var activeDays: Set<Int>

    static let `default` = ScheduleRules(
        isEnabled: true,
        activeDays: Set(1...7)
    )
}

struct TimingRules: Codable, Equatable, Sendable {
    var prepTime: Minutes
    var latestWakeTime: ClockTime
    var defaultCommuteTime: Minutes

    static let `default` = TimingRules(
        prepTime: Minutes(45),
        latestWakeTime: .defaultLatestWakeTime,
        defaultCommuteTime: Minutes(20)
    )
}

struct TitleKeywordRules: Codable, Equatable, Sendable {
    var blockedKeywords: [String]
    var allowedKeywords: [String]

    static let `default` = TitleKeywordRules(
        blockedKeywords: ["ooo", "pto", "vacation", "holiday"],
        allowedKeywords: []
    )
}

struct EventFilterRules: Codable, Equatable, Sendable {
    var selectedCalendarIDs: Set<String>
    var ignoreAllDayEvents: Bool
    var ignoreTentativeEvents: Bool
    var ignoreCanceledEvents: Bool
    var ignoreFreeEvents: Bool
    var titleKeywords: TitleKeywordRules

    static let `default` = EventFilterRules(
        selectedCalendarIDs: [],
        ignoreAllDayEvents: true,
        ignoreTentativeEvents: true,
        ignoreCanceledEvents: true,
        ignoreFreeEvents: true,
        titleKeywords: .default
    )
}

struct AlarmPreferences: Codable, Equatable, Sendable {
    var schedule: ScheduleRules
    var timing: TimingRules
    var filters: EventFilterRules
    var locationRules: [LocationRule]
    var alarmRules: [AlarmRule]

    init(
        schedule: ScheduleRules,
        timing: TimingRules,
        filters: EventFilterRules,
        locationRules: [LocationRule],
        alarmRules: [AlarmRule] = []
    ) {
        self.schedule = schedule
        self.timing = timing
        self.filters = filters
        self.locationRules = locationRules
        // Ensure there is always a default rule.
        if alarmRules.contains(where: { $0.isDefault }) {
            self.alarmRules = alarmRules
        } else {
            self.alarmRules = alarmRules + [AlarmRule.makeDefault(
                prepTime: timing.prepTime,
                commuteTime: timing.defaultCommuteTime
            )]
        }
    }

    static let `default` = AlarmPreferences(
        schedule: .default,
        timing: .default,
        filters: .default,
        locationRules: [],
        alarmRules: [AlarmRule.makeDefault()]
    )

    var isEnabled: Bool {
        get { schedule.isEnabled }
        set { schedule.isEnabled = newValue }
    }

    var prepTime: Minutes {
        get { timing.prepTime }
        set { timing.prepTime = newValue }
    }

    var latestWakeTime: ClockTime {
        get { timing.latestWakeTime }
        set { timing.latestWakeTime = newValue }
    }

    var defaultCommuteTime: Minutes {
        get { timing.defaultCommuteTime }
        set { timing.defaultCommuteTime = newValue }
    }

    var activeDays: Set<Int> {
        get { schedule.activeDays }
        set { schedule.activeDays = newValue }
    }

    var selectedCalendarIDs: Set<String> {
        get { filters.selectedCalendarIDs }
        set { filters.selectedCalendarIDs = newValue }
    }

    var ignoreAllDayEvents: Bool {
        get { filters.ignoreAllDayEvents }
        set { filters.ignoreAllDayEvents = newValue }
    }

    var ignoreTentativeEvents: Bool {
        get { filters.ignoreTentativeEvents }
        set { filters.ignoreTentativeEvents = newValue }
    }

    var ignoreCanceledEvents: Bool {
        get { filters.ignoreCanceledEvents }
        set { filters.ignoreCanceledEvents = newValue }
    }

    var ignoreFreeEvents: Bool {
        get { filters.ignoreFreeEvents }
        set { filters.ignoreFreeEvents = newValue }
    }

    var titleBlocklist: [String] {
        get { filters.titleKeywords.blockedKeywords }
        set { filters.titleKeywords.blockedKeywords = newValue }
    }

    var titleAllowlist: [String] {
        get { filters.titleKeywords.allowedKeywords }
        set { filters.titleKeywords.allowedKeywords = newValue }
    }

    /// The single default rule (always present, matches any event).
    var defaultAlarmRule: AlarmRule {
        alarmRules.first(where: { $0.isDefault }) ?? AlarmRule.makeDefault(
            prepTime: timing.prepTime,
            commuteTime: timing.defaultCommuteTime
        )
    }

    /// User-created rules (non-default, evaluated before the default).
    var customAlarmRules: [AlarmRule] {
        alarmRules.filter { !$0.isDefault }
    }
}

extension AlarmPreferences {
    private enum CodingKeys: String, CodingKey {
        case schedule
        case timing
        case filters
        case locationRules
        case alarmRules

        case isEnabled
        case prepTime
        case latestWakeTime
        case defaultCommuteTime
        case activeDays
        case selectedCalendarIDs
        case ignoreAllDayEvents
        case ignoreTentativeEvents
        case ignoreCanceledEvents
        case ignoreFreeEvents
        case titleBlocklist
        case titleAllowlist
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.schedule) || container.contains(.timing) || container.contains(.filters) {
            let decodedSchedule = try container.decodeIfPresent(ScheduleRules.self, forKey: .schedule) ?? .default
            let decodedTiming = try container.decodeIfPresent(TimingRules.self, forKey: .timing) ?? .default
            schedule = decodedSchedule
            timing = decodedTiming
            filters = try container.decodeIfPresent(EventFilterRules.self, forKey: .filters) ?? .default
            locationRules = try container.decodeIfPresent([LocationRule].self, forKey: .locationRules) ?? []
            let decoded = try container.decodeIfPresent([AlarmRule].self, forKey: .alarmRules) ?? []
            if decoded.contains(where: { $0.isDefault }) {
                alarmRules = decoded
            } else {
                alarmRules = decoded + [AlarmRule.makeDefault(prepTime: decodedTiming.prepTime, commuteTime: decodedTiming.defaultCommuteTime)]
            }
            return
        }

        schedule = ScheduleRules(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? ScheduleRules.default.isEnabled,
            activeDays: try container.decodeIfPresent(Set<Int>.self, forKey: .activeDays) ?? ScheduleRules.default.activeDays
        )
        timing = TimingRules(
            prepTime: try container.decodeIfPresent(Minutes.self, forKey: .prepTime) ?? TimingRules.default.prepTime,
            latestWakeTime: try container.decodeIfPresent(ClockTime.self, forKey: .latestWakeTime) ?? TimingRules.default.latestWakeTime,
            defaultCommuteTime: try container.decodeIfPresent(Minutes.self, forKey: .defaultCommuteTime) ?? TimingRules.default.defaultCommuteTime
        )
        filters = EventFilterRules(
            selectedCalendarIDs: try container.decodeIfPresent(Set<String>.self, forKey: .selectedCalendarIDs) ?? EventFilterRules.default.selectedCalendarIDs,
            ignoreAllDayEvents: try container.decodeIfPresent(Bool.self, forKey: .ignoreAllDayEvents) ?? EventFilterRules.default.ignoreAllDayEvents,
            ignoreTentativeEvents: try container.decodeIfPresent(Bool.self, forKey: .ignoreTentativeEvents) ?? EventFilterRules.default.ignoreTentativeEvents,
            ignoreCanceledEvents: try container.decodeIfPresent(Bool.self, forKey: .ignoreCanceledEvents) ?? EventFilterRules.default.ignoreCanceledEvents,
            ignoreFreeEvents: try container.decodeIfPresent(Bool.self, forKey: .ignoreFreeEvents) ?? EventFilterRules.default.ignoreFreeEvents,
            titleKeywords: TitleKeywordRules(
                blockedKeywords: try container.decodeIfPresent([String].self, forKey: .titleBlocklist) ?? TitleKeywordRules.default.blockedKeywords,
                allowedKeywords: try container.decodeIfPresent([String].self, forKey: .titleAllowlist) ?? TitleKeywordRules.default.allowedKeywords
            )
        )
        locationRules = try container.decodeIfPresent([LocationRule].self, forKey: .locationRules) ?? []
        let legacyDecoded = try container.decodeIfPresent([AlarmRule].self, forKey: .alarmRules) ?? []
        if legacyDecoded.contains(where: { $0.isDefault }) {
            alarmRules = legacyDecoded
        } else {
            alarmRules = legacyDecoded + [AlarmRule.makeDefault(prepTime: timing.prepTime, commuteTime: timing.defaultCommuteTime)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(timing, forKey: .timing)
        try container.encode(filters, forKey: .filters)
        try container.encode(locationRules, forKey: .locationRules)
        try container.encode(alarmRules, forKey: .alarmRules)
    }
}
