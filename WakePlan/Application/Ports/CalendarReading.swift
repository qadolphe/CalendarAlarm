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
}

protocol CalendarEventProviding {
    func accounts() async throws -> [ConnectedCalendarAccount]
    func calendars() async throws -> [CalendarSource]
    func events(for targetDay: TargetDay) async throws -> [ParsedEvent]
}

protocol AccountStoring {
    func load() throws -> [ConnectedCalendarAccount]
    func save(_ accounts: [ConnectedCalendarAccount]) throws
}

struct GoogleAccountAuthResult: Equatable, Sendable {
    let accountID: CalendarAccountID
    let matchingAccountIDs: Set<CalendarAccountID>
    let displayName: String
    let email: String
}

protocol GoogleAccountAuthenticating {
    @MainActor
    func signIn() async throws -> GoogleAccountAuthResult
}
