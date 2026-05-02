import EventKit
import Foundation

enum EventKitMappers {
    static func map(_ event: EKEvent) -> ParsedEvent {
        ParsedEvent(
            id: event.eventIdentifier ?? UUID().uuidString,
            calendarID: event.calendar.calendarIdentifier,
            title: event.title ?? "Untitled Event",
            startDate: event.startDate,
            endDate: event.endDate,
            timeZoneIdentifier: event.timeZone?.identifier,
            isAllDay: event.isAllDay,
            status: mapStatus(event.status),
            availability: mapAvailability(event.availability),
            location: event.location,
            notes: event.notes
        )
    }

    private static func mapStatus(_ status: EKEventStatus) -> ParsedEventStatus {
        switch status {
        case .confirmed:
            return .confirmed
        case .tentative:
            return .tentative
        case .canceled:
            return .canceled
        case .none:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    private static func mapAvailability(_ availability: EKEventAvailability) -> ParsedEventAvailability {
        switch availability {
        case .busy:
            return .busy
        case .free:
            return .free
        case .tentative:
            return .tentative
        case .unavailable:
            return .unavailable
        case .notSupported:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}
