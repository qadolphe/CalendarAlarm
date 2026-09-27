import SwiftUI

struct EarlyOtterDetailsView: View {
    private let inputPlan: WakeUpPlan
    let alarmStatus: AlarmScheduleStatus?
    /// Optional so SwiftUI previews can render without a full app state.
    /// When present, a single-day "Edit Alarm" action is offered.
    let appState: AppState?

    @State private var isEditing = false

    init(plan: WakeUpPlan, alarmStatus: AlarmScheduleStatus?, appState: AppState? = nil) {
        self.inputPlan = plan
        self.alarmStatus = alarmStatus
        self.appState = appState
    }

    /// The most up-to-date plan for this day: re-derived from app state so an edit made
    /// in the pushed editor is reflected the moment we slide back, falling back to the
    /// plan captured when the sheet opened.
    private var plan: WakeUpPlan {
        guard let appState else { return inputPlan }
        return appState.dailyPlans.first(where: { $0.targetDay == inputPlan.targetDay }) ?? inputPlan
    }

    /// Only today and future days are editable, and never while fully disabled.
    private var isEditableDay: Bool {
        guard appState != nil, plan.reason != .systemDisabled else {
            return false
        }
        return plan.targetDay.date >= Calendar.current.startOfDay(for: Date())
    }

