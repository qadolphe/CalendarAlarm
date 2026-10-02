import Foundation

struct EarlyOtterCalculator {
    private let eventFilter: EventFilter
    private let hasher: EarlyOtterHasher

    init(
        eventFilter: EventFilter = EventFilter(),
        hasher: EarlyOtterHasher = EarlyOtterHasher()
    ) {
        self.eventFilter = eventFilter
        self.hasher = hasher
    }

    func calculate(
        events: [ParsedEvent],
        preferences: AlarmPreferences,
        targetDay: TargetDay,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WakeUpPlan {
        _ = now

        let scheduleRules = preferences.schedule
        let timingRules = preferences.timing
        let weekday = calendar.component(.weekday, from: targetDay.date)
        // Days without a calendar alarm still carry a nominal time and settings.
        let placeholderTime = timingRules.latestWakeTime
        let placeholderWakeTime = placeholderTime.date(on: targetDay, calendar: calendar)
        let defaultAlarmSettings = preferences.defaultAlarmSettings

        // The day's events are computed once up front and threaded into every plan —
        // including disabled, inactive, and skipped days where no alarm runs but the
        // events are still there for the week markers and the day planner.
        let dayEvents = events
            .filter { eventFilter.shouldInclude($0, preferences: preferences) }
            .filter { targetDay.interval(calendar: calendar).contains($0.startDate) }
            .sorted { $0.startDate < $1.startDate }

        if !preferences.isSystemEnabled {
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "systemDisabled",
                    components: [
                        timestamp(targetDay.date),
                        "\(placeholderTime.hour)",
                        "\(placeholderTime.minute)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                dayEvents: dayEvents,
                calculatedWakeTime: placeholderWakeTime,
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                alarmSettings: defaultAlarmSettings,
                reason: .systemDisabled,
                appliedRuleName: nil,
                matchedRuleNames: []
            )
        }

        let override = preferences.override(for: targetDay, calendar: calendar)

        // A fixed custom time replaces the automatic computation for this date
        // (it can even force an alarm on an otherwise-off day), still respecting
        // the master system switch handled above.
        if let override, let customTime = override.customWakeTime {
            return makeManualTimePlan(
                targetDay: targetDay,
                customTime: customTime,
                isSkipped: override.isSkipped,
                extraAlarms: override.extraAlarms ?? .none,
                dayEvents: dayEvents,
                timingRules: timingRules,
                defaultAlarmSettings: defaultAlarmSettings,
                calendar: calendar
            )
        }

        // Otherwise the day follows its normal automatic schedule...
        let basePlan = automaticPlan(
            events: events,
            preferences: preferences,
            targetDay: targetDay,
            scheduleRules: scheduleRules,
            timingRules: timingRules,
            weekday: weekday,
            placeholderTime: placeholderTime,
            placeholderWakeTime: placeholderWakeTime,
            defaultAlarmSettings: defaultAlarmSettings,
            dayEvents: dayEvents,
            dayExtraAlarms: override?.extraAlarms,
            calendar: calendar
        )

        // ...optionally skipped for this one day, while keeping the underlying
        // automatic time/prep/commute so re-enabling restores it exactly.
        if let override, override.isSkipped {
            return makeSkippedPlan(base: basePlan, targetDay: targetDay)
        }

        return basePlan
    }

    /// The normal event-driven plan for a day, with no per-date override applied.
    private func automaticPlan(
        events: [ParsedEvent],
        preferences: AlarmPreferences,
        targetDay: TargetDay,
        scheduleRules: ScheduleRules,
        timingRules: TimingRules,
        weekday: Int,
        placeholderTime: ClockTime,
        placeholderWakeTime: Date,
        defaultAlarmSettings: RuleAlarmSettings,
        dayEvents: [ParsedEvent],
        dayExtraAlarms: ExtraAlarms?,
        calendar: Calendar
    ) -> WakeUpPlan {
        if !scheduleRules.activeDays.contains(weekday) {
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "inactive-day",
                    components: [
                        timestamp(targetDay.date),
                        "\(weekday)",
                        "\(placeholderTime.hour)",
                        "\(placeholderTime.minute)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                dayEvents: dayEvents,
                calculatedWakeTime: placeholderWakeTime,
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                alarmSettings: defaultAlarmSettings,
                reason: .inactiveDay,
                appliedRuleName: nil,
                matchedRuleNames: []
            )
        }

        if !scheduleRules.isEnabled {
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "disabled",
                    components: [
                        timestamp(targetDay.date),
                        "\(placeholderTime.hour)",
                        "\(placeholderTime.minute)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                dayEvents: dayEvents,
                calculatedWakeTime: placeholderWakeTime,
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                alarmSettings: defaultAlarmSettings,
                reason: .disabled,
                appliedRuleName: nil,
                matchedRuleNames: []
            )
        }
        let validEvents = events
            .filter { eventFilter.shouldInclude($0, preferences: preferences) }
            .filter { targetDay.interval(calendar: calendar).contains($0.startDate) }

        // Build every candidate: (event, matchingRule, calculatedWakeTime)
        // A rule matches an event if AlarmRule.matches returns true.
        // The default rule is the fallback when no custom rule matches.
        struct Candidate {
            let event: ParsedEvent
            let rule: AlarmRule
            let wakeTime: Date
        }

        var candidates: [Candidate] = []
        let activeCalendarIDs = Set(events.map(\.calendarID))

        for event in validEvents {
            // Collect every custom rule that matches this event
            var matchingRules: [AlarmRule] = preferences.customAlarmRules.filter {
                $0.matches(event: event, activeCalendarIDs: activeCalendarIDs, calendar: calendar)
            }

            // If no custom rule matches, try the default rule
            if matchingRules.isEmpty {
                let defaultRule = preferences.defaultAlarmRule
                if defaultRule.matches(event: event, activeCalendarIDs: activeCalendarIDs, calendar: calendar) {
                    matchingRules.append(defaultRule)
                }
            }
            
            // If no rule matches at all (e.g. calendar restriction on all rules), skip event
            guard !matchingRules.isEmpty else { continue }

            for rule in matchingRules {
                let offset = rule.prepTime.rawValue + rule.commuteTime.rawValue
                let wakeTime = calendar.date(
                    byAdding: .minute,
                    value: -offset,
                    to: event.startDate
                ) ?? event.startDate
                candidates.append(Candidate(event: event, rule: rule, wakeTime: wakeTime))
            }
        }

        guard let winner = candidates.min(by: { $0.wakeTime < $1.wakeTime }) else {
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "no-schedule",
                    components: [
                        timestamp(targetDay.date),
                        "\(weekday)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                dayEvents: dayEvents,
                calculatedWakeTime: placeholderWakeTime,
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                alarmSettings: defaultAlarmSettings,
                reason: .noSchedule,
                appliedRuleName: nil,
                matchedRuleNames: []
            )
        }

        // Collect all rule names that matched the winning event (for UI transparency)
        let winningEvent = winner.event
        let winnerWakeTime = winner.wakeTime
        let winningRule = winner.rule
        let allMatchedRulesForWinningEvent = candidates
            .filter { $0.event.id == winningEvent.id }
            .map { $0.rule.name }

        // Only surface multi-match when more than one distinct rule matched the chosen event
        let matchedRuleNames: [String] = allMatchedRulesForWinningEvent.count > 1
            ? Array(LinkedDedupe(allMatchedRulesForWinningEvent))
            : []

        return WakeUpPlan(
            id: hasher.makeID(
                kind: "event",
                components: [
                    winningEvent.id,
                    timestamp(targetDay.date),
                    timestamp(winningEvent.startDate),
                    timestamp(winnerWakeTime),
                    "\(winningRule.prepTime.rawValue)",
                    "\(winningRule.commuteTime.rawValue)"
                ] + alarmSettingsComponents(winningRule.alarmSettings)
            ),
            targetDay: targetDay,
            targetEvent: winningEvent,
            dayEvents: dayEvents,
            calculatedWakeTime: winnerWakeTime,
            eventStartTime: winningEvent.startDate,
            prepTime: winningRule.prepTime,
            commuteTime: winningRule.commuteTime,
            alarmSettings: winningRule.alarmSettings,
            // A day's own extra alarms, set from the week view, win over the rule's.
            extraAlarms: dayExtraAlarms ?? winningRule.extraAlarms,
            reason: .event,
            appliedRuleName: winningRule.displayName,
            appliedRuleSymbol: winningRule.symbol,
            matchedRuleNames: matchedRuleNames
        )
    }

    /// A fixed-time manual override (optionally skipped) for a single date.
    private func makeManualTimePlan(
        targetDay: TargetDay,
        customTime: ClockTime,
        isSkipped: Bool,
        extraAlarms: ExtraAlarms,
        dayEvents: [ParsedEvent],
        timingRules: TimingRules,
        defaultAlarmSettings: RuleAlarmSettings,
        calendar: Calendar
    ) -> WakeUpPlan {
        let wakeTime = customTime.date(on: targetDay, calendar: calendar)

        return WakeUpPlan(
            id: hasher.makeID(
                kind: isSkipped ? "manual-skip" : "manual-override",
                components: [
                    timestamp(targetDay.date),
                    "\(customTime.hour)",
                    "\(customTime.minute)"
                ] + alarmSettingsComponents(defaultAlarmSettings)
            ),
            targetDay: targetDay,
            targetEvent: nil,
            dayEvents: dayEvents,
            calculatedWakeTime: wakeTime,
            eventStartTime: nil,
            prepTime: timingRules.prepTime,
            commuteTime: timingRules.defaultCommuteTime,
            alarmSettings: defaultAlarmSettings,
            extraAlarms: extraAlarms,
            reason: isSkipped ? .manualSkip : .manualOverride,
            appliedRuleName: nil,
            matchedRuleNames: []
        )
    }

    /// Marks an automatically-computed plan as skipped for one day, preserving its
    /// time/prep/commute so re-enabling restores the exact automatic alarm.
    private func makeSkippedPlan(base: WakeUpPlan, targetDay: TargetDay) -> WakeUpPlan {
        WakeUpPlan(
            id: hasher.makeID(
                kind: "manual-skip-auto",
                components: [timestamp(targetDay.date)]
            ),
            targetDay: targetDay,
            targetEvent: nil,
            dayEvents: base.dayEvents,
            calculatedWakeTime: base.calculatedWakeTime,
            eventStartTime: nil,
            prepTime: base.prepTime,
            commuteTime: base.commuteTime,
            alarmSettings: base.alarmSettings,
            reason: .manualSkip,
            appliedRuleName: nil,
            matchedRuleNames: []
        )
    }

    /// Hashed into the ID of every plan that rings, so a sound or snooze edit
    /// replaces alarms already scheduled with the old settings.
    private func alarmSettingsComponents(_ settings: RuleAlarmSettings) -> [String] {
        [settings.sound.rawValue, "\(settings.snoozeEnabled)", "\(settings.snoozeDuration.rawValue)"]
    }

    private func timestamp(_ date: Date) -> String {
        String(format: "%.0f", date.timeIntervalSince1970)
    }

}

// Simple order-preserving deduplication without requiring Hashable protocol extras
private struct LinkedDedupe<T: Equatable>: Sequence {
    private let items: [T]
    init(_ items: [T]) { self.items = items }
    func makeIterator() -> IndexingIterator<[T]> {
        var seen: [T] = []
        for item in items where !seen.contains(item) { seen.append(item) }
        return seen.makeIterator()
    }
}
