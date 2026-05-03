import EventKit
import Foundation
import GoogleSignIn

final class EventKitCalendarReader: CalendarReading {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func authorizationState() -> CalendarAuthorizationState {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            return .notDetermined
        case .fullAccess:
            return .authorized
        case .writeOnly:
            return .denied
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }

    func requestAuthorization() async throws -> CalendarAuthorizationState {
        if #available(iOS 17.0, *) {
            let granted = try await eventStore.requestFullAccessToEvents()
            return granted ? .authorized : .denied
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted ? .authorized : .denied)
                    }
                }
            }
        }
    }

    func availableCalendars() async throws -> [CalendarSource] {
        eventStore.calendars(for: .event).map {
            CalendarSource(
                id: $0.calendarIdentifier,
                title: $0.title,
                isSelected: true,
                accountID: AppleCalendarProvider.appleAccountID,
                provider: .apple
            )
        }
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        let calendars = eventStore.calendars(for: .event)
        let interval = targetDay.interval(calendar: .current)

        let predicate = eventStore.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: calendars
        )

        return eventStore.events(matching: predicate).map { EventKitMappers.map($0) }
    }
}

struct AppleCalendarProvider: CalendarEventProviding {
    static let appleAccountID: CalendarAccountID = "apple.calendar"

    private let calendarReader: EventKitCalendarReader
    private let accountStore: AccountStoring

    init(calendarReader: EventKitCalendarReader, accountStore: AccountStoring) {
        self.calendarReader = calendarReader
        self.accountStore = accountStore
    }

    func accounts() async throws -> [ConnectedCalendarAccount] {
        let stored = try? accountStore.load()
        let isEnabled = stored?.first(where: { $0.id == Self.appleAccountID })?.isEnabled ?? true
        return [
            ConnectedCalendarAccount(
                id: Self.appleAccountID,
                provider: .apple,
                displayName: "Apple Calendar",
                isEnabled: isEnabled
            )
        ]
    }

    func calendars() async throws -> [CalendarSource] {
        try await calendarReader.availableCalendars()
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        try await calendarReader.events(for: targetDay)
    }
}

struct GoogleCalendarProvider: CalendarEventProviding {
    private static let calendarReadonlyScope = "https://www.googleapis.com/auth/calendar.readonly"

    private let accountStore: AccountStoring
    private let session: URLSession

    init(
        accountStore: AccountStoring,
        session: URLSession = .shared
    ) {
        self.accountStore = accountStore
        self.session = session
    }

    func accounts() async throws -> [ConnectedCalendarAccount] {
        try accountStore.load()
            .filter { $0.provider == .google }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func calendars() async throws -> [CalendarSource] {
        let enabledAccounts = try await googleEnabledAccounts()
        guard !enabledAccounts.isEmpty else { return [] }

        let user = try await currentGoogleUser()
        guard let user else {
            return []
        }

        let refreshedUser = try validatedCalendarAccess(for: user)
        guard let account = matchingAccount(for: refreshedUser, in: enabledAccounts) else {
            return []
        }

        let calendarList = try await fetchCalendarList(accessToken: refreshedUser.accessToken.tokenString)

        return calendarList.items.map { calendar in
            CalendarSource(
                id: Self.calendarSourceID(for: calendar.id),
                title: calendar.summary,
                isSelected: true,
                accountID: account.id,
                provider: .google
            )
        }
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        let enabledAccounts = try await googleEnabledAccounts()
        guard !enabledAccounts.isEmpty else { return [] }

        let user = try await currentGoogleUser()
        guard let user else { return [] }

        let refreshedUser = try validatedCalendarAccess(for: user)
        guard let account = matchingAccount(for: refreshedUser, in: enabledAccounts) else {
            return []
        }

        let accountID = account.id
        let calendarList = try await fetchCalendarList(accessToken: refreshedUser.accessToken.tokenString)
        let interval = targetDay.interval(calendar: .current)

        var merged: [ParsedEvent] = []

        try await withThrowingTaskGroup(of: [ParsedEvent].self) { group in
            for calendar in calendarList.items {
                group.addTask {
                    let events = try await fetchEvents(
                        accessToken: refreshedUser.accessToken.tokenString,
                        calendar: calendar,
                        interval: interval,
                        accountID: accountID
                    )
                    return events
                }
            }

            for try await events in group {
                merged.append(contentsOf: events)
            }
        }

        return merged.sorted { $0.startDate < $1.startDate }
    }

    private func googleEnabledAccounts() async throws -> [ConnectedCalendarAccount] {
        try await accounts().filter(\.isEnabled)
    }

    private func currentGoogleUser() async throws -> GIDGoogleUser? {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            return try await refreshed(user: currentUser)
        }

        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            return nil
        }

