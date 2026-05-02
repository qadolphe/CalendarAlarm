import Foundation

struct ScheduledAlarmRecord: Codable, Equatable, Sendable {
    let planID: WakePlanID
    let nativeAlarmID: String

    let scheduledWakeTime: Date
    let targetEventID: String?

    let createdAt: Date
    let updatedAt: Date
}
