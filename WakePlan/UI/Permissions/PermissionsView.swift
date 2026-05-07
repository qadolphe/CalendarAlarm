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

                    permissionCard(
                        title: "Calendar",
                        description: AppConfiguration.calendarPermissionExplanation,
                        status: viewModel.calendarStatus,
                        icon: "calendar",
                        isAuthorized: appState.permissions.calendar == .authorized,
                        actionTitle: "Allow Calendar Access",
                        action: { Task { await appState.requestCalendarAccess() } }
                    )

                    permissionCard(
                        title: "Alarm Access",
                        description: AppConfiguration.alarmPermissionExplanation,
                        status: viewModel.alarmStatus,
                        icon: "alarm",
                        isAuthorized: appState.permissions.alarm == .authorized,
                        actionTitle: "Allow Alarm Access",
                        action: { Task { await appState.requestAlarmAccess() } }
                    )
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

    private func permissionCard(
        title: String,
        description: String,
        status: String,
        icon: String,
        isAuthorized: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(WPStyles.primaryOrange)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(WPStyles.primaryText)
                    Text(description)
                        .font(.body)
                        .foregroundStyle(WPStyles.secondaryText)
                }
                Spacer()
            }

            HStack {
                Text(status)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isAuthorized ? WPStyles.successGreen : WPStyles.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((isAuthorized ? WPStyles.successGreen : WPStyles.surfaceRaised).opacity(0.18))
                    .clipShape(Capsule())

                Spacer()

                if !isAuthorized {
                    Button(actionTitle) {
                        action()
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(WPStyles.primaryOrange)
                }
            }
            .padding(.top, 4)
        }
        .cardStyle()
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
