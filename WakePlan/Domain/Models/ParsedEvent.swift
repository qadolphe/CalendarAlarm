import Foundation

enum CalendarProvider: String, Codable, Equatable, Sendable {
    case apple
    case google
}

struct CalendarAccountID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

struct ConnectedCalendarAccount: Identifiable, Codable, Equatable, Sendable {
    let id: CalendarAccountID
    let provider: CalendarProvider
    let displayName: String
    var isEnabled: Bool
}

enum ParsedEventStatus: String, Codable, Equatable, Sendable {
    case confirmed
    case tentative
    case canceled
    case unknown
}

enum ParsedEventAvailability: String, Codable, Equatable, Sendable {
    case busy
    case free
    case tentative
    case unavailable
    case unknown
}

struct ParsedEvent: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let calendarID: String
    let sourceAccountID: CalendarAccountID?
    let provider: CalendarProvider

    let title: String
    let startDate: Date
    let endDate: Date

    let timeZoneIdentifier: String?
    let isAllDay: Bool

    let status: ParsedEventStatus
    let availability: ParsedEventAvailability

    let location: String?
    let notes: String?

    init(
        id: String,
        calendarID: String,
        sourceAccountID: CalendarAccountID? = nil,
        provider: CalendarProvider = .apple,
        title: String,
        startDate: Date,
        endDate: Date,
        timeZoneIdentifier: String?,
        isAllDay: Bool,
        status: ParsedEventStatus,
        availability: ParsedEventAvailability,
        location: String?,
        notes: String?
    ) {
        self.id = id
        self.calendarID = calendarID
        self.sourceAccountID = sourceAccountID
        self.provider = provider
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isAllDay = isAllDay
        self.status = status
        self.availability = availability
        self.location = location
        self.notes = notes
    }
}
