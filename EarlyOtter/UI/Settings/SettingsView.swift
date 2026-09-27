import SwiftUI

// MARK: - Settings (app-level configuration, opened from the Rules tab)

struct SettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var versionTapCount = 0

    var body: some View {
        SettingsPage(title: "Settings") {
            SettingsSection(
                "Alarms",
                footer: "Tip: add “Refresh Alarms” to a Shortcut automation to keep alarms synced."
            ) {
                SettingsToggleRow(
                    icon: "alarm.fill",
                    title: "EarlyOtter Alarms",
                    subtitle: appState.preferences.isSystemEnabled ? nil : "No alarms will ring",
                    isOn: isSystemEnabledBinding
                )
            }

            SettingsSection("Calendars") {
                SettingsNavRow(icon: "person.crop.circle", title: "Accounts", value: accountsValue) {
                    AccountsView(appState: appState)
                }
                SettingsNavRow(
                    icon: "lock.shield",
                    title: "Permissions",
                    value: permissionsValue,
                    valueTint: missingPermissionCount == 0 ? WPStyles.secondaryText : WPStyles.accent
                ) {
                    PermissionsView(appState: appState)
                }
            }

            SettingsSection("Support") {
                SettingsNavRow(icon: "bubble.left.and.bubble.right", title: "Send Feedback") {
                    FeedbackView(appState: appState)
                }
                Button {
                    openURL(AppConfiguration.writeReviewURL)
                } label: {
                    SettingsRow(icon: "star.fill", iconTint: WPStyles.accent, title: "Rate EarlyOtter") {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(WPStyles.tertiaryText)
                    }
                }
                .buttonStyle(.plain)
            }

            versionFooter
        }
    }

    /// Tapping the version seven times marks this phone as internal, so its
    /// telemetry is tagged and kept out of the real numbers.
    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("\(AppConfiguration.appName) \(AppConfiguration.appVersionWithBuild)")
            if appState.isInternalDevice {
                Text("Internal device")
                    .foregroundStyle(WPStyles.accent)
            }
        }
        .font(.footnote)
        .foregroundStyle(WPStyles.tertiaryText)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            versionTapCount += 1
            guard versionTapCount >= 7 else { return }
            versionTapCount = 0
            Task { await appState.setInternalDevice(!appState.isInternalDevice) }
        }
    }

    private var accountsValue: String {
        let count = appState.accounts.filter(\.isEnabled).count
        return count == 0 ? "None" : "\(count) connected"
    }

    private var missingPermissionCount: Int {
        let permissions = appState.permissions
        return [
            permissions.calendar == .authorized,
            permissions.alarm == .authorized,
            permissions.notification == .authorized
        ].filter { !$0 }.count
    }

    private var permissionsValue: String {
        missingPermissionCount == 0 ? "All set" : "\(missingPermissionCount) needed"
    }

    private var isSystemEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.isSystemEnabled },
            set: { isOn in
                Task { await appState.mutatePreferences { $0.isSystemEnabled = isOn } }
            }
        )
    }
}

// MARK: - Accounts

struct AccountsView: View {
    @Bindable var appState: AppState
    @State private var pendingRemovalID: CalendarAccountID?

    private var appleAccount: ConnectedCalendarAccount? {
        appState.accounts.first(where: { $0.provider == .apple })
    }

    private var googleAccounts: [ConnectedCalendarAccount] {
        appState.accounts.filter { $0.provider == .google }
    }

    var body: some View {
        SettingsPage(title: "Accounts") {
            if let notice = appState.noticeMessage {
                StatusBanner(text: notice, kind: .notice)
            }

            if appleAccount != nil || !googleAccounts.isEmpty {
                SettingsSection(
                    "Connected",
                    footer: googleAccounts.isEmpty ? nil : "Long-press a Google account to remove it."
                ) {
                    if let appleAccount {
                        accountRow(appleAccount)
                    }
                    ForEach(googleAccounts) { account in
                        accountRow(account)
                    }
                }
            }

            SettingsSection("Add") {
                if appleAccount == nil {
                    addRow(title: "Apple Calendar") {
                        await appState.connectAppleCalendar()
                    }
                }
                addRow(title: "Google Account") {
                    await appState.addGoogleAccount()
                }
            }
        }
    }

    @ViewBuilder
    private func accountRow(_ account: ConnectedCalendarAccount) -> some View {
        let icon = account.provider == .apple ? "apple.logo" : "g.circle.fill"

        if pendingRemovalID == account.id {
            SettingsRow(icon: icon, title: account.displayName, subtitle: "Remove this account?") {
                Button("Cancel") { pendingRemovalID = nil }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WPStyles.secondaryText)
                Button("Remove") {
                    pendingRemovalID = nil
                    Task { await appState.removeAccount(id: account.id) }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        } else {
            SettingsToggleRow(
                icon: icon,
                title: account.displayName,
                isOn: Binding(
                    get: { account.isEnabled },
                    set: { isOn in
                        Task { await appState.setAccountEnabled(id: account.id, isEnabled: isOn) }
                    }
                )
            )
            .contextMenu {
                if account.provider == .google {
                    Button("Remove Account", systemImage: "trash", role: .destructive) {
                        pendingRemovalID = account.id
                    }
                }
            }
        }
    }

    private func addRow(title: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            SettingsRow(icon: "plus", iconTint: WPStyles.accent, title: title)
        }
        .buttonStyle(.plain)
    }
}
