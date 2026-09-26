import Foundation

enum TelemetryPropValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }
}

/// The JSON shape `/api/telemetry` accepts for a single event.
struct TelemetryWireEvent: Codable, Equatable, Sendable {
    let name: String
    /// The user's local calendar day, which the server uses to measure retention.
    let day: String
    let occurredAt: String
    let props: [String: TelemetryPropValue]

    init(_ event: TelemetryEvent, at date: Date, timeZone: TimeZone = .current) {
        let (name, props) = Self.nameAndProps(for: event)
        self.name = name
        self.props = props
        self.day = Self.dayString(for: date, timeZone: timeZone)
        self.occurredAt = ISO8601DateFormatter().string(from: date)
    }

    private static func dayString(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func nameAndProps(for event: TelemetryEvent) -> (String, [String: TelemetryPropValue]) {
        switch event {
        case .appOpened:
            return ("app_opened", [:])
        case .onboardingCompleted:
            return ("onboarding_completed", [:])
        case let .permissionResolved(kind, granted):
            return ("permission_resolved", ["kind": .string(kind.rawValue), "granted": .bool(granted)])
        case .calendarAccountConnected(let provider):
            return ("calendar_account_connected", ["provider": .string(provider.rawValue)])
        case let .alarmsSynced(activeAlarmCount, reason):
            return (
                "alarms_synced",
                ["activeAlarmCount": .int(min(max(activeAlarmCount, 0), 100)), "reason": .string(reason.rawValue)]
            )
        case .syncFailed(let reason):
            return ("sync_failed", ["reason": .string(reason.rawValue)])
        case .ruleSaved(let isDefault):
            return ("rule_saved", ["isDefault": .bool(isDefault)])
        case .dayOverrideSet(let kind):
            return ("day_override_set", ["kind": .string(kind.rawValue)])
        case .testAlarmScheduled:
            return ("test_alarm_scheduled", [:])
        case .feedbackSubmitted(let category):
            return ("feedback_submitted", ["category": .string(category.rawValue)])
        }
    }
}

struct TelemetryBatchPayload: Encodable {
    let schemaVersion = 1
    let installId: String
    let appVersion: String
    let buildNumber: String
    let iosVersion: String
    let channel: String
    let events: [TelemetryWireEvent]
}
