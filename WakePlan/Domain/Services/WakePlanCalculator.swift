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

        if !scheduleRules.activeDays.contains(weekday) {
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "inactive-day",
                    components: [
                        timestamp(targetDay.date),
                        "\(weekday)",
                        "\(timingRules.prepTime.rawValue)",
                        "\(timingRules.defaultCommuteTime.rawValue)",
                        "\(timingRules.latestWakeTime.hour)",
                        "\(timingRules.latestWakeTime.minute)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                calculatedWakeTime: timingRules.latestWakeTime.date(on: targetDay, calendar: calendar),
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                isFallback: true,
                reason: .inactiveDay
            )
        }

        if !scheduleRules.isEnabled {
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "disabled",
                    components: [
                        timestamp(targetDay.date),
                        "\(timingRules.prepTime.rawValue)",
                        "\(timingRules.defaultCommuteTime.rawValue)",
                        "\(timingRules.latestWakeTime.hour)",
                        "\(timingRules.latestWakeTime.minute)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                calculatedWakeTime: timingRules.latestWakeTime.date(on: targetDay, calendar: calendar),
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                isFallback: true,
                reason: .disabled
            )
        }

        let validEvents = events
            .filter { eventFilter.shouldInclude($0, preferences: preferences) }
            .filter { targetDay.interval(calendar: calendar).contains($0.startDate) }
            .sorted { $0.startDate < $1.startDate }

        guard let firstEvent = validEvents.first else {
            let fallbackWakeTime = timingRules.latestWakeTime.date(on: targetDay, calendar: calendar)

            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "fallback",
                    components: [
                        timestamp(targetDay.date),
                        timestamp(fallbackWakeTime),
                        "\(timingRules.prepTime.rawValue)",
                        "\(timingRules.defaultCommuteTime.rawValue)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                calculatedWakeTime: fallbackWakeTime,
                eventStartTime: nil,
                prepTime: timingRules.prepTime,
                commuteTime: timingRules.defaultCommuteTime,
                isFallback: true,
                reason: .fallback
            )
        }

        // Find the first custom rule that matches this event; fall back to the default rule.
        let matchingRule = preferences.customAlarmRules.first { $0.matches(event: firstEvent) }
            ?? preferences.defaultAlarmRule
        let effectivePrepTime = matchingRule.prepTime
        let effectiveCommuteTime = matchingRule.commuteTime

        let totalOffset = effectivePrepTime.rawValue + effectiveCommuteTime.rawValue
        let wakeTime = calendar.date(
            byAdding: .minute,
            value: -totalOffset,
            to: firstEvent.startDate
        ) ?? firstEvent.startDate

        return WakeUpPlan(
            id: hasher.makeID(
                kind: "event",
                components: [
                    firstEvent.id,
                    timestamp(targetDay.date),
                    timestamp(firstEvent.startDate),
                    timestamp(wakeTime),
                    "\(effectivePrepTime.rawValue)",
                    "\(effectiveCommuteTime.rawValue)"
                ]
            ),
            targetDay: targetDay,
            targetEvent: firstEvent,
            calculatedWakeTime: wakeTime,
            eventStartTime: firstEvent.startDate,
            prepTime: effectivePrepTime,
            commuteTime: effectiveCommuteTime,
            isFallback: false,
            reason: .event
        )
    }

    private func timestamp(_ date: Date) -> String {
        String(format: "%.0f", date.timeIntervalSince1970)
    }
}
