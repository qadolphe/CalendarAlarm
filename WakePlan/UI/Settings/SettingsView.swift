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
            }
            Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)
            navRow(title: "Permissions", icon: "lock.shield") {
                PermissionsView(appState: appState)
            }
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
            .contentShape(Rectangle())
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
            Text(appState.preferences.isSystemEnabled ? "EarlyOtter will schedule alarms based on your rules." : "EarlyOtter is completely disabled. No alarms will run.")
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

    private var appleAccount: ConnectedCalendarAccount? {
        appState.accounts.first(where: { $0.provider == .apple })
    }

    private var googleAccounts: [ConnectedCalendarAccount] {
        appState.accounts.filter { $0.provider == .google }
    }

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            List {
                if appleAccount != nil || !googleAccounts.isEmpty {
                    Section(header: sectionHeader("Connected Accounts"), footer: Text("EarlyOtter keeps event logic behind one normalized pipeline. Accounts only control which external sources are available to that pipeline.").font(.caption).foregroundStyle(WPStyles.secondaryText)) {
                        if let appleAccount {
                        accountToggleRow(appleAccount, icon: "apple.logo")
                            .listRowBackground(WPStyles.surface)
                        }

                        ForEach(googleAccounts) { account in
                            accountToggleRow(account, icon: "G")
                                .listRowBackground(WPStyles.surface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await appState.removeAccount(id: account.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                Section {
                    if appleAccount == nil {
                        Button {
                            Task { await appState.connectAppleCalendar() }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(WPStyles.primaryOrange)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Apple Calendar")
                                        .foregroundStyle(WPStyles.primaryText)
                                    Text("Connect Apple Calendar")
                                        .font(.subheadline)
                                        .foregroundStyle(WPStyles.secondaryText)
                                }
                            }
                        }
                        .listRowBackground(WPStyles.surface)
                    }

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
                        }
                    }
                    .listRowBackground(WPStyles.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            
            if let notice = appState.noticeMessage {
                VStack {
                    Spacer()
                    Text(notice)
                        .font(.subheadline)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(WPStyles.secondaryText)
            .textCase(nil)
    }

    private func accountToggleRow(_ account: ConnectedCalendarAccount, icon: String) -> some View {
        HStack(spacing: 14) {
            if account.provider == .apple {
                Image(systemName: "apple.logo")
                    .foregroundStyle(WPStyles.primaryOrange)
                    .frame(width: 24)
            } else {
                Text("G")
                    .font(.headline.weight(.black))
                    .foregroundStyle(WPStyles.primaryOrange)
                    .frame(width: 24)
            }

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
