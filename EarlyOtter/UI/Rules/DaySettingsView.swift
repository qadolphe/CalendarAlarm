import SwiftUI

struct DaySettingsView: View {
    @Bindable var appState: AppState
    let weekdayOption: WeekdayOption
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.withAppBackground()

                List {
                    Section(header: Text("Auto-Pilot").font(.subheadline.weight(.semibold)).foregroundStyle(WPStyles.secondaryText).textCase(.uppercase)) {
                        Toggle("Event Alarm", isOn: activeBinding)
                            .tint(WPStyles.primaryOrange)
                            .foregroundStyle(WPStyles.primaryText)
                        
                        Text("Use calendar events to set this day's alarm.")
                            .font(.caption)
                            .foregroundStyle(WPStyles.secondaryText)
                    }
                    .listRowBackground(WPStyles.surface)

                    Section(header: Text("Fixed Alarm").font(.subheadline.weight(.semibold)).foregroundStyle(WPStyles.secondaryText).textCase(.uppercase)) {
                        Toggle("Enable Fixed Alarm", isOn: fallbackEnabledBinding)
                            .tint(WPStyles.primaryOrange)
                            .foregroundStyle(WPStyles.primaryText)
                        
                        if appState.preferences.fallbackEnabledDays.contains(weekdayOption.weekday) {
                            DatePicker(
                                "Wake Time",
                                selection: fallbackTimeBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .foregroundStyle(WPStyles.primaryText)
                        }
                        
                        Text("Use a fixed alarm when you want a guaranteed wake-up.")
                            .font(.caption)
                            .foregroundStyle(WPStyles.secondaryText)
                    }
                    .listRowBackground(WPStyles.surface)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
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
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var activeBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.activeDays.contains(weekdayOption.weekday) },
            set: { v in
                var copy = appState.preferences
                if v {
                    copy.activeDays.insert(weekdayOption.weekday)
                } else {
                    copy.activeDays.remove(weekdayOption.weekday)
                }
                Task { await appState.updatePreferences(copy) }
            }
        )
    }

    private var fallbackEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.fallbackEnabledDays.contains(weekdayOption.weekday) },
            set: { v in
                var copy = appState.preferences
                if v {
                    copy.fallbackEnabledDays.insert(weekdayOption.weekday)
                } else {
                    copy.fallbackEnabledDays.remove(weekdayOption.weekday)
                }
                Task { await appState.updatePreferences(copy) }
            }
        )
    }

    private var fallbackTimeBinding: Binding<Date> {
        Binding(
            get: {
                let clockTime = appState.preferences.fallbackWakeTime(for: weekdayOption.weekday)
                return clockTime.date(on: TargetDay(date: Date()))
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                if let h = comps.hour, let m = comps.minute {
                    var copy = appState.preferences
                    copy.schedule.fallbackWakeTimes[weekdayOption.weekday] = ClockTime(hour: h, minute: m)
                    Task { await appState.updatePreferences(copy) }
                }
            }
        )
    }
}
