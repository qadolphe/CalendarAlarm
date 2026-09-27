import SwiftUI

// MARK: - Schedule tab: calendar alarm days, then Clock-style alarms

struct ScheduleView: View {
    @Bindable var appState: AppState
    @State private var editor: AlarmEditorMode?
    @State private var isShowingCalendarInfo = false
    /// Alarms whose "skip after calendar alarms?" prompt was dismissed, as UUID strings.
    @AppStorage("dismissedCalendarSkipPrompts") private var dismissedSkipPrompts = ""

    var body: some View {
        List {
            Section {
                CalendarDaysRow(appState: appState)
                    .listRowBackground(WPStyles.surface)
            } header: {
                HStack(spacing: 6) {
                    sectionHeader("Calendar Alarms")
                    Button {
                        isShowingCalendarInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(WPStyles.secondaryText)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .padding(.vertical, -8)
                    .accessibilityLabel("About calendar alarms")
                    .popover(isPresented: $isShowingCalendarInfo) {
                        Text("Wakes you in time for your first event on these days.")
                            .font(.subheadline)
                            .foregroundStyle(WPStyles.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 240)
                            .padding()
                            .presentationBackground(WPStyles.surfaceRaised)
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }

            Section {
                ForEach(sortedAlarms) { alarm in
                    // Each alarm is its own card so a swipe moves a whole rounded card.
                    alarmRow(alarm)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(WPStyles.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            // Icon only; the explicit tint overrides the tab bar's white tint.
                            Button(role: .destructive) {
                                Task { await appState.deleteAlarm(id: alarm.id) }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(.red)
                            .accessibilityLabel("Delete")
                        }
                }
            } header: {
                HStack {
                    sectionHeader("Alarms")
                    Spacer()
                    Button {
                        editor = .add
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(WPStyles.accent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .padding(.vertical, -12)
                    .accessibilityLabel("Add Alarm")
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
        .scrollContentBackground(.hidden)
        .background(Color.clear.withAppBackground())
        // System controls (switches, the time wheel) follow the app's night palette.
        .environment(\.colorScheme, .dark)
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editor) { mode in
            NavigationStack {
                AlarmEditorView(appState: appState, mode: mode)
            }
            .environment(\.colorScheme, .dark)
        }
    }

    private var sortedAlarms: [StandardAlarm] {
        appState.preferences.standardAlarms.sorted { $0.time < $1.time }
    }

    // MARK: Alarm rows

    private func alarmRow(_ alarm: StandardAlarm) -> some View {
        let clock = TimetableFormat.clock(alarm.time.date(on: TargetDay(date: Date())))

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    editor = .edit(alarm)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(clock.value)
                                .font(.system(size: 46, weight: .medium, design: .rounded))
                                .monospacedDigit()
                            if let unit = clock.unit {
                                Text(unit)
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundStyle(WPStyles.primaryText)

                        Text(alarm.listSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(WPStyles.secondaryText)
                            .lineLimit(1)
                    }
                    .opacity(alarm.isEnabled ? 1 : 0.45)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Toggle("", isOn: enabledBinding(for: alarm))
                    .labelsHidden()
                    .tint(WPStyles.accent)
            }

            if showsSkipPrompt(for: alarm) {
                skipPrompt(for: alarm)
            }
        }
    }

    private func enabledBinding(for alarm: StandardAlarm) -> Binding<Bool> {
        Binding(
            get: { alarm.isEnabled },
            set: { isOn in
                var updated = alarm
                updated.isEnabled = isOn
                Task { await appState.saveAlarm(updated) }
            }
        )
    }

    // MARK: Skip prompt

    /// Offered once per alarm, when a calendar alarm this week already rings shortly before it.
    private func showsSkipPrompt(for alarm: StandardAlarm) -> Bool {
        guard alarm.isEnabled,
              alarm.calendarSkip == .never,
              !dismissedSkipPromptIDs.contains(alarm.id.uuidString) else {
            return false
        }

        let now = Date()
        return appState.dailyPlans.contains { plan in
            guard plan.reason == .event,
                  let ringDate = alarm.ringDate(on: plan.targetDay),
                  ringDate > now else {
                return false
            }
            return StandardAlarmPlanner().yields(
                ringDate,
                to: [plan.calculatedWakeTime],
                rule: .within(CalendarSkipRule.defaultWindow)
            )
        }
    }

    private func skipPrompt(for alarm: StandardAlarm) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .foregroundStyle(WPStyles.eventTint)
            Text("Skip after calendar alarms?")
                .font(.subheadline)
                .foregroundStyle(WPStyles.primaryText)
            Spacer(minLength: 4)
            Button("Skip") {
                var updated = alarm
                updated.calendarSkip = .within(CalendarSkipRule.defaultWindow)
                Task { await appState.saveAlarm(updated) }
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())
            Button {
                dismissSkipPrompt(for: alarm)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WPStyles.secondaryText)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss")
        }
        .buttonStyle(.plain)
        .padding(.leading, 12)
        .padding(.trailing, 2)
        .padding(.vertical, 4)
        .background(WPStyles.eventTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var dismissedSkipPromptIDs: Set<String> {
        Set(dismissedSkipPrompts.split(separator: ",").map(String.init))
    }

    private func dismissSkipPrompt(for alarm: StandardAlarm) {
        dismissedSkipPrompts = (dismissedSkipPromptIDs.union([alarm.id.uuidString])).sorted().joined(separator: ",")
    }

    // MARK: Small pieces

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(WPStyles.secondaryText)
            .textCase(.uppercase)
    }
}

// MARK: - Weekday circles

/// Seven day toggles in a row, as in the Clock app's alarm editor.
struct WeekdayCircles: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EarlyOtterUIConfiguration.sundayFirstWeekdays) { option in
                let isOn = selection.contains(option.weekday)

                Button {
                    if isOn {
                        selection.remove(option.weekday)
                    } else {
                        selection.insert(option.weekday)
                    }
                } label: {
                    Text(option.shortLabel.prefix(1))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isOn ? WPStyles.onAccent : WPStyles.secondaryText)
                        .frame(width: 40, height: 40)
                        .background {
                            if isOn {
                                Circle().fill(WPStyles.accent)
                            } else {
                                Circle().strokeBorder(WPStyles.surfaceOutline, lineWidth: 1.5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.fullLabel)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// The weekdays calendar alarms run on.
struct CalendarDaysRow: View {
    @Bindable var appState: AppState

    var body: some View {
        WeekdayCircles(selection: Binding(
            get: { appState.preferences.activeDays },
            set: { days in Task { await appState.mutatePreferences { $0.activeDays = days } } }
        ))
        .padding(.vertical, 4)
    }
}

// MARK: - Display text

extension StandardAlarm {
    /// "Wake up, Weekdays", like the Clock app's alarm list.
    var listSubtitle: String {
        let title = label.isEmpty ? "Alarm" : label
        guard isRepeating else { return title }
        return "\(title), \(repeatSummary)"
    }

    /// "Never", "Every day", "Weekdays", "Weekends", or short day names.
    var repeatSummary: String {
        switch repeatDays {
        case []: return "Never"
        case Set(1...7): return "Every day"
        case Set(2...6): return "Weekdays"
        case [1, 7]: return "Weekends"
        default:
            return EarlyOtterUIConfiguration.sundayFirstWeekdays
                .filter { repeatDays.contains($0.weekday) }
                .map { $0.shortLabel.capitalized }
                .joined(separator: " ")
        }
    }
}
