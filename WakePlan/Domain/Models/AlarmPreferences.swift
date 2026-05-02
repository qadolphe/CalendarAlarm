import Foundation

struct AlarmPreferences: Codable, Equatable, Sendable {
    var isEnabled: Bool

    var prepTime: Minutes
    var latestWakeTime: ClockTime
    var defaultCommuteTime: Minutes

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
        selectedCalendarIDs: [],
        ignoreAllDayEvents: true,
        ignoreTentativeEvents: true,
        ignoreCanceledEvents: true,
        ignoreFreeEvents: true,
        titleBlocklist: ["ooo", "pto", "vacation", "holiday"],
        titleAllowlist: []
    )
}
