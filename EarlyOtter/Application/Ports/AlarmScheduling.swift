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
    /// IDs of alarms the system still has pending, including any the record store lost track of.
    func pendingNativeAlarmIDs() async throws -> [String]

    /// Ends any Live Activities owned by AlarmKit that are not associated with
    /// the supplied set of currently-scheduled native alarm IDs. This is used
    /// to clean up orphaned (or zombie) Live Activities that would otherwise
    /// leave a persistent indicator in the Dynamic Island.
    func endOrphanedLiveActivities(keepingNativeAlarmIDs: Set<String>) async
}

extension AlarmScheduling {
    func pendingNativeAlarmIDs() async throws -> [String] { [] }
    func endOrphanedLiveActivities(keepingNativeAlarmIDs: Set<String>) async {}
}
