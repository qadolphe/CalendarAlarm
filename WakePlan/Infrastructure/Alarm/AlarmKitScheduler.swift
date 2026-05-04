#if canImport(AlarmKit)
import AlarmKit
import CryptoKit
import Foundation
import OSLog

@available(iOS 26.0, *)
private struct AlarmKitScheduleError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

@available(iOS 26.0, *)
final class AlarmKitScheduler: AlarmScheduling {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "WakePlan",
        category: "AlarmScheduling"
    )

    func authorizationState() async -> AlarmAuthorizationState {
        switch AlarmManager.shared.authorizationState {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            return .unknown
        }
    }

    func requestAuthorization() async throws -> AlarmAuthorizationState {
        let state = try await AlarmManager.shared.requestAuthorization()

        switch state {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }

    func schedule(plan: WakeUpPlan) async throws -> ScheduledAlarmRecord {
        let nativeAlarmID = deterministicAlarmID(for: plan.id.rawValue)
        let configuration = try AlarmKitMappers.configuration(from: plan)
        let debugSummary = AlarmKitMappers.debugSummary(for: plan)

        try? AlarmManager.shared.cancel(id: nativeAlarmID)
        logger.info("Scheduling alarm with payload: \(debugSummary, privacy: .public), alarmUUID=\(nativeAlarmID.uuidString, privacy: .public)")

        do {
            _ = try await AlarmManager.shared.schedule(
                id: nativeAlarmID,
                configuration: configuration
            )
        } catch {
            logger.error("Alarm scheduling failed: \(self.failureMessage(for: error, plan: plan, alarmID: nativeAlarmID), privacy: .public)")
            throw AlarmKitScheduleError(
                message: failureMessage(for: error, plan: plan, alarmID: nativeAlarmID)
            )
        }

        let now = Date()

        return ScheduledAlarmRecord(
            planID: plan.id,
            nativeAlarmID: nativeAlarmID.uuidString,
            scheduledWakeTime: plan.calculatedWakeTime,
            targetEventID: plan.targetEvent?.id,
            createdAt: now,
            updatedAt: now
        )
    }

    func cancel(nativeAlarmID: String) async throws {
        guard let alarmID = UUID(uuidString: nativeAlarmID) else { return }
        try AlarmManager.shared.cancel(id: alarmID)
    }

    private func deterministicAlarmID(for rawPlanID: String) -> UUID {
        let digest = SHA256.hash(data: Data(rawPlanID.utf8))
        let bytes = Array(digest.prefix(16))

        let uuidBytes = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )

        return UUID(uuid: uuidBytes)
    }

    private func failureMessage(
        for error: Error,
        plan: WakeUpPlan,
        alarmID: UUID
    ) -> String {
        let nsError = error as NSError
        var parts: [String] = [
            nsError.localizedDescription
        ]

        parts.append("Domain: \(nsError.domain)")
        parts.append("Code: \(nsError.code)")
        parts.append("Error: \(String(describing: error))")

        if let failureReason = nsError.localizedFailureReason, !failureReason.isEmpty {
            parts.append(failureReason)
        }

        if let recoverySuggestion = nsError.localizedRecoverySuggestion, !recoverySuggestion.isEmpty {
            parts.append(recoverySuggestion)
        }

        parts.append("Plan: \(plan.reason.rawValue)")
        parts.append("Payload: \(AlarmKitMappers.debugSummary(for: plan))")
        parts.append("Alarm ID: \(alarmID.uuidString)")

        return parts.joined(separator: " ")
    }
}
#endif
