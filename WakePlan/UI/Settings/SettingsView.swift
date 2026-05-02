import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = SettingsViewModel(appState: appState)

        Form {
            Section("Automatic Alarm") {
                Toggle("Enabled", isOn: binding(\.isEnabled))
            }

            Section("Timing") {
                Stepper(
                    "Prep time: \(appState.preferences.prepTime.rawValue) min",
                    value: minutesBinding(\.prepTime),
                    in: 0...180,
                    step: 5
                )

                Stepper(
                    "Commute buffer: \(appState.preferences.defaultCommuteTime.rawValue) min",
                    value: minutesBinding(\.defaultCommuteTime),
                    in: 0...180,
                    step: 5
                )

                DatePicker(
                    "Latest wake time",
                    selection: latestWakeTimeBinding,
                    displayedComponents: .hourAndMinute
                )
            }

            Section("Calendars") {
                NavigationLink {
                    CalendarSelectionView(appState: appState)
                } label: {
                    LabeledContent("Selected calendars", value: viewModel.selectedCalendarsSummary)
                }
            }

            Section("Ignore") {
                Toggle("All-day events", isOn: binding(\.ignoreAllDayEvents))
                Toggle("Tentative events", isOn: binding(\.ignoreTentativeEvents))
                Toggle("Canceled events", isOn: binding(\.ignoreCanceledEvents))
                Toggle("Free events", isOn: binding(\.ignoreFreeEvents))
            }

            Section("Permissions") {
                NavigationLink {
                    PermissionsView(appState: appState)
                } label: {
                    Text("Manage permissions")
                }
            }
        }
        .navigationTitle("Settings")
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

    private func minutesBinding(_ keyPath: WritableKeyPath<AlarmPreferences, Minutes>) -> Binding<Int> {
        Binding(
            get: { appState.preferences[keyPath: keyPath].rawValue },
            set: { newValue in
                var copy = appState.preferences
                copy[keyPath: keyPath] = Minutes(newValue)
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
}