    private var selectedDayTitle: String {
        plan.targetDay.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var showsUnavailableDayState: Bool {
        switch plan.reason {
        case .disabled, .inactiveDay, .noSchedule, .systemDisabled, .manualSkip:
            return true
        case .event, .fallback, .authorizationMissing, .manualOverride:
            return false
        }
    }

    private var unavailableStateIcon: String {
        switch plan.reason {
        case .inactiveDay:
            return "pause.circle.fill"
        case .disabled, .systemDisabled:
            return "power.circle.fill"
        case .noSchedule:
            return "calendar.badge.exclamationmark"
        case .manualSkip:
            return "bell.slash.fill"
        case .event, .fallback, .authorizationMissing, .manualOverride:
            return "alarm.fill"
        }
    }

    private var unavailableStateTitle: String {
        switch plan.reason {
        case .inactiveDay:
            return "Calendar Alarms Disabled"
        case .disabled:
            return "Automatic Alarms Off"
        case .systemDisabled:
            return "EarlyOtter Disabled"
        case .noSchedule:
            return "Nothing Scheduled"
        case .manualSkip:
            return "Manually Disabled"
        case .event, .fallback, .authorizationMissing, .manualOverride:
            return "Wake Time"
        }
    }

    private var unavailableStateMessage: String {
        switch plan.reason {
        case .inactiveDay:
            return ""
        case .disabled:
            return "Automatic alarms are turned off. Re-enable Auto Alarms from the schedule settings to resume managed alarms."
        case .systemDisabled:
            return "EarlyOtter is fully disabled right now, so no managed alarms will be created until you turn it back on."
        case .noSchedule:
            return "No matching calendar event or fallback alarm was available for this day."
        case .manualSkip:
            return ""
        case .event, .fallback, .authorizationMissing, .manualOverride:
            return ""
        }
    }

    private var standaloneEvent: ParsedEvent? {
        guard plan.targetEvent == nil else {
            return nil
        }

        return plan.firstEventOfDay
    }

    var body: some View {
        ZStack {
            // Shared background so only the foreground content crossfades.
            Color.clear.withAppBackground()

            if isEditing, let appState {
                DayAlarmEditView(
                    appState: appState,
                    plan: plan,
                    onClose: closeEditor
                )
                .transition(.opacity)
            } else {
                detailScroll
                    .transition(.opacity)
            }
        }
        .presentationDetents([.fraction(0.6)])
        .presentationDragIndicator(.visible)
    }

    private var detailScroll: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selectedDayTitle)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(WPStyles.primaryText)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)

                    Group {
                        if showsUnavailableDayState {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: unavailableStateIcon)
                                        .foregroundStyle(plan.reason == .noSchedule ? WPStyles.eventTint : WPStyles.accent)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(unavailableStateTitle)
                                            .font(.headline)
                                            .foregroundStyle(WPStyles.primaryText)

                                        if !unavailableStateMessage.isEmpty {
                                            Text(unavailableStateMessage)
                                                .font(.subheadline)
                                                .foregroundStyle(WPStyles.secondaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }

                                    Spacer()
                                }

                                if let standaloneEvent {
                                    Divider()
                                    standaloneEventRow(standaloneEvent)
                                }
                            }
                            .padding(20)
                            .background(WPStyles.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        } else {
                            WakeUpTimetableView(plan: plan)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(WPStyles.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)

                    alarmStatusCard()

                    if !plan.matchedRuleNames.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(WPStyles.eventTint)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Multiple Rules Matched")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(WPStyles.primaryText)
                                Text("Matched \(plan.matchedRuleNames.joined(separator: " and ")). EarlyOtter automatically used the earliest required alarm.")
                                    .font(.subheadline)
                                    .foregroundStyle(WPStyles.secondaryText)
                            }
                        }
                        .padding(16)
                        .background(WPStyles.eventTint.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 20)
                    }

                    if isEditableDay {
                        editAlarmButton
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: plan)
    }

    private var editAlarmButton: some View {
        Button {
            // Crossfade the content to the editor.
            withAnimation(.easeInOut(duration: 0.28)) {
                isEditing = true
            }
        } label: {
            if plan.reason == .manualSkip {
                Label("Enable Alarm", systemImage: "bell.fill")
            } else if plan.reason == .inactiveDay || plan.reason == .noSchedule || plan.reason == .disabled {
                Label("Add Alarm", systemImage: "plus")
            } else {
                Label("Edit Alarm", systemImage: "pencil")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private func closeEditor() {
        withAnimation(.easeInOut(duration: 0.28)) {
            isEditing = false
        }
    }

    @ViewBuilder
    private func alarmStatusCard() -> some View {
        if let alarmStatus {
            switch alarmStatus {
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scheduling Error")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .textCase(.uppercase)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(16)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            case .needsPermission:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alarm Permission Needed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WPStyles.accent)
                    Text(AppConfiguration.alarmPermissionExplanation)
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.secondaryText)
                }
                .padding(16)
                .background(WPStyles.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            case .disabled, .notScheduled, .scheduled:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    private func standaloneEventRow(_ event: ParsedEvent) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(WPStyles.eventTint)
            Text(event.title)
                .font(.headline)
                .foregroundStyle(WPStyles.primaryText)
                .lineLimit(1)
            Spacer()
            Text(event.startDate, style: .time)
                .font(.title3.weight(.semibold))
                .foregroundStyle(WPStyles.primaryText)
        }
    }
}

#if DEBUG
struct EarlyOtterDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EarlyOtterDetailsView(plan: samplePlanWithEvent, alarmStatus: .scheduled(sampleRecord))
            EarlyOtterDetailsView(plan: sampleFallbackPlan, alarmStatus: .failed("The operation couldn’t be completed. Alarm ID: preview"))
        }
    }

    private static var sampleRecord: ScheduledAlarmRecord {
        ScheduledAlarmRecord(
            planID: samplePlanWithEvent.id,
            nativeAlarmID: "preview-record",
            scheduledWakeTime: samplePlanWithEvent.calculatedWakeTime,
            targetEventID: samplePlanWithEvent.targetEvent?.id,
            createdAt: samplePlanWithEvent.calculatedWakeTime,
            updatedAt: samplePlanWithEvent.calculatedWakeTime
        )
    }

    private static var samplePlanWithEvent: WakeUpPlan {
        let startDate = Date().addingTimeInterval(60 * 60 * 12)
        let event = ParsedEvent(
            id: "preview-event",
            calendarID: "primary",
            title: "Morning Standup",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(60 * 30),
            timeZoneIdentifier: TimeZone.current.identifier,
            isAllDay: false,
            status: .confirmed,
            availability: .busy,
            location: "Conference Room",
            notes: nil
        )

        return WakeUpPlan(
            id: "preview-event-plan",
            targetDay: TargetDay(date: startDate),
            targetEvent: event,
            calculatedWakeTime: startDate.addingTimeInterval(-(50 * 60)),
            eventStartTime: startDate,
            prepTime: Minutes(30),
            commuteTime: Minutes(20),
            alarmSettings: .default,
            isFallback: false,
            reason: .event,
            appliedRuleName: "Weekday Office",
            matchedRuleNames: ["Weekday Office", "Morning Meetings"]
        )
    }

    private static var sampleFallbackPlan: WakeUpPlan {
        let wakeTime = Date().addingTimeInterval(60 * 60 * 8)

        return WakeUpPlan(
            id: "preview-fallback-plan",
            targetDay: TargetDay(date: wakeTime),
            targetEvent: nil,
            calculatedWakeTime: wakeTime,
            eventStartTime: nil,
            prepTime: Minutes(0),
            commuteTime: Minutes(0),
            alarmSettings: .default,
            isFallback: true,
            reason: .fallback,
            appliedRuleName: nil,
            matchedRuleNames: []
        )
    }
}
#endif
