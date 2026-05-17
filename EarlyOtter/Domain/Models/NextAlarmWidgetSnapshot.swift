import Foundation

enum NextAlarmWidgetSnapshotState: String, Codable, Equatable, Sendable {
    case scheduled
    case empty
    case stale
}

struct NextAlarmWidgetSnapshot: Codable, Equatable, Sendable {
    let state: NextAlarmWidgetSnapshotState
    let nextAlarmDate: Date?
    let eventTitle: String?
    let context: String?
    let detailText: String?
    let lastUpdatedAt: Date

    static func scheduled(
        nextAlarmDate: Date,
        eventTitle: String? = nil,
        context: String? = nil,
        detailText: String? = nil,
        lastUpdatedAt: Date
    ) -> Self {
        Self(
            state: .scheduled,
            nextAlarmDate: nextAlarmDate,
            eventTitle: eventTitle,
            context: context,
            detailText: detailText,
            lastUpdatedAt: lastUpdatedAt
        )
    }

    static func empty(
        detailText: String? = nil,
        lastUpdatedAt: Date
    ) -> Self {
        Self(
            state: .empty,
            nextAlarmDate: nil,
            eventTitle: nil,
            context: nil,
            detailText: detailText,
            lastUpdatedAt: lastUpdatedAt
        )
    }

    static func stale(
        nextAlarmDate: Date? = nil,
        eventTitle: String? = nil,
        context: String? = nil,
        detailText: String? = nil,
        lastUpdatedAt: Date
    ) -> Self {
        Self(
            state: .stale,
            nextAlarmDate: nextAlarmDate,
            eventTitle: eventTitle,
            context: context,
            detailText: detailText,
            lastUpdatedAt: lastUpdatedAt
        )
    }
}