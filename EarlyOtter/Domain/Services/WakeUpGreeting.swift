import Foundation

/// The time-of-day window an alarm fires in. Drives which wake-up message is shown.
///
/// Boundaries use an inclusive upper bound:
/// - ``predawn``: 00:00–05:00
/// - ``earlyMorning``: 05:01–08:00
/// - ``midMorning``: 08:01–10:00
/// - ``lateMorning``: 10:01–23:59
enum WakeWindow: CaseIterable, Equatable, Sendable {
    case predawn
    case earlyMorning
    case midMorning
    case lateMorning

    init(hour: Int, minute: Int) {
        let minutesSinceMidnight = hour * 60 + minute

        switch minutesSinceMidnight {
        case ...(5 * 60):
            self = .predawn
        case ...(8 * 60):
            self = .earlyMorning
        case ...(10 * 60):
            self = .midMorning
        default:
            self = .lateMorning
        }
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
}

/// A non-empty set of interchangeable wake-up lines for a single ``WakeWindow``.
///
/// The variadic initializer makes "zero messages" unrepresentable: every
/// `WakeUpMessages` value is guaranteed to hold at least one line.
struct WakeUpMessages: Sendable {
    let lines: [String]

    init(_ first: String, _ rest: String...) {
        lines = [first] + rest
    }

    /// Deterministically picks a line from `seed`. The same seed always returns
    /// the same line — so a given alarm shows a stable message — while different
    /// seeds rotate through the set.
    func line(seed: Int) -> String {
        let count = lines.count
        let index = ((seed % count) + count) % count
        return lines[index]
    }
}

/// The full body of wake-up copy: one ``WakeUpMessages`` group per ``WakeWindow``.
///
/// A stored property per window means the compiler forces every window to be
/// supplied, so a catalog can never be missing a window's messages. The actual
/// copy lives in `WakeUpMessageCatalog+Default.swift`.
struct WakeUpMessageCatalog: Sendable {
    let predawn: WakeUpMessages
    let earlyMorning: WakeUpMessages
    let midMorning: WakeUpMessages
    let lateMorning: WakeUpMessages

    func messages(for window: WakeWindow) -> WakeUpMessages {
        switch window {
        case .predawn:
            return predawn
        case .earlyMorning:
            return earlyMorning
        case .midMorning:
            return midMorning
        case .lateMorning:
            return lateMorning
        }
    }
}

/// Builds an alarm's alert title from the time it fires and the optional
/// calendar event it wakes the user for.
struct WakeUpGreetingProvider: Sendable {
    let catalog: WakeUpMessageCatalog
    let calendar: Calendar

    init(catalog: WakeUpMessageCatalog = .default, calendar: Calendar = .current) {
        self.catalog = catalog
        self.calendar = calendar
    }

    /// - Parameters:
    ///   - eventTitle: The calendar event the alarm is tied to, if any. Appended
    ///     as a suffix when present and non-blank.
    ///   - wakeTime: When the alarm fires. Selects both the window and — seeded by
    ///     the day — which line within that window is shown.
    func title(eventTitle: String?, wakeTime: Date) -> String {
        let window = WakeWindow(date: wakeTime, calendar: calendar)
        let seed = calendar.ordinality(of: .day, in: .era, for: wakeTime) ?? 0
        let greeting = catalog.messages(for: window).line(seed: seed)

        guard let event = eventTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !event.isEmpty else {
            return greeting
        }

        return "\(greeting) — \(event)"
    }
}
