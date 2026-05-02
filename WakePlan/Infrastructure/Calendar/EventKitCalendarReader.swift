import EventKit
import Foundation

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

    func calendars() async throws -> [CalendarSource] {
        eventStore.calendars(for: .event).map {
            CalendarSource(
                id: $0.calendarIdentifier,
                title: $0.title,
                isSelected: true
            )
        }
    }

    func events(
        for targetDay: TargetDay,
        selectedCalendarIDs: Set<String>
    ) async throws -> [ParsedEvent] {
        let calendars = eventStore.calendars(for: .event).filter { calendar in
            selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains(calendar.calendarIdentifier)
        }

        let predicate = eventStore.predicateForEvents(
            withStart: targetDay.interval.start,
            end: targetDay.interval.end,
            calendars: calendars
        )

        return eventStore.events(matching: predicate).map(EventKitMappers.map)
    }
}
