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
    func events(in interval: DateInterval, calendar: Calendar) async throws -> [ParsedEvent]
}

extension CalendarEventProviding {
    func events(in interval: DateInterval, calendar: Calendar) async throws -> [ParsedEvent] {
        guard interval.duration > 0 else { return [] }

        var merged: [ParsedEvent] = []
        var cursor = calendar.startOfDay(for: interval.start)

        while cursor < interval.end {
            let targetDay = TargetDay(date: cursor, calendar: calendar)
            merged.append(contentsOf: try await events(for: targetDay))

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }

            cursor = nextDay
        }

        return merged
            .filter { interval.contains($0.startDate) }
            .sorted { $0.startDate < $1.startDate }
    }
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
