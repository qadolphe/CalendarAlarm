import Foundation
import UserNotifications

enum NotificationAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case unknown
}

struct PermissionSnapshot: Equatable, Sendable {
    var calendar: CalendarAuthorizationState
    var alarm: AlarmAuthorizationState
    var notification: NotificationAuthorizationState

    static let initial = PermissionSnapshot(
        calendar: .notDetermined,
        alarm: .notDetermined,
        notification: .notDetermined
    )
}

final class PermissionService {
    private let calendarReader: CalendarReading
    private let alarmScheduler: AlarmScheduling
    private let notificationCenter: UNUserNotificationCenter

    init(
        calendarReader: CalendarReading,
        alarmScheduler: AlarmScheduling,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.calendarReader = calendarReader
        self.alarmScheduler = alarmScheduler
        self.notificationCenter = notificationCenter
    }

    func currentStatus() async -> PermissionSnapshot {
        let settings = await notificationCenter.notificationSettings()
        let notificationState: NotificationAuthorizationState
        switch settings.authorizationStatus {
        case .notDetermined: notificationState = .notDetermined
        case .authorized, .provisional, .ephemeral: notificationState = .authorized
        case .denied: notificationState = .denied
        @unknown default: notificationState = .unknown
        }

        return PermissionSnapshot(
            calendar: calendarReader.authorizationState(),
            alarm: await alarmScheduler.authorizationState(),
            notification: notificationState
        )
    }

    func requestCalendarAccess() async throws -> CalendarAuthorizationState {
        try await calendarReader.requestAuthorization()
    }

    func requestAlarmAccess() async throws -> AlarmAuthorizationState {
        try await alarmScheduler.requestAuthorization()
    }

    func requestNotificationAccess() async throws -> NotificationAuthorizationState {
        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ? .authorized : .denied
    }
}
