import Foundation

/// Whether a standard alarm stays quiet on days a calendar alarm already woke you.
enum CalendarSkipRule: Codable, Equatable, Hashable, Sendable {
    /// Always rings.
    case never
    /// Skipped when a calendar alarm rings in this window before it.
    case within(Minutes)

    static let windowOptions: [Minutes] = [60, 120, 180, 240, 360].map(Minutes.init)
    static let defaultWindow = Minutes(180)

    var window: Minutes? {
        if case .within(let window) = self { return window }
        return nil
    }
}

/// A Clock-style alarm the user sets directly: a time, optional repeat days, and
/// an optional rule that yields to calendar alarms.
struct StandardAlarm: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var time: ClockTime
    /// Weekdays it repeats on (1=Sun…7=Sat). Empty means it rings once.
    var repeatDays: Set<Int>
    var label: String
    var isEnabled: Bool
    var settings: RuleAlarmSettings
    var extraAlarms: ExtraAlarms
    var calendarSkip: CalendarSkipRule
    /// A specific date the user picked for a one-time alarm.
    var chosenDay: TargetDay?
    /// The day a one-time alarm rings, fixed when it is turned on.
    var oneTimeDay: TargetDay?

    init(
        id: UUID = UUID(),
        time: ClockTime,
        repeatDays: Set<Int> = [],
        label: String = "",
        isEnabled: Bool = true,
        settings: RuleAlarmSettings = .default,
        extraAlarms: ExtraAlarms = .none,
        calendarSkip: CalendarSkipRule = .never,
        chosenDay: TargetDay? = nil,
        oneTimeDay: TargetDay? = nil
    ) {
        self.id = id
        self.time = time
        self.repeatDays = repeatDays
        self.label = label
        self.isEnabled = isEnabled
        self.settings = settings
        self.extraAlarms = extraAlarms
        self.calendarSkip = calendarSkip
        self.chosenDay = chosenDay
        self.oneTimeDay = oneTimeDay
    }

    var isRepeating: Bool {
        !repeatDays.isEmpty
    }

    /// When this alarm rings on the given day, or `nil` if it doesn't.
    func ringDate(on targetDay: TargetDay, calendar: Calendar = .current) -> Date? {
        guard isEnabled else { return nil }

        if isRepeating {
            let weekday = calendar.component(.weekday, from: targetDay.date)
            return repeatDays.contains(weekday) ? time.date(on: targetDay, calendar: calendar) : nil
        }

        return oneTimeDay == targetDay ? time.date(on: targetDay, calendar: calendar) : nil
    }

    /// Pins a one-time alarm to its chosen date, or else to the next time its
    /// clock time comes around. A chosen date that has passed is dropped.
    func armed(now: Date = Date(), calendar: Calendar = .current) -> StandardAlarm {
        var copy = self
        guard !isRepeating else {
            copy.chosenDay = nil
            copy.oneTimeDay = nil
            return copy
        }

        if let chosenDay, time.date(on: chosenDay, calendar: calendar) > now {
            copy.oneTimeDay = chosenDay
            return copy
        }

        let today = TargetDay(date: now, calendar: calendar)
        copy.chosenDay = nil
        copy.oneTimeDay = time.date(on: today, calendar: calendar) > now
            ? today
            : TargetDay.tomorrow(from: now, calendar: calendar)
        return copy
    }

    /// True once a one-time alarm's ring time has passed, so it can turn itself off.
    func hasFired(now: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled, !isRepeating, let oneTimeDay else { return false }
        return time.date(on: oneTimeDay, calendar: calendar) <= now
    }

    /// Standby alarms from before standard alarms existed: one alarm per distinct
    /// time, repeating on the days that shared it, still yielding to calendar alarms.
    static func migratedStandby(
        days: Set<Int>,
        times: [Int: ClockTime],
        defaultTime: ClockTime,
        settings: RuleAlarmSettings
    ) -> [StandardAlarm] {
        let daysByTime = Dictionary(grouping: days) { times[$0] ?? defaultTime }

        return daysByTime
            .sorted { $0.key < $1.key }
            .map { time, days in
                StandardAlarm(
                    time: time,
                    repeatDays: Set(days),
                    settings: settings,
                    calendarSkip: .within(CalendarSkipRule.defaultWindow)
                )
            }
    }
}

extension StandardAlarm {
    private enum CodingKeys: String, CodingKey {
        case id, time, repeatDays, label, isEnabled, settings, extraAlarms, calendarSkip, chosenDay, oneTimeDay
    }

    // Alarms saved before extra alarms existed load with none.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            time: try container.decode(ClockTime.self, forKey: .time),
            repeatDays: try container.decode(Set<Int>.self, forKey: .repeatDays),
            label: try container.decode(String.self, forKey: .label),
            isEnabled: try container.decode(Bool.self, forKey: .isEnabled),
            settings: try container.decode(RuleAlarmSettings.self, forKey: .settings),
            extraAlarms: try container.decodeIfPresent(ExtraAlarms.self, forKey: .extraAlarms) ?? .none,
            calendarSkip: try container.decode(CalendarSkipRule.self, forKey: .calendarSkip),
            chosenDay: try container.decodeIfPresent(TargetDay.self, forKey: .chosenDay),
            oneTimeDay: try container.decodeIfPresent(TargetDay.self, forKey: .oneTimeDay)
        )
    }
}