        return try await restorePreviousSignIn()
    }

    private func restorePreviousSignIn() async throws -> GIDGoogleUser? {
        try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == kGIDSignInErrorDomain,
                       nsError.code == GoogleCalendarProviderError.noAuthInKeychainCode {
                        continuation.resume(returning: nil)
                        return
                    }

                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: user)
            }
        }
    }

    private func refreshed(user: GIDGoogleUser) async throws -> GIDGoogleUser {
        try await withCheckedThrowingContinuation { continuation in
            user.refreshTokensIfNeeded { refreshedUser, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let refreshedUser else {
                    continuation.resume(throwing: GoogleCalendarProviderError.missingSignedInUser)
                    return
                }

                continuation.resume(returning: refreshedUser)
            }
        }
    }

    private func validatedCalendarAccess(for user: GIDGoogleUser) throws -> GIDGoogleUser {
        let grantedScopes = Set(user.grantedScopes ?? [])
        guard grantedScopes.contains(Self.calendarReadonlyScope) else {
            throw GoogleCalendarProviderError.missingCalendarScope
        }

        return user
    }

    private func fetchCalendarList(accessToken: String) async throws -> GoogleCalendarListResponse {
        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
        let request = authorizedRequest(url: url, accessToken: accessToken)
        return try await decode(request, as: GoogleCalendarListResponse.self)
    }

    private func fetchEvents(
        accessToken: String,
        calendar: GoogleCalendarListItem,
        interval: DateInterval,
        accountID: CalendarAccountID
    ) async throws -> [ParsedEvent] {
        var components = URLComponents(
            string: "https://www.googleapis.com/calendar/v3/calendars/\(calendar.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendar.id)/events"
        )!
        components.queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: Self.dateTimeFormatter.string(from: interval.start)),
            URLQueryItem(name: "timeMax", value: Self.dateTimeFormatter.string(from: interval.end))
        ]

        let request = authorizedRequest(url: components.url!, accessToken: accessToken)
        let response = try await decode(request, as: GoogleCalendarEventsResponse.self)

        return response.items.compactMap { item in
            mapEvent(
                item,
                calendar: calendar,
                accountID: accountID
            )
        }
    }

    private func authorizedRequest(url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func decode<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw GoogleCalendarProviderError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try Self.decoder.decode(type, from: data)
    }

    private func mapEvent(
        _ item: GoogleCalendarEvent,
        calendar: GoogleCalendarListItem,
        accountID: CalendarAccountID
    ) -> ParsedEvent? {
        guard let start = Self.parse(dateInfo: item.start),
              let end = Self.parse(dateInfo: item.end) else {
            return nil
        }

        let calendarID = Self.calendarSourceID(for: calendar.id)
        let eventID = "google:\(calendar.id):\(item.id)"

        return ParsedEvent(
            id: eventID,
            calendarID: calendarID,
            sourceAccountID: accountID,
            provider: .google,
            title: item.summary ?? "Untitled Event",
            startDate: start,
            endDate: end,
            timeZoneIdentifier: item.start.timeZone ?? item.end.timeZone,
            isAllDay: item.start.date != nil,
            status: item.parsedStatus,
            availability: item.parsedAvailability,
            location: item.location,
            notes: item.description
        )
    }

    private func matchingAccount(
        for user: GIDGoogleUser,
        in accounts: [ConnectedCalendarAccount]
    ) -> ConnectedCalendarAccount? {
        let candidateIDs = googleAccountIDs(for: user)
        return accounts.first(where: { candidateIDs.contains($0.id) })
    }

    private func googleAccountIDs(for user: GIDGoogleUser) -> Set<CalendarAccountID> {
        var ids: Set<CalendarAccountID> = []

        if let email = normalizedEmail(user.profile?.email) {
            ids.insert(CalendarAccountID(rawValue: email))
        }

        if let userID = normalizedValue(user.userID) {
            ids.insert(CalendarAccountID(rawValue: userID))
        }

        return ids
    }

    private func normalizedEmail(_ value: String?) -> String? {
        normalizedValue(value)?.lowercased()
    }

    private func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func calendarSourceID(for googleCalendarID: String) -> String {
        "google:\(googleCalendarID)"
    }

    private static func parse(dateInfo: GoogleEventDateInfo) -> Date? {
        if let dateTime = dateInfo.dateTime {
            return preciseDateTimeFormatter.date(from: dateTime)
                ?? dateTimeFormatter.date(from: dateTime)
        }

        if let date = dateInfo.date {
            return dateFormatter.date(from: date)
        }

        return nil
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private static let preciseDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private enum GoogleCalendarProviderError: LocalizedError {
    static let noAuthInKeychainCode = -4

    case missingSignedInUser
    case missingCalendarScope
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingSignedInUser:
            return "Google Calendar could not find a signed-in user."
        case .missingCalendarScope:
            return "Google Calendar access expired or was never granted. Reconnect your Google account."
        case .requestFailed(let statusCode):
            return "Google Calendar request failed with status \(statusCode)."
        }
    }
}

