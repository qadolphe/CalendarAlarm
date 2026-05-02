import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = SettingsViewModel(appState: appState)

        ZStack {
            Color.clear
                .withAppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Settings")
                        .font(.largeTitle.weight(.bold))
                        .padding(.top, 20)

                    alarmCard
                    timingCard(viewModel: viewModel)
                    filtersCard

                    VStack(spacing: 0) {
                        NavigationLink {
                            CalendarSelectionView(appState: appState)
                        } label: {
                            settingsRow(
                                title: "Calendars",
                                subtitle: viewModel.selectedCalendarsSummary,
                                icon: "calendar.badge.clock"
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.vertical, 14)

                        NavigationLink {
                            PermissionsView(appState: appState)
                        } label: {
                            settingsRow(
                                title: "Permissions",
                                subtitle: viewModel.permissionsSummary,
                                icon: "lock.shield",
                                showWarning: viewModel.needsPermissions
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                    .cardStyle()
                }
                .padding(24)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var alarmCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Automatic Alarm",
                subtitle: "Keep tomorrow's wake-up time synced with your calendar."
            )

            Toggle("Enabled", isOn: binding(\.isEnabled))
                .tint(WPStyles.primaryOrange)
                .font(.headline)
        }
        .cardStyle()
    }

    private func timingCard(viewModel: SettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Timing",
                subtitle: viewModel.timingSummary
            )

            NavigationLink {
                TimingSettingsView(appState: appState)
            } label: {
                settingsRow(
                    title: "Edit Timing",
                    subtitle: "Prep time, commute buffer, and latest wake time",
                    icon: "clock.badge.checkmark"
                )
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Ignore Rules",
                subtitle: "Choose which events WakePlan should skip when calculating tomorrow's alarm."
            )

            toggleRow("All-day events", binding: binding(\.ignoreAllDayEvents))
            Divider()
            toggleRow("Tentative events", binding: binding(\.ignoreTentativeEvents))
            Divider()
            toggleRow("Canceled events", binding: binding(\.ignoreCanceledEvents))
            Divider()
            toggleRow("Free events", binding: binding(\.ignoreFreeEvents))
        }
        .cardStyle()
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func toggleRow(_ title: String, binding: Binding<Bool>) -> some View {
        Toggle(title, isOn: binding)
            .tint(WPStyles.primaryOrange)
            .font(.headline)
    }

    private func settingsRow(title: String, subtitle: String, icon: String, showWarning: Bool = false) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(showWarning ? WPStyles.warningBanner : .secondary)
            }
            
            Spacer()
            
            if showWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(WPStyles.warningBanner)
            }
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.subheadline.weight(.semibold))
        }
        .contentShape(Rectangle())
    }

    private func binding(_ keyPath: WritableKeyPath<AlarmPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.preferences[keyPath: keyPath] },
            set: { newValue in
                var copy = appState.preferences
                copy[keyPath: keyPath] = newValue
                Task { await appState.updatePreferences(copy) }
            }
        )
    }
}
