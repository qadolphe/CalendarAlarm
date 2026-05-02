import Foundation

struct PermissionSnapshot: Equatable, Sendable {
    var calendar: CalendarAuthorizationState
    var alarm: AlarmAuthorizationState

    static let initial = PermissionSnapshot(
        calendar: .notDetermined,
        alarm: .notDetermined
    )
}

final class PermissionService {
    private let calendarReader: CalendarReading
    private let alarmScheduler: AlarmScheduling

    init(
        calendarReader: CalendarReading,
        alarmScheduler: AlarmScheduling
    ) {
        self.calendarReader = calendarReader
        self.alarmScheduler = alarmScheduler
    }

    func currentStatus() async -> PermissionSnapshot {
        PermissionSnapshot(
            calendar: calendarReader.authorizationState(),
            alarm: await alarmScheduler.authorizationState()
        )
    }

    func requestCalendarAccess() async throws -> CalendarAuthorizationState {
        try await calendarReader.requestAuthorization()
    }

    func requestAlarmAccess() async throws -> AlarmAuthorizationState {
        try await alarmScheduler.requestAuthorization()
    }
}
