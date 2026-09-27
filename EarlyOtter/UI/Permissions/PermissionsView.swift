import SwiftUI

struct PermissionsView: View {
    @Bindable var appState: AppState
    @Environment(\.openURL) private var openURL

    var body: some View {
        SettingsPage(title: "Permissions") {
            if let errorMessage = appState.errorMessage {
                StatusBanner(text: errorMessage, kind: .error)
            }
            if let noticeMessage = appState.noticeMessage {
                StatusBanner(text: noticeMessage, kind: .notice)
            }

            SettingsSection("Access") {
                permissionRow(
                    icon: "calendar",
                    title: "Calendar",
                    access: PermissionAccess(appState.permissions.calendar)
                ) { await appState.requestCalendarAccess() }

                permissionRow(
                    icon: "alarm.fill",
                    title: "Alarms",
                    access: PermissionAccess(appState.permissions.alarm)
                ) { await appState.requestAlarmAccess() }

                permissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    access: PermissionAccess(appState.permissions.notification)
                ) { await appState.requestNotificationAccess() }
            }

            SettingsSection("Privacy", footer: "Counts only. Never your calendar details.") {
                SettingsToggleRow(
                    icon: "chart.bar.fill",
                    title: "Share Usage Data",
                    isOn: Binding(
                        get: { appState.isUsageSharingEnabled },
                        set: { isOn in Task { await appState.setUsageSharingEnabled(isOn) } }
                    )
                )
                Button {
                    openURL(AppConfiguration.privacyPolicyURL)
                } label: {
                    SettingsRow(icon: "doc.text", title: "Privacy Policy") {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(WPStyles.tertiaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await appState.refreshPermissions()
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        access: PermissionAccess,
        request: @escaping () async -> Void
    ) -> some View {
        SettingsRow(icon: icon, title: title) {
            switch access {
            case .allowed:
                Text("Allowed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WPStyles.successGreen)
            case .requestable:
                Button("Allow") { Task { await request() } }
                    .buttonStyle(PrimaryCapsuleButtonStyle())
            case .denied:
                Button("Open Settings") { appState.openSettings() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(WPStyles.surfaceRaised, in: Capsule())
                    .buttonStyle(.plain)
            }
        }
    }
}

/// How a permission row should present itself, independent of the source framework.
private enum PermissionAccess {
    case allowed
    case requestable
    case denied

    init(_ state: CalendarAuthorizationState) {
        switch state {
        case .authorized: self = .allowed
        case .denied, .restricted: self = .denied
        case .notDetermined, .unknown: self = .requestable
        }
    }

    init(_ state: AlarmAuthorizationState) {
        switch state {
        case .authorized: self = .allowed
        case .denied: self = .denied
        case .notDetermined, .unknown: self = .requestable
        }
    }

    init(_ state: NotificationAuthorizationState) {
        switch state {
        case .authorized: self = .allowed
        case .denied: self = .denied
        case .notDetermined, .unknown: self = .requestable
        }
    }
}
