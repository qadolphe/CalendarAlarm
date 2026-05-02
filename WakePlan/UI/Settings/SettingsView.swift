import SwiftUI

// MARK: - Schedule (now merged with Settings)

/// Kept for backward-compatibility references. Redirects to SettingsView.
typealias ScheduleView = SettingsView

// MARK: - Settings tab (contains schedule + app settings)

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    autoPilotCard
                    activeDaysCard
                    fallbackCard

                    appSettingsLinks
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Cards

    private var autoPilotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(WPStyles.primaryOrange.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .foregroundStyle(WPStyles.primaryOrange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Auto-Pilot")
                        .font(.headline)
                        .foregroundStyle(WPStyles.primaryText)
                    Text(appState.preferences.isEnabled ? "Active" : "Paused")
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.secondaryText)
                }

                Spacer()

                Toggle("", isOn: enabledBinding)
                    .labelsHidden()
                    .tint(WPStyles.primaryOrange)
            }
        }
        .cardStyle()
    }

    private var activeDaysCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Active Days")
                .font(.headline)
                .foregroundStyle(WPStyles.primaryText)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                spacing: 10
            ) {
                ForEach(WakePlanUIConfiguration.sundayFirstWeekdays) { option in
                    weekdayCell(option)
                }
            }
        }
        .cardStyle()
    }

    // MARK: Schedule cards

    private var fallbackCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fallback Wake Time")
                .font(.headline)
                .foregroundStyle(WPStyles.primaryText)

            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundStyle(WPStyles.primaryOrange)
                Text("Latest Wake Time")
                    .foregroundStyle(WPStyles.primaryText)
                Spacer()
                DatePicker("", selection: latestWakeTimeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
            }
        }
        .cardStyle()
    }

    // MARK: App settings nav links

    private var appSettingsLinks: some View {
        VStack(spacing: 0) {
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

    private func navRow<D: View>(title: String, icon: String, @ViewBuilder destination: () -> D) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(WPStyles.primaryOrange)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(WPStyles.primaryText)
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

    // MARK: Helpers

    private func weekdayCell(_ option: WeekdayOption) -> some View {
        let isSelected = appState.preferences.activeDays.contains(option.weekday)
        return Button { toggleActiveDay(option.weekday) } label: {
            VStack(spacing: 10) {
                Text(option.shortLabel).font(.caption.weight(.bold))
                Circle()
                    .fill(isSelected ? WPStyles.primaryOrange : WPStyles.surfaceRaised)
                    .frame(width: 8, height: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? WPStyles.surfaceRaised : WPStyles.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? WPStyles.primaryOrange.opacity(0.55) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? WPStyles.primaryText : WPStyles.secondaryText.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.isEnabled },
            set: { v in
                var copy = appState.preferences
                copy.isEnabled = v
                Task { await appState.updatePreferences(copy) }
            }
        )
    }

    private var latestWakeTimeBinding: Binding<Date> {
        Binding(
            get: {
                appState.preferences.latestWakeTime.date(on: TargetDay(date: Date()))
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                guard let h = c.hour, let m = c.minute else { return }
                var copy = appState.preferences
                copy.latestWakeTime = ClockTime(hour: h, minute: m)
                Task { await appState.updatePreferences(copy) }
            }
        )
    }

    private func toggleActiveDay(_ weekday: Int) {
        var copy = appState.preferences
        if copy.activeDays.contains(weekday) {
            guard copy.activeDays.count > 1 else { return }
            copy.activeDays.remove(weekday)
        } else {
            copy.activeDays.insert(weekday)
        }
        Task { await appState.updatePreferences(copy) }
    }
}


