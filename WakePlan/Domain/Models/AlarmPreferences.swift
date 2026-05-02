import Foundation

struct LocationRule: Codable, Equatable, Sendable {
    var label: String
    var triggerRadiusMeters: Double
    var prepAdjustment: Minutes
}

struct AlarmPreferences: Codable, Equatable, Sendable {
    var isEnabled: Bool

    var prepTime: Minutes
    var latestWakeTime: ClockTime
    var defaultCommuteTime: Minutes

    var activeDays: Set<Int>
    var locationRules: [LocationRule]

    var selectedCalendarIDs: Set<String>

    var ignoreAllDayEvents: Bool
    var ignoreTentativeEvents: Bool
    var ignoreCanceledEvents: Bool
    var ignoreFreeEvents: Bool

    var titleBlocklist: [String]
    var titleAllowlist: [String]

    static let `default` = AlarmPreferences(
        isEnabled: true,
        prepTime: Minutes(45),
        latestWakeTime: .defaultLatestWakeTime,
        defaultCommuteTime: Minutes(20),
        activeDays: Set(1...7),
        locationRules: [],
        selectedCalendarIDs: [],
        ignoreAllDayEvents: true,
        ignoreTentativeEvents: true,
        ignoreCanceledEvents: true,
        ignoreFreeEvents: true,
        titleBlocklist: ["ooo", "pto", "vacation", "holiday"],
        titleAllowlist: []
    )
}
