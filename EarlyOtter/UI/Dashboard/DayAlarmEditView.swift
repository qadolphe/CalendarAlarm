import SwiftUI

/// Edits the alarm for a single calendar date only, reached from the week view.
/// Saving writes a `DayAlarmOverride`; the weekly schedule and rules are untouched.
struct DayAlarmEditView: View {
    let appState: AppState
    let plan: WakeUpPlan
    /// Called to crossfade back to the day detail (after Back, Save, or Reset).
    var onClose: () -> Void

    @State private var wakeDate: Date
    @State private var isSkipped: Bool
    @State private var extraAlarms: ExtraAlarms
    @State private var showingLateAlarmAlert = false

    private let seedWakeDate: Date
    private let startedWithOverride: Bool
    private let startedCustom: Bool
    private let initialOverride: DayAlarmOverride?

    init(appState: AppState, plan: WakeUpPlan, onClose: @escaping () -> Void) {
        self.appState = appState
        self.plan = plan
        self.onClose = onClose

        let existing = appState.preferences.override(for: plan.targetDay)
        startedWithOverride = existing != nil
        startedCustom = existing?.customWakeTime != nil
        initialOverride = existing

        let seed: Date
        let skip: Bool
        if let custom = existing?.customWakeTime {
            // A user-chosen fixed time.
            seed = custom.date(on: plan.targetDay)
            skip = existing?.isSkipped ?? false
        } else {
            // Automatic (possibly skipped): the plan carries the real automatic time.
            seed = plan.calculatedWakeTime
            skip = existing?.isSkipped ?? false
        }

        seedWakeDate = seed
        _wakeDate = State(initialValue: seed)
        _isSkipped = State(initialValue: skip)
        _extraAlarms = State(initialValue: plan.extraAlarms)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    skipCard
                    wakeTimeCard
                    extraAlarmsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            
            HStack(spacing: 12) {
                if startedWithOverride {
                    Button(action: reset) {
                        Text("Reset")
                            .font(.headline)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(WPStyles.surfaceRaised)
                            .foregroundStyle(Color(red: 0.8, green: 0.8, blue: 0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: attemptSave) {
                    Text("Save")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 8)
        }
        .alert("Late Alarm Warning", isPresented: $showingLateAlarmAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Save Anyway") {
                save()
            }
        } message: {
            Text("You are setting an alarm for the afternoon or after your first event starts. Are you sure?")
        }
    }

    // MARK: Inline top bar (mirrors a nav bar, but lives inside the shared sheet)

    private var topBar: some View {
        HStack {
            Text(dayTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(WPStyles.primaryText)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(WPStyles.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    // MARK: Wake time

    private var wakeTimeCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "alarm.fill")
                    .font(.title3)
                    .foregroundStyle(WPStyles.accent)
                Text("Wake Time")
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
                Spacer()
                Text(wakeDate, style: .time)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(WPStyles.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            DatePicker(
                "Wake Time",
                selection: $wakeDate,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipped()
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(WPStyles.surface))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(isSkipped ? 0.4 : 1)
        .disabled(isSkipped)
        .animation(.easeInOut(duration: 0.2), value: isSkipped)
    }

    // MARK: Extra alarms

    private var extraAlarmsCard: some View {
        NavigationLink {
            ExtraAlarmsPickerView(selection: $extraAlarms)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.title3)
                    .foregroundStyle(WPStyles.accent)
                Text("Extra alarms")
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
                Spacer()
                Text(ExtraAlarmsPickerView.rowValue(for: extraAlarms))
                    .foregroundStyle(WPStyles.secondaryText)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WPStyles.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(WPStyles.surface))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isSkipped ? 0.4 : 1)
        .disabled(isSkipped)
    }

    // MARK: Skip

    private var skipCard: some View {
        Toggle(isOn: $isSkipped.animation(.easeInOut(duration: 0.2))) {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.title3)
                    .foregroundStyle(WPStyles.secondaryText)
                Text("Skip alarm")
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
            }
        }
        .tint(WPStyles.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(WPStyles.surface))
    }

    // MARK: Derived

    private var dayTitle: String {
        plan.targetDay.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var contextEvent: ParsedEvent? {
        plan.targetEvent ?? plan.firstEventOfDay
    }

    private var isLateAlarm: Bool {
        if isSkipped { return false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: wakeDate)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        // Warning if alarm is in the afternoon
        if hour >= 12 { return true }

        // Warning if alarm is after the first event of the day
        if let event = contextEvent {
            let eventComponents = Calendar.current.dateComponents([.hour, .minute], from: event.startDate)
            let eventHour = eventComponents.hour ?? 0
            let eventMinute = eventComponents.minute ?? 0
            if hour > eventHour || (hour == eventHour && minute > eventMinute) {
                return true
            }
        }
        return false
    }

    // MARK: Actions

    private func attemptSave() {
        if isLateAlarm {
            showingLateAlarmAlert = true
        } else {
            save()
        }
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: wakeDate)
        let clock = ClockTime(hour: components.hour ?? 0, minute: components.minute ?? 0)

        // The time only becomes a "custom" override if the user picked one before
        // or changed it now; otherwise the day stays on the automatic schedule.
        let seedComponents = Calendar.current.dateComponents([.hour, .minute], from: seedWakeDate)
        let timeChanged = seedComponents.hour != components.hour || seedComponents.minute != components.minute
        let extrasChanged = extraAlarms != plan.extraAlarms
        // Only a calendar alarm can keep following its rule with the day's own extra
        // alarms; any other alarm becomes this day's custom alarm to carry them.
        let pinsTime = startedCustom || timeChanged || (extrasChanged && plan.reason != .event)
        let customWakeTime: ClockTime? = pinsTime ? clock : nil
        // A custom time keeps the extra alarms the day had; otherwise they're stored
        // only once the user has set them for this day.
        let dayExtraAlarms: ExtraAlarms? = (customWakeTime != nil || extrasChanged || initialOverride?.extraAlarms != nil)
            ? extraAlarms
            : nil

        // Automatic, not skipped and with the rule's extra alarms: nothing to override.
        let newOverride: DayAlarmOverride? = (customWakeTime == nil && !isSkipped && dayExtraAlarms == nil)
            ? nil
            : DayAlarmOverride(customWakeTime: customWakeTime, isSkipped: isSkipped, extraAlarms: dayExtraAlarms)

        // Skip the write (and refresh) when nothing actually changed.
        guard newOverride != initialOverride else {
            onClose()
            return
        }

        let targetDay = plan.targetDay
        Task { await appState.setDayOverride(newOverride, for: targetDay) }
        onClose()
    }

    private func reset() {
        let targetDay = plan.targetDay
        Task { await appState.setDayOverride(nil, for: targetDay) }
        onClose()
    }
}