private struct GoogleCalendarListResponse: Decodable {
    let items: [GoogleCalendarListItem]
}

private struct GoogleCalendarListItem: Decodable {
    let id: String
    let summary: String
}

private struct GoogleCalendarEventsResponse: Decodable {
    let items: [GoogleCalendarEvent]
}

private struct GoogleCalendarEvent: Decodable {
    let id: String
    let summary: String?
    let status: String?
    let location: String?
    let description: String?
    let transparency: String?
    let start: GoogleEventDateInfo
    let end: GoogleEventDateInfo

    var parsedStatus: ParsedEventStatus {
        switch status {
        case "confirmed":
            return .confirmed
        case "tentative":
            return .tentative
        case "cancelled":
            return .canceled
        default:
            return .unknown
        }
    }

    var parsedAvailability: ParsedEventAvailability {
        switch transparency {
        case "transparent":
            return .free
        case "opaque":
            return .busy
        default:
            return .busy
        }
    }
}

private struct GoogleEventDateInfo: Decodable {
    let date: String?
    let dateTime: String?
    let timeZone: String?
}

struct CompositeCalendarProvider: CalendarEventProviding {
    private let providers: [CalendarEventProviding]

    init(providers: [CalendarEventProviding]) {
        self.providers = providers
    }

    func accounts() async throws -> [ConnectedCalendarAccount] {
        var merged: [ConnectedCalendarAccount] = []

        for provider in providers {
            merged.append(contentsOf: try await provider.accounts())
        }

        return merged
    }

    func calendars() async throws -> [CalendarSource] {
        var merged: [CalendarSource] = []

        for provider in providers {
            merged.append(contentsOf: try await provider.calendars())
        }

        return merged
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        var merged: [ParsedEvent] = []

        for provider in providers {
            merged.append(contentsOf: try await provider.events(for: targetDay))
        }

        return merged
    }
}
