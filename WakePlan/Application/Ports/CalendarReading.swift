import Foundation

enum CalendarAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unknown
}

protocol CalendarReading {
    func authorizationState() -> CalendarAuthorizationState
    func requestAuthorization() async throws -> CalendarAuthorizationState

    func calendars() async throws -> [CalendarSource]

    func events(
        for targetDay: TargetDay,
        selectedCalendarIDs: Set<String>
    ) async throws -> [ParsedEvent]
}
