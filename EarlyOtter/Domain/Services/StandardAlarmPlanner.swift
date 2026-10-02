import Foundation

/// Turns standard alarms into dated plans, dropping occurrences that yield to a
/// calendar alarm or fall on a day the user edited from the week view.
struct StandardAlarmPlanner {
    private let hasher: EarlyOtterHasher

    init(hasher: EarlyOtterHasher = EarlyOtterHasher()) {
        self.hasher = hasher
    }

    func plans(
        for targetDays: [TargetDay],
        calendarPlans: [WakeUpPlan],
        preferences: AlarmPreferences,
        calendar: Calendar = .current
    ) -> [WakeUpPlan] {
        guard preferences.isSystemEnabled else { return [] }

        let calendarAlarmTimes = calendarPlans
            .filter { $0.reason == .event }
            .map(\.calculatedWakeTime)

        return targetDays.flatMap { targetDay -> [WakeUpPlan] in
            // A day edited from the week view (skipped or given a custom time)
            // replaces every alarm on that date.
            guard preferences.override(for: targetDay, calendar: calendar) == nil else { return [] }

            return preferences.standardAlarms.compactMap { alarm in
                guard let ringDate = alarm.ringDate(on: targetDay, calendar: calendar),
                      !yields(ringDate, to: calendarAlarmTimes, rule: alarm.calendarSkip) else {
                    return nil
                }

                return makePlan(for: alarm, ringDate: ringDate, targetDay: targetDay)
            }
        }
        .sorted { $0.calculatedWakeTime < $1.calculatedWakeTime }
    }

    /// The plan each day shows on the week view: its earliest alarm of either kind.
    func earliestPerDay(calendarPlans: [WakeUpPlan], alarmPlans: [WakeUpPlan]) -> [WakeUpPlan] {
        let alarmPlansByDay = Dictionary(grouping: alarmPlans, by: \.targetDay)

        return calendarPlans.map { calendarPlan in
            guard let earliestAlarm = alarmPlansByDay[calendarPlan.targetDay]?
                .min(by: { $0.calculatedWakeTime < $1.calculatedWakeTime }) else {
                return calendarPlan
            }

            if calendarPlan.setsAlarm, calendarPlan.calculatedWakeTime <= earliestAlarm.calculatedWakeTime {
                return calendarPlan
            }
            // Keep the day's events so the week view and planner can still show them.
            var dayPlan = earliestAlarm
            dayPlan.dayEvents = calendarPlan.dayEvents
            return dayPlan
        }
    }

    /// Whether a calendar alarm rings inside the alarm's skip window.
    func yields(_ ringDate: Date, to calendarAlarmTimes: [Date], rule: CalendarSkipRule) -> Bool {
        guard let window = rule.window else { return false }

        let windowStart = ringDate.addingTimeInterval(-TimeInterval(window.rawValue * 60))
        return calendarAlarmTimes.contains { $0 >= windowStart && $0 < ringDate }
    }

    private func makePlan(for alarm: StandardAlarm, ringDate: Date, targetDay: TargetDay) -> WakeUpPlan {
        WakeUpPlan(
            // Everything AlarmKit is configured with is hashed in, so an edit reschedules it.
            id: hasher.makeID(
                kind: "alarm",
                components: [
                    alarm.id.uuidString,
                    String(format: "%.0f", ringDate.timeIntervalSince1970),
                    alarm.label,
                    alarm.settings.sound.rawValue,
                    "\(alarm.settings.snoozeEnabled)",
                    "\(alarm.settings.snoozeDuration.rawValue)"
                ]
            ),
            targetDay: targetDay,
            targetEvent: nil,
            calculatedWakeTime: ringDate,
            eventStartTime: nil,
            prepTime: Minutes(0),
            commuteTime: Minutes(0),
            alarmSettings: alarm.settings,
            extraAlarms: alarm.extraAlarms,
            reason: .alarm,
            alarmLabel: alarm.label,
            appliedRuleName: nil,
            matchedRuleNames: []
        )
    }
}

