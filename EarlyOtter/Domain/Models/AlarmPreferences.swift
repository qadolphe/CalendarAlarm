import Foundation

/// A one-off manual adjustment for a single calendar date, set from the week view.
/// Keyed by `yyyy-MM-dd` so it survives plan recomputation, and always wins over
/// the recurring weekly schedule for that date only.
struct DayAlarmOverride: Codable, Equatable, Sendable {
    /// A fixed wake time the user chose for this day. `nil` means "follow the
    /// automatic schedule" — so a skipped automatic day restores to automatic
    /// (with its event/prep/commute) rather than a pinned time.
    var customWakeTime: ClockTime?
    /// When true, no alarm fires this day (the underlying time source is kept).
    var isSkipped: Bool

    init(customWakeTime: ClockTime?, isSkipped: Bool = false) {
        self.customWakeTime = customWakeTime
        self.isSkipped = isSkipped
    }
}

extension DayAlarmOverride {
    private enum CodingKeys: String, CodingKey {
        case customWakeTime
        case isSkipped
        case wakeTime // legacy: a non-optional chosen time
        case kind     // legacy: an either/or custom-time-or-skip enum
    }

    /// The original either/or shape, kept only to migrate the earliest saved overrides.
    private enum LegacyKind: Codable {
        case customTime(ClockTime)
        case skip
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Oldest shape: `{ kind: .customTime | .skip }`.
        if container.contains(.kind) {
            switch try container.decode(LegacyKind.self, forKey: .kind) {
            case .customTime(let time):
                customWakeTime = time
                isSkipped = false
            case .skip:
                customWakeTime = nil
                isSkipped = true
            }
            return
        }

        // Previous shape: a non-optional `wakeTime` that always counted as custom.
        if let wakeTime = try container.decodeIfPresent(ClockTime.self, forKey: .wakeTime) {
            customWakeTime = wakeTime
            isSkipped = try container.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
            return
        }

        // Current shape: optional `customWakeTime` (nil = automatic) + `isSkipped`.
        customWakeTime = try container.decodeIfPresent(ClockTime.self, forKey: .customWakeTime)
        isSkipped = try container.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(customWakeTime, forKey: .customWakeTime)
        try container.encode(isSkipped, forKey: .isSkipped)
    }
}

struct LocationRule: Codable, Equatable, Sendable {
    var label: String
    var triggerRadiusMeters: Double
    var prepAdjustment: Minutes
}

struct ScheduleRules: Codable, Equatable, Sendable {
    var isEnabled: Bool
    /// Weekdays calendar alarms run on.
    var activeDays: Set<Int>
    var alarms: [StandardAlarm]

    static let `default` = ScheduleRules(
        isEnabled: true,
        activeDays: Set(1...7),
        alarms: []
    )
}

extension ScheduleRules {
    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case activeDays
        case alarms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        activeDays = try container.decode(Set<Int>.self, forKey: .activeDays)
        // Schedules saved before standard alarms get theirs from `LegacyStandbySchedule`.
        alarms = try container.decodeIfPresent([StandardAlarm].self, forKey: .alarms) ?? []
    }
}

/// The standby fields a schedule carried before standard alarms replaced them.
private struct LegacyStandbySchedule: Decodable {
    let alarms: [StandardAlarm]?
    let fallbackEnabledDays: Set<Int>?
    let fallbackWakeTimes: [Int: ClockTime]?

    var needsMigration: Bool {
        alarms == nil
    }
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

    var standardAlarms: [StandardAlarm] {
        get { schedule.alarms }
        set { schedule.alarms = newValue }
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

    /// Turns off one-time alarms whose ring time has passed, like the Clock app.
    mutating func disableFiredOneTimeAlarms(now: Date = Date(), calendar: Calendar = .current) {
        for index in schedule.alarms.indices where schedule.alarms[index].hasFired(now: now, calendar: calendar) {
            schedule.alarms[index].isEnabled = false
        }
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

    /// Drop overrides older than the retained history window so storage doesn't grow unbounded.
    /// Retaining previous days allows elapsed dashboard entries to preserve their one-off state.
    mutating func pruneExpiredOverrides(
        asOf now: Date = Date(),
        retainingPreviousDays: Int = 0,
        calendar: Calendar = .current
    ) {
        let retentionDays = max(retainingPreviousDays, 0)
        let earliestRetainedDate = calendar.date(
            byAdding: .day,
            value: -retentionDays,
            to: now
        ) ?? now
        let earliestRetainedKey = Self.overrideKey(
            for: TargetDay(date: earliestRetainedDate, calendar: calendar),
            calendar: calendar
        )
        dateOverrides = dateOverrides.filter { $0.key >= earliestRetainedKey }
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

    var defaultAlarmSettings: RuleAlarmSettings {
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
            if let legacy = try? container.decodeIfPresent(LegacyStandbySchedule.self, forKey: .schedule),
               legacy.needsMigration {
                schedule.alarms = StandardAlarm.migratedStandby(
                    days: legacy.fallbackEnabledDays ?? [],
                    times: legacy.fallbackWakeTimes ?? [:],
                    defaultTime: decodedTiming.latestWakeTime,
                    settings: defaultAlarmRule.alarmSettings
                )
            }
            return
        }

        isSystemEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSystemEnabled) ?? true
        dateOverrides = try container.decodeIfPresent([String: DayAlarmOverride].self, forKey: .dateOverrides) ?? [:]

        let decodedActiveDays = try container.decodeIfPresent(Set<Int>.self, forKey: .activeDays) ?? ScheduleRules.default.activeDays
        let legacyStandbyDays = try container.decodeIfPresent(Set<Int>.self, forKey: .fallbackEnabledDays) ?? decodedActiveDays
        schedule = ScheduleRules(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? ScheduleRules.default.isEnabled,
            activeDays: decodedActiveDays,
            alarms: []
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
        schedule.alarms = StandardAlarm.migratedStandby(
            days: legacyStandbyDays,
            times: [:],
            defaultTime: timing.latestWakeTime,
            settings: defaultAlarmRule.alarmSettings
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
