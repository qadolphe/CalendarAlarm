import XCTest
@testable import EarlyOtter

final class EventFilterTests: XCTestCase {
    private let filter = EventFilter()

    func testIgnoresAllDayEventsWhenPreferenceEnabled() {
        var preferences = AlarmPreferences.default
        preferences.ignoreAllDayEvents = true

        XCTAssertFalse(filter.shouldInclude(event(isAllDay: true), preferences: preferences))
    }

    func testIgnoresTentativeEventsWhenPreferenceEnabled() {
        var preferences = AlarmPreferences.default
        preferences.ignoreTentativeEvents = true

        XCTAssertFalse(filter.shouldInclude(event(status: .tentative), preferences: preferences))
    }

    func testIgnoresCanceledEventsWhenPreferenceEnabled() {
        var preferences = AlarmPreferences.default
        preferences.ignoreCanceledEvents = true

        XCTAssertFalse(filter.shouldInclude(event(status: .canceled), preferences: preferences))
    }

    func testIgnoresFreeEventsWhenPreferenceEnabled() {
        var preferences = AlarmPreferences.default
        preferences.ignoreFreeEvents = true

        XCTAssertFalse(filter.shouldInclude(event(availability: .free), preferences: preferences))
    }

    func testDoesNotFilterByLegacyCalendarSelection() {
        var preferences = AlarmPreferences.default
        preferences.selectedCalendarIDs = ["work"]

        XCTAssertTrue(filter.shouldInclude(event(calendarID: "work"), preferences: preferences))
        XCTAssertTrue(filter.shouldInclude(event(calendarID: "personal"), preferences: preferences))
    }

    func testRespectsTitleBlocklist() {
        var preferences = AlarmPreferences.default
        preferences.titleBlocklist = ["vacation"]

        XCTAssertFalse(filter.shouldInclude(event(title: "Summer Vacation"), preferences: preferences))
    }

    func testRespectsTitleAllowlist() {
        var preferences = AlarmPreferences.default
        preferences.titleAllowlist = ["onsite", "client"]
        preferences.titleBlocklist = []

        XCTAssertTrue(filter.shouldInclude(event(title: "Client Onsite"), preferences: preferences))
        XCTAssertFalse(filter.shouldInclude(event(title: "Gym"), preferences: preferences))
    }

    func testDecodesLegacyFlatPreferencesPayloadIntoTypedRules() throws {
        let data = """
        {
          "isEnabled": true,
          "prepTime": { "rawValue": 35 },
          "latestWakeTime": { "hour": 7, "minute": 45 },
          "defaultCommuteTime": { "rawValue": 15 },
          "activeDays": [1, 2, 3, 4, 5],
          "locationRules": [],
          "selectedCalendarIDs": ["work"],
          "ignoreAllDayEvents": true,
          "ignoreTentativeEvents": false,
          "ignoreCanceledEvents": true,
          "ignoreFreeEvents": true,
          "titleBlocklist": ["vacation"],
          "titleAllowlist": ["onsite"]
        }
        """.data(using: .utf8)!

        let preferences = try JSONDecoder().decode(AlarmPreferences.self, from: data)

        XCTAssertTrue(preferences.schedule.isEnabled)
        XCTAssertEqual(preferences.schedule.activeDays, Set([1, 2, 3, 4, 5]))
        XCTAssertEqual(preferences.timing.prepTime, Minutes(35))
        XCTAssertEqual(preferences.timing.defaultCommuteTime, Minutes(15))
        XCTAssertEqual(preferences.defaultAlarmRule.selectedCalendarIDs, Set(["work"]))
        XCTAssertEqual(preferences.filters.selectedCalendarIDs, Set(["work"]))
        XCTAssertEqual(preferences.filters.titleKeywords.blockedKeywords, ["vacation"])
        XCTAssertEqual(preferences.filters.titleKeywords.allowedKeywords, ["onsite"])
    }

        func testAlarmRuleDecodesMissingEnabledFlagAsEnabled() throws {
                let data = """
                {
                    "id": "0E0A4470-4785-4B3A-9C23-FA4A845C4C0E",
                    "name": "Office",
                    "isDefault": false,
                    "activeWeekdays": [1, 2, 3, 4, 5, 6, 7],
                    "selectedCalendarIDs": ["work"],
                    "conditions": [{ "type": "titleContains", "value": "office" }],
                    "prepTime": { "rawValue": 45 },
                    "commuteTime": { "rawValue": 20 },
                    "alarmSettings": {
                        "sound": "default",
                        "snoozeEnabled": true,
                        "snoozeDuration": { "rawValue": 10 }
                    }
                }
                """.data(using: .utf8)!

                let rule = try JSONDecoder().decode(AlarmRule.self, from: data)

                XCTAssertTrue(rule.isEnabled)
        }

    private func event(
        calendarID: String = "work",
        title: String = "Standup",
        isAllDay: Bool = false,
        status: ParsedEventStatus = .confirmed,
        availability: ParsedEventAvailability = .busy
    ) -> ParsedEvent {
        ParsedEvent(
            id: UUID().uuidString,
            calendarID: calendarID,
            title: title,
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            timeZoneIdentifier: nil,
            isAllDay: isAllDay,
            status: status,
            availability: availability,
            location: nil,
            notes: nil
        )
    }
}
