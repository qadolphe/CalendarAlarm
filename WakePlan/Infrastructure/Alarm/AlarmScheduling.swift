import Foundation

enum AlarmAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case unknown
}

protocol AlarmScheduling {
    func authorizationState() async -> AlarmAuthorizationState
    func requestAuthorization() async throws -> AlarmAuthorizationState

    func schedule(plan: WakeUpPlan) async throws -> ScheduledAlarmRecord
    func cancel(nativeAlarmID: String) async throws
}
