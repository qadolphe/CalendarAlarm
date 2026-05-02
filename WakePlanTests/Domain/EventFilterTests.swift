import XCTest
@testable import WakePlan

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

    func testRespectsCalendarSelection() {
        var preferences = AlarmPreferences.default
        preferences.selectedCalendarIDs = ["work"]

        XCTAssertTrue(filter.shouldInclude(event(calendarID: "work"), preferences: preferences))
        XCTAssertFalse(filter.shouldInclude(event(calendarID: "personal"), preferences: preferences))
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
