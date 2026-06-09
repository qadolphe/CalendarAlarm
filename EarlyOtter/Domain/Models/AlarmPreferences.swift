import Foundation

/// A one-off manual adjustment for a single calendar date, set from the week view.
/// Keyed by `yyyy-MM-dd` so it survives plan recomputation, and always wins over
/// the recurring weekly schedule for that date only.
struct DayAlarmOverride: Codable, Equatable, Sendable {
    enum Kind: Codable, Equatable, Sendable {
        /// Wake at this fixed clock time on this day, ignoring events.
        case customTime(ClockTime)
        /// No alarm at all on this day.
        case skip
    }

    var kind: Kind
}

struct LocationRule: Codable, Equatable, Sendable {
    var label: String
    var triggerRadiusMeters: Double
    var prepAdjustment: Minutes
}

struct ScheduleRules: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var activeDays: Set<Int>
    var fallbackEnabledDays: Set<Int>
    /// Per-weekday fallback wake times. Missing key = use `TimingRules.latestWakeTime`.
    var fallbackWakeTimes: [Int: ClockTime]

    static let `default` = ScheduleRules(
        isEnabled: true,
        activeDays: Set(1...7),
        fallbackEnabledDays: [],
        fallbackWakeTimes: [:]
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
        blockedKeywords: [],
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
        ignoreTentativeEvents: false,
        ignoreCanceledEvents: false,
        ignoreFreeEvents: false,
        titleKeywords: .default
    )
}

struct AlarmPreferences: Codable, Equatable, Sendable {
    var schedule: ScheduleRules
    var timing: TimingRules
    var filters: EventFilterRules
    var locationRules: [LocationRule]
    var alarmRules: [AlarmRule]
    var isSystemEnabled: Bool

    /// One-off per-date adjustments, keyed by `yyyy-MM-dd`. See `DayAlarmOverride`.
    var dateOverrides: [String: DayAlarmOverride]

