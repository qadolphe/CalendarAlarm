import Foundation

enum EarlyOtterReason: String, Codable, Equatable, Sendable {
    case event
    /// A standard alarm the user set on the Schedule tab.
    case alarm
    case noSchedule
    case disabled
    case inactiveDay
    case authorizationMissing
    case manualOverride
    case manualSkip
    case systemDisabled
}

struct WakeUpPlan: Codable, Equatable, Identifiable, Sendable {
    let id: EarlyOtterID

    let targetDay: TargetDay
    let targetEvent: ParsedEvent?
    /// The day's events that pass the user's filters, earliest first.
    var dayEvents: [ParsedEvent]

    let calculatedWakeTime: Date
    let eventStartTime: Date?

    let prepTime: Minutes
    let commuteTime: Minutes
    let alarmSettings: RuleAlarmSettings
    /// Alarms that ring before this one: a rule's, a standard alarm's, or a day's own.
    let extraAlarms: ExtraAlarms
    /// Set on the copies `alarmSeries` makes for extra alarms; `nil` on the wake-up itself.
    let minutesEarly: Int?

    let reason: EarlyOtterReason

    /// The user's label for a standard alarm (`reason == .alarm`); may be empty.
    let alarmLabel: String?

    /// Name of the rule that produced the chosen wake time.
    var appliedRuleName: String?
    /// That rule's icon.
    var appliedRuleSymbol: RuleSymbol?

    /// Names of all rules that matched the chosen event (only populated when >1 rule matched).
    let matchedRuleNames: [String]

    init(
        id: EarlyOtterID,
        targetDay: TargetDay,
        targetEvent: ParsedEvent?,
        dayEvents: [ParsedEvent] = [],
        calculatedWakeTime: Date,
        eventStartTime: Date?,
        prepTime: Minutes,
        commuteTime: Minutes,
        alarmSettings: RuleAlarmSettings,
        extraAlarms: ExtraAlarms = .none,
        minutesEarly: Int? = nil,
        reason: EarlyOtterReason,
        alarmLabel: String? = nil,
        appliedRuleName: String?,
        appliedRuleSymbol: RuleSymbol? = nil,
        matchedRuleNames: [String]
    ) {
        self.id = id
        self.targetDay = targetDay
        self.targetEvent = targetEvent
        self.dayEvents = dayEvents.isEmpty ? [targetEvent].compactMap { $0 } : dayEvents
        self.calculatedWakeTime = calculatedWakeTime
        self.eventStartTime = eventStartTime
        self.prepTime = prepTime
        self.commuteTime = commuteTime
        self.alarmSettings = alarmSettings
        self.extraAlarms = extraAlarms
        self.minutesEarly = minutesEarly
        self.reason = reason
        self.alarmLabel = alarmLabel
        self.appliedRuleName = appliedRuleName
        self.appliedRuleSymbol = appliedRuleSymbol
        self.matchedRuleNames = matchedRuleNames
    }

    var firstEventOfDay: ParsedEvent? {
        dayEvents.first
    }
}

extension WakeUpPlan {
    /// A standard alarm's name, as the Clock app shows it: its label, or "Alarm".
    var alarmTitle: String {
        alarmLabel.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "Alarm")
    }

    /// What the wake-up is called on screen: a standard alarm's label, otherwise "Wake up".
    var wakeTitle: String {
        reason == .alarm ? alarmTitle : String(localized: "Wake up")
    }

    /// When this plan's extra alarms ring, earliest first.
    var extraAlarmTimes: [Date] {
        guard setsAlarm else { return [] }
        return extraAlarms.offsets.map { calculatedWakeTime.addingTimeInterval(-TimeInterval($0.rawValue * 60)) }
    }

    /// Every alarm this plan rings, earliest first: its extra alarms, then the
    /// wake-up itself, which keeps its ID. Each extra's ID is derived from the
    /// wake-up's, so changing the count or spacing only replaces the alarms that moved.
    var alarmSeries: [WakeUpPlan] {
        zip(extraAlarms.offsets, extraAlarmTimes).map { offset, time in
            WakeUpPlan(
                id: EarlyOtterID(rawValue: "\(id.rawValue)~early-\(offset.rawValue)"),
                targetDay: targetDay,
                targetEvent: targetEvent,
                dayEvents: dayEvents,
                calculatedWakeTime: time,
                eventStartTime: eventStartTime,
                prepTime: prepTime,
                commuteTime: commuteTime,
                alarmSettings: alarmSettings,
                minutesEarly: offset.rawValue,
                reason: reason,
                alarmLabel: alarmLabel,
                appliedRuleName: appliedRuleName,
                appliedRuleSymbol: appliedRuleSymbol,
                matchedRuleNames: matchedRuleNames
            )
        } + [self]
    }

    /// Whether this plan puts an alarm on the device.
    var setsAlarm: Bool {
        switch reason {
        case .event, .alarm, .authorizationMissing, .manualOverride:
            return true
        case .noSchedule, .disabled, .inactiveDay, .manualSkip, .systemDisabled:
            return false
        }
    }
}
