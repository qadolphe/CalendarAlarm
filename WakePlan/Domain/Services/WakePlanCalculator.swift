import Foundation

struct WakePlanCalculator {
    private let eventFilter: EventFilter
    private let hasher: WakePlanHasher

    init(
        eventFilter: EventFilter = EventFilter(),
        hasher: WakePlanHasher = WakePlanHasher()
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

        if !preferences.isSystemEnabled {
            let dayFallback = preferences.fallbackWakeTime(for: weekday)
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "systemDisabled",
                    components: [
                        timestamp(targetDay.date),
                        "\(dayFallback.hour)",
                        "\(dayFallback.minute)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                calculatedWakeTime: dayFallback.date(on: targetDay, calendar: calendar),
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                isFallback: true,
                reason: .systemDisabled,
                appliedRuleName: nil,
                matchedRuleNames: []
            )
        }

        if !scheduleRules.activeDays.contains(weekday) {
            let dayFallback = preferences.fallbackWakeTime(for: weekday)
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "inactive-day",
                    components: [
                        timestamp(targetDay.date),
                        "\(weekday)",
                        "\(dayFallback.hour)",
                        "\(dayFallback.minute)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                calculatedWakeTime: dayFallback.date(on: targetDay, calendar: calendar),
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                isFallback: true,
                reason: .inactiveDay,
                appliedRuleName: nil,
                matchedRuleNames: []
            )
        }

        if !scheduleRules.isEnabled {
            let dayFallback = preferences.fallbackWakeTime(for: weekday)
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "disabled",
                    components: [
                        timestamp(targetDay.date),
                        "\(dayFallback.hour)",
                        "\(dayFallback.minute)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                calculatedWakeTime: dayFallback.date(on: targetDay, calendar: calendar),
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                isFallback: true,
                reason: .disabled,
                appliedRuleName: nil,
                matchedRuleNames: []
            )
        }
        let validEvents = events
            .filter { eventFilter.shouldInclude($0, preferences: preferences) }
            .filter { targetDay.interval(calendar: calendar).contains($0.startDate) }

        let allRules = preferences.alarmRules

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
            // Collect every rule that matches this event
            let matchingRules: [AlarmRule] = allRules.filter { $0.matches(event: event, activeCalendarIDs: activeCalendarIDs) }
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

        // Choose the candidate with the earliest wake time (not earliest event start)
        guard let winner = candidates.min(by: { $0.wakeTime < $1.wakeTime }) else {
            guard scheduleRules.fallbackEnabledDays.contains(weekday) else {
                let dayFallback = preferences.fallbackWakeTime(for: weekday)
                return WakeUpPlan(
                    id: hasher.makeID(
                        kind: "disabled-fallback-day",
                        components: [
                            timestamp(targetDay.date),
                            "\(weekday)",
                            "\(dayFallback.hour)",
                            "\(dayFallback.minute)"
                        ]
                    ),
                    targetDay: targetDay,
                    targetEvent: nil,
                    calculatedWakeTime: dayFallback.date(on: targetDay, calendar: calendar),
                    eventStartTime: nil,
                    prepTime: timingRules.prepTime,
                    commuteTime: timingRules.defaultCommuteTime,
                    isFallback: false,
                    reason: .disabled,
                    appliedRuleName: nil,
                    matchedRuleNames: []
                )
            }

            let dayFallback = preferences.fallbackWakeTime(for: weekday)
            let fallbackWakeTime = dayFallback.date(on: targetDay, calendar: calendar)

            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "fallback",
                    components: [
                        timestamp(targetDay.date),
                        timestamp(fallbackWakeTime)
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                calculatedWakeTime: fallbackWakeTime,
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                isFallback: true,
                reason: .fallback,
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
                ]
            ),
            targetDay: targetDay,
            targetEvent: winningEvent,
            calculatedWakeTime: winnerWakeTime,
            eventStartTime: winningEvent.startDate,
            prepTime: winningRule.prepTime,
            commuteTime: winningRule.commuteTime,
            isFallback: false,
            reason: .event,
            appliedRuleName: winningRule.name,
            matchedRuleNames: matchedRuleNames
        )
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