    init(
        schedule: ScheduleRules,
        timing: TimingRules,
        filters: EventFilterRules,
        locationRules: [LocationRule],
        alarmRules: [AlarmRule] = [],
        isSystemEnabled: Bool = true,
        dateOverrides: [String: DayAlarmOverride] = [:]
    ) {
        self.schedule = schedule
        self.timing = timing
        self.filters = filters
        self.locationRules = locationRules
        self.isSystemEnabled = isSystemEnabled
        self.dateOverrides = dateOverrides
        self.alarmRules = Self.normalizedAlarmRules(
            alarmRules,
            timing: timing,
            legacySelectedCalendarIDs: filters.selectedCalendarIDs
        )
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

    var fallbackEnabledDays: Set<Int> {
        get { schedule.fallbackEnabledDays }
        set { schedule.fallbackEnabledDays = newValue }
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

    /// Effective fallback wake time for a given weekday (1=Sun…7=Sat).
    func fallbackWakeTime(for weekday: Int) -> ClockTime {
        schedule.fallbackWakeTimes[weekday] ?? timing.latestWakeTime
    }

    /// Whether event-driven auto alarms run on the given weekday.
    func autoAlarmEnabled(on weekday: Int) -> Bool {
        isEnabled && activeDays.contains(weekday)
    }

    /// Whether a fixed backup alarm is set for the given weekday.
    func fixedAlarmEnabled(on weekday: Int) -> Bool {
        fallbackEnabledDays.contains(weekday)
    }

    /// True when no fixed backup alarms are configured for any day.
    var hasNoFixedAlarms: Bool {
        fallbackEnabledDays.isEmpty
    }

    // MARK: Per-date overrides

    /// The manual override (if any) for a specific calendar date.
    func override(for targetDay: TargetDay, calendar: Calendar = .current) -> DayAlarmOverride? {
        dateOverrides[Self.overrideKey(for: targetDay, calendar: calendar)]
    }

    /// Set (or clear, when `override` is `nil`) the manual override for a date.
    mutating func setOverride(
        _ override: DayAlarmOverride?,
        for targetDay: TargetDay,
        calendar: Calendar = .current
    ) {
        let key = Self.overrideKey(for: targetDay, calendar: calendar)
        if let override {
            dateOverrides[key] = override
        } else {
            dateOverrides.removeValue(forKey: key)
        }
    }

    /// Drop overrides for dates that have already passed so storage doesn't grow unbounded.
    mutating func pruneExpiredOverrides(asOf now: Date = Date(), calendar: Calendar = .current) {
        let todayKey = Self.overrideKey(for: TargetDay(date: now, calendar: calendar), calendar: calendar)
        dateOverrides = dateOverrides.filter { $0.key >= todayKey }
    }

    /// Stable, lexicographically sortable `yyyy-MM-dd` key for a target day.
    static func overrideKey(for targetDay: TargetDay, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: targetDay.date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    /// The single default rule (always present, matches any event).
    var defaultAlarmRule: AlarmRule {
        alarmRules.first(where: { $0.isDefault }) ?? AlarmRule.makeDefault(
            prepTime: timing.prepTime,
            commuteTime: timing.defaultCommuteTime,
            selectedCalendarIDs: filters.selectedCalendarIDs
        )
    }

    var fallbackAlarmSettings: RuleAlarmSettings {
        defaultAlarmRule.alarmSettings
    }

    /// User-created rules (non-default, evaluated before the default).
    var customAlarmRules: [AlarmRule] {
        alarmRules.filter { !$0.isDefault }
    }

    private static func normalizedAlarmRules(
        _ alarmRules: [AlarmRule],
        timing: TimingRules,
        legacySelectedCalendarIDs: Set<String>
    ) -> [AlarmRule] {
        var normalized = alarmRules

        if let defaultIndex = normalized.firstIndex(where: { $0.isDefault }) {
            normalized[defaultIndex].isEnabled = true
            normalized[defaultIndex].activeWeekdays = Set(1...7)
            if normalized[defaultIndex].selectedCalendarIDs.isEmpty,
               !legacySelectedCalendarIDs.isEmpty {
                normalized[defaultIndex].selectedCalendarIDs = legacySelectedCalendarIDs
            }
            return normalized
        }

        normalized.append(
            AlarmRule.makeDefault(
                prepTime: timing.prepTime,
                commuteTime: timing.defaultCommuteTime,
                selectedCalendarIDs: legacySelectedCalendarIDs
            )
        )
        return normalized
    }
}

extension AlarmPreferences {
    private enum CodingKeys: String, CodingKey {
        case schedule
        case timing
        case filters
        case locationRules
        case alarmRules
        case isSystemEnabled
        case dateOverrides

        case isEnabled
        case prepTime
        case latestWakeTime
        case defaultCommuteTime
        case activeDays
        case fallbackEnabledDays
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
            isSystemEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSystemEnabled) ?? true
            dateOverrides = try container.decodeIfPresent([String: DayAlarmOverride].self, forKey: .dateOverrides) ?? [:]
            alarmRules = Self.normalizedAlarmRules(
                decoded,
                timing: decodedTiming,
                legacySelectedCalendarIDs: filters.selectedCalendarIDs
            )
            return
        }

        isSystemEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSystemEnabled) ?? true
        dateOverrides = try container.decodeIfPresent([String: DayAlarmOverride].self, forKey: .dateOverrides) ?? [:]

        let decodedActiveDays = try container.decodeIfPresent(Set<Int>.self, forKey: .activeDays) ?? ScheduleRules.default.activeDays
        schedule = ScheduleRules(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? ScheduleRules.default.isEnabled,
            activeDays: decodedActiveDays,
            fallbackEnabledDays: try container.decodeIfPresent(Set<Int>.self, forKey: .fallbackEnabledDays) ?? decodedActiveDays,
            fallbackWakeTimes: [:]
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
        alarmRules = Self.normalizedAlarmRules(
            legacyDecoded,
            timing: timing,
            legacySelectedCalendarIDs: filters.selectedCalendarIDs
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(timing, forKey: .timing)
        try container.encode(filters, forKey: .filters)
        try container.encode(locationRules, forKey: .locationRules)
        try container.encode(alarmRules, forKey: .alarmRules)
        try container.encode(isSystemEnabled, forKey: .isSystemEnabled)
        try container.encode(dateOverrides, forKey: .dateOverrides)
    }
}
