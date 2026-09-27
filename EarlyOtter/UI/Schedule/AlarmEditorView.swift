import SwiftUI

enum AlarmEditorMode: Identifiable {
    case add
    case edit(StandardAlarm)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let alarm): return alarm.id.uuidString
        }
    }
}

/// Add or edit one standard alarm, modelled on the Clock app's alarm sheet.
struct AlarmEditorView: View {
    @Bindable var appState: AppState
    let mode: AlarmEditorMode
    @Environment(\.dismiss) private var dismiss

    @State private var alarm: StandardAlarm
    @State private var wakeDate: Date
    @State private var isPickingDate = false
    @State private var pickedDate = Date()

    init(appState: AppState, mode: AlarmEditorMode) {
        self.appState = appState
        self.mode = mode

        let alarm: StandardAlarm
        switch mode {
        case .add:
            alarm = StandardAlarm(time: Self.nextWholeHour())
        case .edit(let existing):
            alarm = existing
        }
        _alarm = State(initialValue: alarm)
        _wakeDate = State(initialValue: alarm.time.date(on: TargetDay(date: Date())))
    }

    var body: some View {
        List {
            Section {
                DatePicker("Time", selection: $wakeDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Text("Repeat")
                        Spacer()
                        Text(repeatLabel)
                            .foregroundStyle(WPStyles.secondaryText)
                        Button {
                            pickedDate = (alarm.chosenDay ?? TargetDay(date: Date())).date
                            isPickingDate = true
                        } label: {
                            Image(systemName: "calendar")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(alarm.chosenDay == nil ? WPStyles.secondaryText : WPStyles.accent)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Pick a date")
                    }

                    WeekdayCircles(selection: repeatDaysBinding)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(WPStyles.surface)

            Section {
                LabeledContent("Label") {
                    TextField("Alarm", text: $alarm.label)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(WPStyles.secondaryText)
                }

                NavigationLink {
                    AlarmSoundPickerView(selection: $alarm.settings.sound)
                } label: {
                    LabeledContent("Sound", value: alarm.settings.sound.displayName)
                }

                Toggle("Snooze", isOn: $alarm.settings.snoozeEnabled)
                    .tint(WPStyles.accent)

                if alarm.settings.snoozeEnabled {
                    Picker("Snooze Duration", selection: $alarm.settings.snoozeDuration) {
                        ForEach(snoozeOptions, id: \.self) { option in
                            Text("\(option.rawValue) min").tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(WPStyles.accent)
                }
            }
            .listRowBackground(WPStyles.surface)

            Section {
                Toggle(isOn: skipsBinding) {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .foregroundStyle(WPStyles.eventTint)
                        Text("Skip after calendar alarm")
                    }
                }
                .tint(WPStyles.accent)

                if let window = alarm.calendarSkip.window {
                    SkipWindowSlider(
                        window: Binding(get: { window }, set: { alarm.calendarSkip = .within($0) }),
                        alarmDate: wakeDate
                    )
                    .padding(.vertical, 6)
                }
            }
            .listRowBackground(WPStyles.surface)

            if case .edit = mode {
                Section {
                    Button("Delete Alarm", role: .destructive) {
                        Task { await appState.deleteAlarm(id: alarm.id) }
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.red.opacity(0.14))
            }
        }
        // Tight like the Clock app: the wheel sits right under the bar, sections close together.
        .listSectionSpacing(16)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Color.clear.withAppBackground())
        .navigationTitle(mode.isAdd ? "Add Alarm" : "Edit Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) { save() }
                    .tint(WPStyles.accent)
            }
        }
        .sheet(isPresented: $isPickingDate) {
            datePickerSheet
        }
    }

    // MARK: Repeat

    private var repeatDaysBinding: Binding<Set<Int>> {
        Binding(
            get: { alarm.repeatDays },
            set: { days in
                alarm.repeatDays = days
                if !days.isEmpty { alarm.chosenDay = nil }
            }
        )
    }

    /// "Weekdays", or for a one-time alarm the day it will ring: "Today", "Tomorrow", "Sat, Feb 18".
    private var repeatLabel: String {
        guard !alarm.isRepeating else { return alarm.repeatSummary }

        var draft = alarm
        draft.time = clockTime(from: wakeDate)
        guard let day = draft.armed().oneTimeDay?.date else { return "Never" }

        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Date",
                selection: $pickedDate,
                in: Calendar.current.startOfDay(for: Date())...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(WPStyles.accent)
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.clear.withAppBackground())
            .navigationTitle("Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { isPickingDate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        alarm.repeatDays = []
                        alarm.chosenDay = TargetDay(date: pickedDate)
                        isPickingDate = false
                    }
                    .tint(WPStyles.accent)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .presentationDetents([.height(500)])
    }

    private var snoozeOptions: [Minutes] {
        Set([5, 9, 10, 15, 20, 30].map(Minutes.init) + [alarm.settings.snoozeDuration])
            .sorted()
    }

    private var skipsBinding: Binding<Bool> {
        Binding(
            get: { alarm.calendarSkip != .never },
            set: { alarm.calendarSkip = $0 ? .within(CalendarSkipRule.defaultWindow) : .never }
        )
    }

    private func save() {
        var saved = alarm
        saved.time = clockTime(from: wakeDate)
        saved.label = saved.label.trimmingCharacters(in: .whitespacesAndNewlines)
        // Saving an alarm turns it on, as in the Clock app.
        saved.isEnabled = true
        Task { await appState.saveAlarm(saved) }
        dismiss()
    }

    private func clockTime(from date: Date) -> ClockTime {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    private static func nextWholeHour(now: Date = Date(), calendar: Calendar = .current) -> ClockTime {
        let hour = calendar.component(.hour, from: now)
        return ClockTime(hour: (hour + 1) % 24, minute: 0)
    }
}

private extension AlarmEditorMode {
    var isAdd: Bool {
        if case .add = self { return true }
        return false
    }
}

/// The skip window drawn to scale: drag the handle to choose how long before the
/// alarm a calendar alarm counts, from 1 to 6 hours.
private struct SkipWindowSlider: View {
    @Binding var window: Minutes
    let alarmDate: Date

    private let span = 6.0
    private let handleSize: CGFloat = 26

    private var hours: Double {
        Double(window.rawValue) / 60
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Within")
                    .foregroundStyle(WPStyles.primaryText)
                Spacer()
                Text(hoursText)
                    .foregroundStyle(WPStyles.secondaryText)
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let startX = width * (1 - hours / span)
                let labelWidth: CGFloat = 76

                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(WPStyles.surfaceRaised)
                        .frame(width: width, height: 6)
                        .offset(y: (handleSize - 6) / 2)
                    Capsule()
                        .fill(WPStyles.eventTint.opacity(0.6))
                        .frame(width: width - startX, height: 6)
                        .offset(x: startX, y: (handleSize - 6) / 2)
                    Circle()
                        .fill(WPStyles.accent)
                        .frame(width: 12, height: 12)
                        .offset(x: width - 12, y: (handleSize - 12) / 2)
                    Circle()
                        .fill(Color.white)
                        .frame(width: handleSize, height: handleSize)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .offset(x: min(max(startX - handleSize / 2, 0), width - handleSize))

                    // The window's start rides under the handle; the alarm time stays at the end.
                    Text(windowStart, format: .dateTime.hour().minute())
                        .foregroundStyle(WPStyles.eventTint)
                        .frame(width: labelWidth)
                        .offset(
                            x: min(max(startX - labelWidth / 2, 0), width - labelWidth * 2),
                            y: handleSize + 8
                        )
                    Text(alarmDate, format: .dateTime.hour().minute())
                        .foregroundStyle(WPStyles.accent)
                        .frame(width: labelWidth, alignment: .trailing)
                        .offset(x: width - labelWidth, y: handleSize + 8)
                }
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: width, height: handleSize, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        let dragged = (1 - value.location.x / width) * span * 60
                        window = CalendarSkipRule.windowOptions.min {
                            abs(Double($0.rawValue) - dragged) < abs(Double($1.rawValue) - dragged)
                        } ?? window
                    }
                )
            }
            .frame(height: handleSize + 24)
        }
        .sensoryFeedback(.selection, trigger: window)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Skip window")
        .accessibilityValue(hoursText)
        .accessibilityAdjustableAction { direction in
            let options = CalendarSkipRule.windowOptions
            guard let index = options.firstIndex(of: window) else { return }
            switch direction {
            case .increment: window = options[min(index + 1, options.count - 1)]
            case .decrement: window = options[max(index - 1, 0)]
            @unknown default: break
            }
        }
    }

    private var hoursText: String {
        hours == 1 ? "1 hour" : "\(Int(hours)) hours"
    }

    private var windowStart: Date {
        alarmDate.addingTimeInterval(-TimeInterval(window.rawValue * 60))
    }
}
