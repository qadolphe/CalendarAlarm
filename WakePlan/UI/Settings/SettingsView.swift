import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = SettingsViewModel(appState: appState)

        ZStack {
            Color.clear.withAppBackground()

            List {
                Section {
                    Toggle(isOn: binding(\.isEnabled)) {
                        Label("Auto-Pilot Enabled", systemImage: "smart_toy")
                            .foregroundStyle(appState.preferences.isEnabled ? WPStyles.primaryOrange : WPStyles.primaryText)
                    }
                    .tint(WPStyles.primaryOrange)
                } footer: {
                    Text("When disabled, WakePlan will not schedule alarms or check your calendar.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(WPStyles.primaryOrange.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "smart_toy")
                                    .foregroundStyle(WPStyles.primaryOrange)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Auto-Pilot")
                                    .font(.headline)
                                    .foregroundStyle(WPStyles.primaryText)
                                Text(appState.preferences.isEnabled ? "Currently Active" : "Currently Paused")
                                    .font(.subheadline)
                                    .foregroundStyle(WPStyles.secondaryText)
                            }

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.activeRoutineTitle)
                                .font(.headline)
                                .foregroundStyle(WPStyles.primaryText)
                            Text(viewModel.activeRoutineSummary)
                                .font(.subheadline)
                                .foregroundStyle(WPStyles.secondaryText)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Schedule Grid") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(viewModel.activeDaysSummary)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(WPStyles.secondaryText)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                            ForEach(Array(viewModel.weekdayOptions.enumerated()), id: \.offset) { _, option in
                                Button {
                                    toggleActiveDay(option.weekday)
                                } label: {
                                    VStack(spacing: 8) {
                                        Text(option.label)
                                            .font(.caption.weight(.bold))
                                        Circle()
                                            .fill(appState.preferences.activeDays.contains(option.weekday) ? WPStyles.primaryOrange : WPStyles.surfaceRaised)
                                            .frame(width: 6, height: 6)
                                            .shadow(color: appState.preferences.activeDays.contains(option.weekday) ? WPStyles.primaryOrange.opacity(0.8) : .clear, radius: 8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(appState.preferences.activeDays.contains(option.weekday) ? WPStyles.surfaceRaised : WPStyles.surface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(appState.preferences.activeDays.contains(option.weekday) ? WPStyles.primaryOrange.opacity(0.6) : Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                    .foregroundStyle(appState.preferences.activeDays.contains(option.weekday) ? WPStyles.primaryText : WPStyles.secondaryText.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                }

                Section("Morning Baseline") {
                    NavigationLink(destination: TimingSettingsView(appState: appState)) {
                        settingsRow(title: "Morning Routine", value: "\(appState.preferences.prepTime.rawValue) mins", icon: "cup.and.saucer.fill")
                    }

                    NavigationLink(destination: TimingSettingsView(appState: appState)) {
                        settingsRow(title: "Default Commute", value: "\(appState.preferences.defaultCommuteTime.rawValue) mins", icon: "car.fill")
                    }

                    HStack {
                        Label("Latest Wake Time", systemImage: "bed.double.fill")
                            .foregroundStyle(WPStyles.primaryText)
                        Spacer()
                        DatePicker(
                            "",
                            selection: latestWakeTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .colorScheme(.dark)
                    }
                }

                Section("Event Filtering") {
                    NavigationLink(destination: CalendarSelectionView(appState: appState)) {
                        settingsRow(title: "Active Calendars", value: viewModel.selectedCalendarsSummary, icon: "calendar.badge.clock")
                    }

                    Toggle("Ignore All-Day Events", isOn: binding(\.ignoreAllDayEvents))
                        .tint(WPStyles.primaryOrange)
                    Toggle("Ignore Tentative Events", isOn: binding(\.ignoreTentativeEvents))
                        .tint(WPStyles.primaryOrange)
                }

                Section("Additional Links") {
                    NavigationLink(destination: RulesView(appState: appState)) {
                        settingsRow(title: "Logic", value: "How WakePlan decides", icon: "tune")
                    }

                    NavigationLink(destination: ManualAlarmListView(appState: appState)) {
                        settingsRow(title: "Alarms", value: viewModel.alarmListSummary, icon: "alarm")
                    }

                    NavigationLink(destination: PermissionsView(appState: appState)) {
                        settingsRow(title: "Permissions", value: viewModel.permissionsSummary, icon: "lock.shield")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .environment(\.defaultMinListRowHeight, 60)
        }
        .navigationTitle("Rules & Settings")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(WPStyles.background, for: .navigationBar)
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

    private var latestWakeTimeBinding: Binding<Date> {
        Binding(
            get: {
                let targetDay = TargetDay(date: Date())
                return appState.preferences.latestWakeTime.date(on: targetDay)
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                guard let hour = components.hour, let minute = components.minute else { return }

                var copy = appState.preferences
                copy.latestWakeTime = ClockTime(hour: hour, minute: minute)
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

    private func settingsRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(WPStyles.primaryOrange)

            Text(title)
                .foregroundStyle(WPStyles.primaryText)

            Spacer()

            Text(value)
                .foregroundStyle(WPStyles.secondaryText)
                .lineLimit(1)
        }
    }
}

struct ManualAlarmListView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = ManualAlarmListViewModel(appState: appState)

        ZStack {
            Color.clear.withAppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Alarms")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(WPStyles.primaryText)
                        .padding(.top, 20)

                    VStack(spacing: 8) {
                        ForEach(viewModel.rows) { row in
                            alarmRow(row)
                        }
                    }
                    .padding(8)
                    .insetSurfaceStyle(cornerRadius: 16)
                }
                .padding(16)
            }
        }
        .navigationTitle("Alarms")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func alarmRow(_ row: ManualAlarmRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.time)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(WPStyles.primaryText)
                    Text(row.period)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(WPStyles.secondaryText)
                }

                Text(row.days)
                    .font(.subheadline)
                    .foregroundStyle(row.isEnabled ? WPStyles.secondaryText : WPStyles.secondaryText.opacity(0.6))
            }

            Spacer()

            Toggle("", isOn: .constant(row.isEnabled))
                .labelsHidden()
                .tint(WPStyles.primaryOrange)
                .disabled(true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(row.isHighlighted ? WPStyles.primaryOrange.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(row.isHighlighted ? WPStyles.primaryOrange.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }
}

private struct ManualAlarmRow: Identifiable {
    let id: String
    let time: String
    let period: String
    let days: String
    let isEnabled: Bool
    let isHighlighted: Bool
}

@MainActor
private struct ManualAlarmListViewModel {
    let rows: [ManualAlarmRow]

    init(appState: AppState) {
        let preferences = appState.preferences
        var builtRows: [ManualAlarmRow] = []

        if case let .ready(viewState) = appState.dashboardState {
            builtRows.append(Self.row(
                id: "scheduled-primary",
                date: viewState.plan.calculatedWakeTime,
                days: Self.describe(activeDays: preferences.activeDays),
                isEnabled: true,
                isHighlighted: true
            ))
        } else if case let .emptyFallback(viewState) = appState.dashboardState {
            builtRows.append(Self.row(
                id: "fallback-primary",
                date: viewState.plan.calculatedWakeTime,
                days: "Fallback schedule",
                isEnabled: preferences.isEnabled,
                isHighlighted: true
            ))
        }

        let latestWakeDate = preferences.latestWakeTime.date(on: TargetDay(date: Date()))

        if preferences.activeDays != Set([1, 2, 3, 4, 5, 6, 7]) {
            builtRows.append(Self.row(
                id: "weekday-auto-pilot",
                date: latestWakeDate,
                days: Self.describe(activeDays: preferences.activeDays),
                isEnabled: preferences.isEnabled,
                isHighlighted: preferences.isEnabled
            ))
        }

        let inactiveDays = Set([1, 2, 3, 4, 5, 6, 7]).subtracting(preferences.activeDays)
        if !inactiveDays.isEmpty {
            builtRows.append(Self.row(
                id: "inactive-days",
                date: latestWakeDate,
                days: Self.describe(activeDays: inactiveDays),
                isEnabled: false,
                isHighlighted: false
            ))
        }

        if builtRows.isEmpty {
            builtRows.append(Self.row(
                id: "default",
                date: latestWakeDate,
                days: "Everyday",
                isEnabled: preferences.isEnabled,
                isHighlighted: preferences.isEnabled
            ))
        }

        rows = builtRows
    }

    private static func row(id: String, date: Date, days: String, isEnabled: Bool, isHighlighted: Bool) -> ManualAlarmRow {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm"
        let time = formatter.string(from: date)
        formatter.dateFormat = "a"
        let period = formatter.string(from: date)

        return ManualAlarmRow(
            id: id,
            time: time,
            period: period,
            days: days,
            isEnabled: isEnabled,
            isHighlighted: isHighlighted
        )
    }

    private static func describe(activeDays: Set<Int>) -> String {
        if activeDays == Set([1, 2, 3, 4, 5, 6, 7]) {
            return "Everyday"
        }

        let ordered: [(Int, String)] = [
            (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
        ]

        let labels = ordered.compactMap { activeDays.contains($0.0) ? $0.1 : nil }
        return labels.joined(separator: ", ")
    }
}
