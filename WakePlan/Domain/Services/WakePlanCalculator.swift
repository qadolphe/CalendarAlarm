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

        let weekday = calendar.component(.weekday, from: targetDay.date)

        if !preferences.activeDays.contains(weekday) {
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "inactive-day",
                    components: [
                        timestamp(targetDay.date),
                        "\(weekday)",
                        "\(preferences.prepTime.rawValue)",
                        "\(preferences.defaultCommuteTime.rawValue)",
                        "\(preferences.latestWakeTime.hour)",
                        "\(preferences.latestWakeTime.minute)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                calculatedWakeTime: preferences.latestWakeTime.date(on: targetDay, calendar: calendar),
                eventStartTime: nil,
                prepTime: preferences.prepTime,
                commuteTime: preferences.defaultCommuteTime,
                isFallback: true,
                reason: .inactiveDay
            )
        }

        if !preferences.isEnabled {
            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "disabled",
                    components: [
                        timestamp(targetDay.date),
                        "\(preferences.prepTime.rawValue)",
                        "\(preferences.defaultCommuteTime.rawValue)",
                        "\(preferences.latestWakeTime.hour)",
                        "\(preferences.latestWakeTime.minute)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                calculatedWakeTime: preferences.latestWakeTime.date(on: targetDay, calendar: calendar),
                eventStartTime: nil,
                prepTime: preferences.prepTime,
                commuteTime: preferences.defaultCommuteTime,
                isFallback: true,
                reason: .disabled
            )
        }

        let validEvents = events
            .filter { eventFilter.shouldInclude($0, preferences: preferences) }
            .filter { targetDay.interval(calendar: calendar).contains($0.startDate) }
            .sorted { $0.startDate < $1.startDate }

        guard let firstEvent = validEvents.first else {
            let fallbackWakeTime = preferences.latestWakeTime.date(on: targetDay, calendar: calendar)

            return WakeUpPlan(
                id: hasher.makeID(
                    kind: "fallback",
                    components: [
                        timestamp(targetDay.date),
                        timestamp(fallbackWakeTime),
                        "\(preferences.prepTime.rawValue)",
                        "\(preferences.defaultCommuteTime.rawValue)"
                    ]
                ),
                targetDay: targetDay,
                targetEvent: nil,
                calculatedWakeTime: fallbackWakeTime,
                eventStartTime: nil,
                prepTime: preferences.prepTime,
                commuteTime: preferences.defaultCommuteTime,
                isFallback: true,
                reason: .fallback
            )
        }

        let totalOffset = preferences.prepTime.rawValue + preferences.defaultCommuteTime.rawValue
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
                    "\(preferences.prepTime.rawValue)",
                    "\(preferences.defaultCommuteTime.rawValue)"
                ]
            ),
            targetDay: targetDay,
            targetEvent: firstEvent,
            calculatedWakeTime: wakeTime,
            eventStartTime: firstEvent.startDate,
            prepTime: preferences.prepTime,
            commuteTime: preferences.defaultCommuteTime,
            isFallback: false,
            reason: .event
        )
    }

    private func timestamp(_ date: Date) -> String {
        String(format: "%.0f", date.timeIntervalSince1970)
    }
}
