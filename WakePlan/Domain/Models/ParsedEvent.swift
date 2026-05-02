import Foundation

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

    let title: String
    let startDate: Date
    let endDate: Date

    let timeZoneIdentifier: String?
    let isAllDay: Bool

    let status: ParsedEventStatus
    let availability: ParsedEventAvailability

    let location: String?
    let notes: String?
}
