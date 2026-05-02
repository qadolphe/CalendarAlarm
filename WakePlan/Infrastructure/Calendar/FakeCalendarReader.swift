import Foundation

#if DEBUG
final class FakeCalendarReader: CalendarReading {
    private enum FakeCalendarID {
        static let work = "fake-work"
        static let personal = "fake-personal"
        static let testing = "fake-testing"
    }

    func authorizationState() -> CalendarAuthorizationState {
        .authorized
    }

    func requestAuthorization() async throws -> CalendarAuthorizationState {
        .authorized
    }

    func calendars() async throws -> [CalendarSource] {
        [
            CalendarSource(id: FakeCalendarID.work, title: "Work", isSelected: true),
            CalendarSource(id: FakeCalendarID.personal, title: "Personal", isSelected: true),
            CalendarSource(id: FakeCalendarID.testing, title: "Testing", isSelected: true)
        ]
    }

    func events(
        for targetDay: TargetDay,
        selectedCalendarIDs: Set<String>
    ) async throws -> [ParsedEvent] {
        let allEvents = makeEvents(for: targetDay)

        guard !selectedCalendarIDs.isEmpty else {
            return allEvents
        }

        return allEvents.filter { selectedCalendarIDs.contains($0.calendarID) }
    }

    private func makeEvents(for targetDay: TargetDay) -> [ParsedEvent] {
        let calendar = Calendar.current

        return [
            ParsedEvent(
                id: "fake-design-review",
                calendarID: FakeCalendarID.work,
                title: "Design Review",
                startDate: date(hour: 8, minute: 30, on: targetDay, calendar: calendar),
                endDate: date(hour: 9, minute: 0, on: targetDay, calendar: calendar),
                timeZoneIdentifier: calendar.timeZone.identifier,
                isAllDay: false,
                status: .confirmed,
                availability: .busy,
                location: "Studio A",
                notes: "Fake data for dashboard testing"
            ),
            ParsedEvent(
                id: "fake-standup",
                calendarID: FakeCalendarID.work,
                title: "Standup",
                startDate: date(hour: 9, minute: 15, on: targetDay, calendar: calendar),
                endDate: date(hour: 9, minute: 30, on: targetDay, calendar: calendar),
                timeZoneIdentifier: calendar.timeZone.identifier,
                isAllDay: false,
                status: .confirmed,
                availability: .busy,
                location: nil,
                notes: "Secondary valid event"
            ),
            ParsedEvent(
                id: "fake-pto",
                calendarID: FakeCalendarID.personal,
                title: "PTO",
                startDate: targetDay.interval(calendar: calendar).start,
                endDate: targetDay.interval(calendar: calendar).end,
                timeZoneIdentifier: calendar.timeZone.identifier,
                isAllDay: true,
                status: .confirmed,
                availability: .unavailable,
                location: nil,
                notes: "All-day event to verify filtering"
            ),
            ParsedEvent(
                id: "fake-free-hold",
                calendarID: FakeCalendarID.testing,
                title: "Free Test Event",
                startDate: date(hour: 7, minute: 0, on: targetDay, calendar: calendar),
                endDate: date(hour: 7, minute: 30, on: targetDay, calendar: calendar),
                timeZoneIdentifier: calendar.timeZone.identifier,
                isAllDay: false,
                status: .confirmed,
                availability: .free,
                location: nil,
                notes: "Should be ignored while ignoreFreeEvents is enabled"
            )
        ]
    }

    private func date(hour: Int, minute: Int, on targetDay: TargetDay, calendar: Calendar) -> Date {
        ClockTime(hour: hour, minute: minute).date(on: targetDay, calendar: calendar)
    }
}
#endif
