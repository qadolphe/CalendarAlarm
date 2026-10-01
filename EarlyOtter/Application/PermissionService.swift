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
        let notificationState: NotificationAuthorizationState
        switch await notificationCenter.authorizationStatus() {
        case .notDetermined: notificationState = .notDetermined
        case .authorized, .provisional, .ephemeral: notificationState = .authorized
        case .denied: notificationState = .denied
        case nil: notificationState = .unknown
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

extension UNUserNotificationCenter {
    /// The current authorization, or `nil` if the notification center doesn't
    /// answer in time. It sometimes never answers (seen on simulators after a cold
    /// boot), and app launch waits on this, so it must not hang the dashboard.
    func authorizationStatus(within seconds: TimeInterval = 2) async -> UNAuthorizationStatus? {
        await withCheckedContinuation { continuation in
            let resume = ResumeOnce(continuation)
            getNotificationSettings { settings in
                resume(settings.authorizationStatus)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                resume(nil)
            }
        }
    }
}

/// Resumes a continuation with whichever value arrives first and ignores the rest.
private final class ResumeOnce<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }

    func callAsFunction(_ value: Value) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
