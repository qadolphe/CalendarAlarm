import SwiftUI

struct PermissionsView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = PermissionsViewModel(appState: appState)

        ZStack {
            Color.clear
                .withAppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("EarlyOtter keeps your alarm plan on-device and only requests the access it needs.")
                        .font(.body)
                        .foregroundStyle(WPStyles.secondaryText)
                        .padding(.top, 20)

                    if let errorMessage = appState.errorMessage {
                        statusBanner(errorMessage, tint: .red)
                    }

                    if let noticeMessage = appState.noticeMessage {
                        statusBanner(noticeMessage, tint: WPStyles.primaryOrange)
                    }

                    VStack(spacing: 0) {
                        permissionRow(
                            title: "Calendar",
                            description: "Needed to view your upcoming events.",
                            status: viewModel.calendarStatus,
                            icon: "calendar",
                            isAuthorized: appState.permissions.calendar == .authorized,
                            actionTitle: "Allow",
                            action: { Task { await appState.requestCalendarAccess() } }
                        )

                        Divider().overlay(WPStyles.cardBorder).padding(.leading, 48)

                        permissionRow(
                            title: "Alarms",
                            description: "Needed to schedule wake-up routines.",
                            status: viewModel.alarmStatus,
                            icon: "alarm.fill",
                            isAuthorized: appState.permissions.alarm == .authorized,
                            actionTitle: "Allow",
                            action: { Task { await appState.requestAlarmAccess() } }
                        )

                        Divider().overlay(WPStyles.cardBorder).padding(.leading, 48)

                        permissionRow(
                            title: "Notifications",
                            description: "Needed to alert you when alarms sync or fail.",
                            status: viewModel.notificationStatus,
                            icon: "bell.fill",
                            isAuthorized: appState.permissions.notification == .authorized,
                            actionTitle: "Allow",
                            action: { Task { await appState.requestNotificationAccess() } }
                        )
                    }
                    .cardStyle()
                }
                .padding(24)
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.refreshPermissions()
        }
    }

    private func permissionRow(
        title: String,
        description: String,
        status: String,
        icon: String,
        isAuthorized: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isAuthorized ? WPStyles.successGreen : WPStyles.secondaryText)
                        
                    Spacer()
                    
                    if !isAuthorized {
                        Button(actionTitle) {
                            action()
                        }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.bordered)
                        .tint(WPStyles.primaryOrange)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }

    private func statusBanner(_ text: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(WPStyles.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}
