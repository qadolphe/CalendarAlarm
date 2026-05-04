import Foundation

struct ScheduledAlarmRecord: Codable, Equatable, Sendable {
    let planID: WakePlanID
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

    var debugSummary: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return [
            "planID=\(planID.rawValue)",
            "nativeAlarmID=\(nativeAlarmID)",
            "scheduledWakeTime=\(formatter.string(from: scheduledWakeTime))",
            "targetEventID=\(targetEventID ?? "nil")"
        ].joined(separator: ", ")
    }
}
