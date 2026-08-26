import Foundation

struct NextAlarmWidgetDisplayPolicy {
    static let lockScreenUpcomingHorizon: TimeInterval = 24 * 60 * 60
    static let emptySymbolName = "moon.zzz.fill"
    static let defaultTimelineRefreshInterval: TimeInterval = 30 * 60

    static func hasLockScreenUpcomingAlarm(
        _ snapshot: NextAlarmWidgetSnapshot,
        now: Date
    ) -> Bool {
        guard snapshot.state != .empty, let nextAlarmDate = snapshot.nextAlarmDate else {
            return false
        }

        let remaining = nextAlarmDate.timeIntervalSince(now)
        return remaining > 0 && remaining <= lockScreenUpcomingHorizon
    }

    static func nextTimelineDate(
        for snapshot: NextAlarmWidgetSnapshot,
        from now: Date
    ) -> Date {
        let defaultRefreshDate = now.addingTimeInterval(defaultTimelineRefreshInterval)
        guard let nextAlarmDate = snapshot.nextAlarmDate, nextAlarmDate > now else {
            return defaultRefreshDate
        }

        let horizonStart = nextAlarmDate.addingTimeInterval(-lockScreenUpcomingHorizon)
        if horizonStart > now {
            return min(defaultRefreshDate, horizonStart)
        }

        return min(defaultRefreshDate, nextAlarmDate.addingTimeInterval(60))
    }
}
