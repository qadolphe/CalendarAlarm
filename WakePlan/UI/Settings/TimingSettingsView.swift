import SwiftUI

struct TimingSettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var draftPreferences: AlarmPreferences

    init(appState: AppState) {
        self.appState = appState
        self._draftPreferences = State(initialValue: appState.preferences)
    }

    var body: some View {
        ZStack {
            WPStyles.bgGradientStart.ignoresSafeArea()
                .withAppBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Edit Timing")
                        .font(.largeTitle.weight(.bold))
                        .padding(.top, 20)
                    
                    Text("Adjust how WakePlan calculates your morning alarm.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 20) {
                        stepperRow(
                            title: "Prep time",
                            value: $draftPreferences.prepTime,
                            range: 0...180
                        )

                        Divider()

                        stepperRow(
                            title: "Commute buffer",
                            value: $draftPreferences.defaultCommuteTime,
                            range: 0...180
                        )

                        Divider()

                        HStack {
                            Text("Fallback wake time")
                                .font(.headline)
                            Spacer()
                            DatePicker(
                                "",
                                selection: fallbackWakeTimeBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        }
                    }
                    .padding(.vertical, 8)
                    .cardStyle()

                    Button("Save Changes") {
                        Task {
                            await appState.updatePreferences(draftPreferences)
                            dismiss()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 16)
                }
                .padding(24)
            }
        }
        .navigationTitle("Timing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var fallbackWakeTimeBinding: Binding<Date> {
        Binding(
            get: {
                let targetDay = TargetDay(date: Date())
                return draftPreferences.latestWakeTime.date(on: targetDay)
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                guard let hour = components.hour, let minute = components.minute else { return }
                draftPreferences.latestWakeTime = ClockTime(hour: hour, minute: minute)
            }
        )
    }

    private func stepperRow(
        title: String,
        value: Binding<Minutes>,
        range: ClosedRange<Int>
    ) -> some View {
        Stepper(
            value: Binding(
                get: { value.wrappedValue.rawValue },
                set: { value.wrappedValue = Minutes($0) }
            ),
            in: range,
            step: 5
        ) {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text("\(value.wrappedValue.rawValue) min")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }
}
