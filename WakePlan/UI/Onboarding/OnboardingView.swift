import SwiftUI

struct OnboardingView: View {
    @Bindable var appState: AppState
    let onFinish: () -> Void

    @State private var step = 0
    @State private var draftPreferences = AlarmPreferences.default

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    progressHeader
                    
                    VStack(spacing: 0) {
                        stepContent
                    }
                    .cardStyle()
                    
                    Spacer()
                    footer
                }
                .padding(24)
            }
            .withAppBackground()
            .navigationBarTitleDisplayMode(.inline)
            .task {
                draftPreferences = appState.preferences
                alignStepWithPermissions()
            }
            .onChange(of: appState.permissions) { _, _ in
                alignStepWithPermissions()
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WakePlan")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? WPStyles.primaryOrange : WPStyles.primaryOrange.opacity(0.18))
                        .frame(height: 8)
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            introStep
        case 1:
            calendarStep
        case 2:
            timingStep
        default:
            alarmStep
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Wake up based on tomorrow's calendar.")
                .font(WPStyles.heroTitleFont)
                .foregroundStyle(.primary)

            Text("WakePlan finds your first important event and sets a real alarm.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Text("A calm plan for the morning, without extra setup every night.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calendarStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Connect your calendar.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("WakePlan reads your events on-device to calculate your wake-up time.")
                .font(.body)
                .foregroundStyle(.secondary)

            statusLine(
                title: "Calendar access",
                value: PermissionsViewModel(appState: appState).calendarStatus
            )

            Button("Connect Apple Calendar") {
                Task { await appState.requestCalendarAccess() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timingStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Set your morning buffer.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

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

                DatePicker(
                    "Fallback wake time",
                    selection: fallbackWakeTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var alarmStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Allow alarm access.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("WakePlan needs permission to schedule real alarms.")
                .font(.body)
                .foregroundStyle(.secondary)

            statusLine(
                title: "Alarm access",
                value: PermissionsViewModel(appState: appState).alarmStatus
            )

            Button("Allow Alarm Access") {
                Task { await appState.requestAlarmAccess() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)

            if appState.permissions.alarm != .authorized {
                Button("Continue to Dashboard") {
                    onFinish()
                }
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") {
                    step -= 1
                }
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Spacer()

            Button(primaryActionTitle) {
                Task { await handlePrimaryAction() }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var primaryActionTitle: String {
        switch step {
        case 0:
            return "Get Started"
        case 1:
            return appState.permissions.calendar == .authorized ? "Continue" : "Skip for Now"
        case 2:
            return "Save Timing"
        default:
            return appState.permissions.alarm == .authorized ? "Open Dashboard" : "Finish Later"
        }
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

    private func handlePrimaryAction() async {
        switch step {
        case 0:
            step = 1
        case 1:
            step = 2
        case 2:
            await appState.updatePreferences(draftPreferences)
            step = 3
        default:
            onFinish()
        }
    }

    private func alignStepWithPermissions() {
        if step == 1, appState.permissions.calendar == .authorized {
            step = 2
        }

        if step == 3, appState.permissions.alarm == .authorized {
            onFinish()
        }
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

    private func statusLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
