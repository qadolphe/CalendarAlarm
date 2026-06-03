import SwiftUI

struct DaySettingsView: View {
    @Bindable var appState: AppState
    let weekdayOption: WeekdayOption
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.withAppBackground()

                VStack(spacing: 10) {
                    toggleCard(
                        icon: "calendar.badge.clock",
                        iconTint: WPStyles.primaryOrange,
                        title: "Calendar Alarms",
                        isOn: activeBinding
                    )

                    VStack(spacing: 0) {
                        toggleRow(
                            icon: "alarm.fill",
                            iconTint: WPStyles.secondaryBlue,
                            title: "Standby Alarm",
                            isOn: fallbackEnabledBinding
                        )

                        if appState.preferences.fallbackEnabledDays.contains(weekdayOption.weekday) {
                            Divider().overlay(WPStyles.cardBorder)
                            DatePicker(
                                "Wake Time",
                                selection: fallbackTimeBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .clipped()
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(WPStyles.surface))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("If you don't have any early events, EarlyOtter will wake you up at this time.")
                        .font(.caption)
                        .foregroundStyle(WPStyles.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("\(weekdayOption.fullLabel) Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(WPStyles.primaryOrange)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func toggleRow(icon: String, iconTint: Color, title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconTint)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
            }
        }
        .tint(WPStyles.primaryOrange)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func toggleCard(icon: String, iconTint: Color, title: String, isOn: Binding<Bool>) -> some View {
        toggleRow(icon: icon, iconTint: iconTint, title: title, isOn: isOn)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(WPStyles.surface))
    }

    private var weekday: Int { weekdayOption.weekday }

    private var activeBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.activeDays.contains(weekday) },
            set: { isOn in
                Task {
                    await appState.mutatePreferences { prefs in
                        if isOn { prefs.activeDays.insert(weekday) }
                        else { prefs.activeDays.remove(weekday) }
                    }
                }
            }
        )
    }

    private var fallbackEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.fixedAlarmEnabled(on: weekday) },
            set: { isOn in
                Task {
                    await appState.mutatePreferences { prefs in
                        if isOn { prefs.fallbackEnabledDays.insert(weekday) }
                        else { prefs.fallbackEnabledDays.remove(weekday) }
                    }
                }
            }
        )
    }

    private var fallbackTimeBinding: Binding<Date> {
        Binding(
            get: { appState.preferences.fallbackWakeTime(for: weekday).date(on: TargetDay(date: Date())) },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                guard let hour = comps.hour, let minute = comps.minute else { return }
                Task {
                    await appState.mutatePreferences { prefs in
                        prefs.schedule.fallbackWakeTimes[weekday] = ClockTime(hour: hour, minute: minute)
                    }
                }
            }
        )
    }
}
