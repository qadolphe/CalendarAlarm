import SwiftUI

// MARK: - Schedule (typealias kept for any lingering references)
typealias ScheduleView = SettingsView

// MARK: - Settings tab (app-level configuration only)

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    systemToggleCard

                    VStack(alignment: .leading, spacing: 0) {
                        appSettingsLinks
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: App settings nav links

    private var appSettingsLinks: some View {
        VStack(spacing: 0) {
            navRow(title: "Accounts", icon: "person.crop.circle.badge.plus") {
                AccountsView(appState: appState)
            } subtitle: {
                Text(SettingsViewModel(appState: appState).accountsSummary)
            }
            Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)
            navRow(title: "Event Filters", icon: "line.3.horizontal.decrease.circle") {
                EventFilterSettingsView(appState: appState)
            }
            Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)
            navRow(title: "Keywords", icon: "text.magnifyingglass") {
                KeywordRulesEditorView(appState: appState)
            }
            Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)
            navRow(title: "Permissions", icon: "lock.shield") {
                PermissionsView(appState: appState)
            }
            Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)
            Button("Refresh App State") {
                Task { await appState.load() }
            }
            .foregroundStyle(WPStyles.primaryOrange)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(WPStyles.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
    }

    private func navRow<D: View, Subtitle: View>(
        title: String,
        icon: String,
        @ViewBuilder destination: () -> D,
        @ViewBuilder subtitle: () -> Subtitle = { EmptyView() }
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(WPStyles.primaryOrange)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(WPStyles.primaryText)
                    subtitle()
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.secondaryText)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WPStyles.tertiaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    private var systemToggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("System Active")
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
                Spacer()
                Toggle("", isOn: isSystemEnabledBinding)
                    .labelsHidden()
                    .tint(WPStyles.primaryOrange)
            }
            Text(appState.preferences.isSystemEnabled ? "WakePlan will schedule alarms based on your rules." : "WakePlan is completely disabled. No alarms will run.")
                .font(.subheadline)
                .foregroundStyle(WPStyles.secondaryText)
        }
        .cardStyle()
    }

    private var isSystemEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.isSystemEnabled },
            set: { v in
                var copy = appState.preferences
                copy.isSystemEnabled = v
                Task { await appState.updatePreferences(copy) }
            }
        )
    }
}

struct AccountsView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Accounts")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(WPStyles.primaryText)
                        .padding(.top, 20)

                    Text("WakePlan keeps event logic behind one normalized pipeline. Accounts only control which external sources are available to that pipeline.")
                        .font(.body)
                        .foregroundStyle(WPStyles.secondaryText)

                    accountsCard

                    if let notice = appState.noticeMessage {
                        noticeBanner(notice)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var accountsCard: some View {
        VStack(spacing: 0) {
            accountInfoRow(
                title: "Apple Calendar",
                subtitle: appState.permissions.calendar == .authorized ? "Connected by iOS" : "Calendar access needed",
                icon: "apple.logo"
            )

            Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)

            Button {
                Task { await appState.addGoogleAccount() }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(WPStyles.primaryOrange)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Google")
                            .foregroundStyle(WPStyles.primaryText)
                        Text("Add Google Account")
                            .font(.subheadline)
                            .foregroundStyle(WPStyles.secondaryText)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            let googleAccounts = appState.accounts.filter { $0.provider == .google }

            if !googleAccounts.isEmpty {
                Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)

                ForEach(Array(googleAccounts.enumerated()), id: \.element.id) { index, account in
                    accountToggleRow(account)

                    if index < googleAccounts.count - 1 {
                        Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(WPStyles.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
    }

    private func accountInfoRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(WPStyles.primaryText)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func accountToggleRow(_ account: ConnectedCalendarAccount) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "globe")
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .foregroundStyle(WPStyles.primaryText)
                Text(account.isEnabled ? "Enabled" : "Disabled")
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)
            }

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { account.isEnabled },
                    set: { newValue in
                        Task { await appState.setAccountEnabled(id: account.id, isEnabled: newValue) }
                    }
                )
            )
            .labelsHidden()
            .tint(WPStyles.primaryOrange)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func noticeBanner(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(WPStyles.primaryOrange)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(WPStyles.primaryText)
            Spacer()
        }
        .padding(16)
        .background(WPStyles.primaryOrange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
