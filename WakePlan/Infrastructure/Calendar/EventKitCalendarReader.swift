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
    private let accountStore: AccountStoring

    init(accountStore: AccountStoring) {
        self.accountStore = accountStore
    }

    func accounts() async throws -> [ConnectedCalendarAccount] {
        try accountStore.load()
            .filter { $0.provider == .google }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func calendars() async throws -> [CalendarSource] {
        []
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        _ = targetDay
        return []
    }
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
