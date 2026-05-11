import SwiftUI

struct WakePlanDetailsView: View {
    let plan: WakeUpPlan
    let alarmStatus: AlarmScheduleStatus?
    @Environment(\.dismiss) private var dismiss

    private var displayedRuleName: String? {
        if let ruleName = plan.appliedRuleName {
            return ruleName
        }

        if plan.reason == .fallback {
            return "Fixed"
        }

        return nil
    }

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let ruleName = displayedRuleName {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Applied Rule")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(WPStyles.secondaryText)
                                .textCase(.uppercase)
                            Text(ruleName)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(WPStyles.primaryText)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32) // Add some top padding since we removed the navigation bar
                    } else {
                        Spacer().frame(height: 16)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        if let event = plan.targetEvent {
                            HStack(alignment: .center) {
                                Image(systemName: "alarm.fill")
                                    .foregroundStyle(WPStyles.primaryOrange)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Wake Time")
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.primaryText)
                                    
                                    HStack(spacing: 6) {
                                        Text(plan.alarmSettings.sound.displayName)
                                        Text("•")
                                        Text(plan.alarmSettings.snoozeEnabled ? "Snooze \(plan.alarmSettings.snoozeDuration.rawValue)m" : "No snooze")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(WPStyles.secondaryText)
                                }
                                
                                Spacer()
                                Text(plan.calculatedWakeTime, style: .time)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(WPStyles.primaryText)
                            }
                            
                            Divider().overlay(WPStyles.cardBorder)
                            
                            timelineRow(icon: "cup.and.saucer.fill", label: "Prep Time", value: "\(plan.prepTime.rawValue)m")
                            timelineRow(icon: "car.fill", label: "Commute", value: "\(plan.commuteTime.rawValue)m")
                            
                            Divider().overlay(WPStyles.cardBorder)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(WPStyles.secondaryBlue)
                                Text(event.title)
                                    .font(.headline)
                                    .foregroundStyle(WPStyles.primaryText)
                                    .lineLimit(1)
                                Spacer()
                                Text(event.startDate, style: .time)
                                    .font(.headline)
                                    .foregroundStyle(WPStyles.primaryText)
                            }
                        } else {
                            HStack(alignment: .center) {
                                Image(systemName: "alarm.fill")
                                    .foregroundStyle(WPStyles.primaryOrange)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Wake Time")
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.primaryText)
                                    
                                    HStack(spacing: 6) {
                                        Text(plan.alarmSettings.sound.displayName)
                                        Text("•")
                                        Text(plan.alarmSettings.snoozeEnabled ? "Snooze \(plan.alarmSettings.snoozeDuration.rawValue)m" : "No snooze")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(WPStyles.secondaryText)
                                }
                                
                                Spacer()
                                Text(plan.calculatedWakeTime, style: .time)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(WPStyles.primaryText)
                            }
                            
                            Divider().overlay(WPStyles.cardBorder)
                            
                            HStack {
                                Image(systemName: "moon.zzz.fill")
                                    .foregroundStyle(.indigo)
                                Text("No early events")
                                    .font(.headline)
                                    .foregroundStyle(WPStyles.primaryText)
                                Spacer()
                            }
                        }
                    }
                    .padding(20)
                    .background(WPStyles.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
                    .padding(.horizontal, 20)

                    alarmStatusCard()

                    if !plan.matchedRuleNames.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(WPStyles.secondaryBlue)
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
                        .background(WPStyles.secondaryBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
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
                        .foregroundStyle(WPStyles.primaryOrange)
                    Text(AppConfiguration.alarmPermissionExplanation)
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.secondaryText)
                }
                .padding(16)
                .background(WPStyles.primaryOrange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            case .disabled, .notScheduled, .scheduled:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    private func timelineRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(WPStyles.tertiaryText)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(WPStyles.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(WPStyles.primaryText)
        }
    }
}

#if DEBUG
struct WakePlanDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WakePlanDetailsView(plan: samplePlanWithEvent, alarmStatus: .scheduled(sampleRecord))
            WakePlanDetailsView(plan: sampleFallbackPlan, alarmStatus: .failed("The operation couldn’t be completed. Alarm ID: preview"))
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
