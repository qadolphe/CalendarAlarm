import Foundation

enum TelemetryPermissionKind: String, Sendable {
    case calendar
    case alarm
    case notification
}

enum TelemetryDayOverrideKind: String, Sendable {
    case skip
    case custom
    case cleared

    init(_ override: DayAlarmOverride?) {
        switch override {
        case nil: self = .cleared
        case let override? where override.isSkipped: self = .skip
        case .some: self = .custom
        }
    }
}

/// Every usage signal EarlyOtter can send. The payloads are closed, typed values,
/// so calendar content or other free text can never be sent.
/// The server contract is in the Website repo, in `lib/telemetry.ts`.
enum TelemetryEvent: Equatable, Sendable {
    case appOpened
    case onboardingCompleted
    case permissionResolved(TelemetryPermissionKind, granted: Bool)
    case calendarAccountConnected(CalendarProvider)
    case alarmsSynced(activeAlarmCount: Int, reason: RefreshReason)
    case syncFailed(reason: RefreshReason)
    case ruleSaved(isDefault: Bool)
    case dayOverrideSet(TelemetryDayOverrideKind)
    case testAlarmScheduled
    case feedbackSubmitted(FeedbackCategory)
}

extension TelemetryEvent {
    /// Returns one event per permission the user has decided on. Permissions that are
    /// still undetermined produce no event.
    static func permissionEvents(for snapshot: PermissionSnapshot) -> [TelemetryEvent] {
        var events: [TelemetryEvent] = []

        switch snapshot.calendar {
        case .authorized: events.append(.permissionResolved(.calendar, granted: true))
        case .denied, .restricted: events.append(.permissionResolved(.calendar, granted: false))
        case .notDetermined, .unknown: break
        }

        switch snapshot.alarm {
        case .authorized: events.append(.permissionResolved(.alarm, granted: true))
        case .denied: events.append(.permissionResolved(.alarm, granted: false))
        case .notDetermined, .unknown: break
        }

        switch snapshot.notification {
        case .authorized: events.append(.permissionResolved(.notification, granted: true))
        case .denied: events.append(.permissionResolved(.notification, granted: false))
        case .notDetermined, .unknown: break
        }

        return events
    }
}
