import Foundation

struct ScheduledAlarmRecord: Codable, Equatable, Sendable {
    let planID: EarlyOtterID
    let nativeAlarmID: String

    let scheduledWakeTime: Date
    let targetEventID: String?

    let createdAt: Date
    let updatedAt: Date
}

extension ScheduledAlarmRecord {
    func isExpired(at now: Date) -> Bool {
        scheduledWakeTime <= now
    }
}
