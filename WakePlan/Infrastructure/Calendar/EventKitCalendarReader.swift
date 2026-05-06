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
        guard let account = storedAppleAccount() else {
            return []
        }

        return [account]
    }

    func calendars() async throws -> [CalendarSource] {
        guard appleCalendarIsEnabled() else { return [] }
        return try await calendarReader.availableCalendars()
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        guard appleCalendarIsEnabled() else { return [] }
        return try await calendarReader.events(for: targetDay)
    }

    private func appleCalendarIsEnabled() -> Bool {
        storedAppleAccount()?.isEnabled ?? false
    }

    private func storedAppleAccount() -> ConnectedCalendarAccount? {
        (try? accountStore.load())?
            .first(where: { $0.id == Self.appleAccountID && $0.provider == .apple })
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
        guard let context = try await currentGoogleContext() else { return [] }
        let user = context.user
        let account = context.account

        let calendarList = try await fetchCalendarList(accessToken: user.accessToken.tokenString)

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
        guard let context = try await currentGoogleContext() else { return [] }
        let user = context.user
        let accountID = context.account.id
        let calendarList = try await fetchCalendarList(accessToken: user.accessToken.tokenString)
        let interval = targetDay.interval(calendar: .current)

        var merged: [ParsedEvent] = []

        try await withThrowingTaskGroup(of: [ParsedEvent].self) { group in
            for calendar in calendarList.items {
                group.addTask {
                    let events = try await fetchEvents(
                        accessToken: user.accessToken.tokenString,
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

    private func currentGoogleContext() async throws -> (user: GIDGoogleUser, account: ConnectedCalendarAccount)? {
        let enabledAccounts = try await googleEnabledAccounts()
        guard !enabledAccounts.isEmpty else { return nil }

        guard let user = try await currentGoogleUser() else { return nil }
        try ensureCalendarAccess(for: user)

        guard let account = matchingAccount(for: user, in: enabledAccounts) else {
            return nil
        }

        return (user, account)
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

    private func ensureCalendarAccess(for user: GIDGoogleUser) throws {
        let grantedScopes = Set(user.grantedScopes ?? [])
        guard grantedScopes.contains(Self.calendarReadonlyScope) else {
            throw GoogleCalendarProviderError.missingCalendarScope
        }
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
            string: "https://www.googleapis.com/calendar/v3/calendars/\(safeCalendarID(for: calendar.id))/events"
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
              let end = Self.parse(dateInfo: item.end) else { return nil }

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
        let candidateIDs = GoogleAccountIdentity.matchingIDs(for: user)
        return accounts.first(where: { candidateIDs.contains($0.id) })
    }

    private static func calendarSourceID(for googleCalendarID: String) -> String {
        "google:\(googleCalendarID)"
    }

    private func safeCalendarID(for googleCalendarID: String) -> String {
        googleCalendarID.addingPercentEncoding(withAllowedCharacters: Self.googleCalendarIDAllowedCharacters)
            ?? googleCalendarID
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
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let googleCalendarIDAllowedCharacters: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/@")
        return allowed
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
        try await mergeProviderResults { provider in
            try await provider.calendars()
        }
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        try await mergeProviderResults { provider in
            try await provider.events(for: targetDay)
        }
    }

    private func mergeProviderResults<T>(
        _ loader: (CalendarEventProviding) async throws -> [T]
    ) async throws -> [T] {
        var merged: [T] = []
        var firstError: Error?
        var successfulProviderCount = 0

        for provider in providers {
            do {
                merged.append(contentsOf: try await loader(provider))
                successfulProviderCount += 1
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        if successfulProviderCount > 0 {
            return merged
        }

        if let firstError {
            throw firstError
        }

        return []
    }
}
