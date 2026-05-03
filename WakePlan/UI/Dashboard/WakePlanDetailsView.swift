import SwiftUI

struct WakePlanDetailsView: View {
    let plan: WakeUpPlan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.withAppBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Header: Rule Name
                        if let ruleName = plan.appliedRuleName {
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
                            .padding(.top, 24)
                        }
                        
                        // Main timeline card
                        VStack(alignment: .leading, spacing: 16) {
                            if let event = plan.targetEvent {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(WPStyles.primaryOrange)
                                    Text(event.title)
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.primaryText)
                                    Spacer()
                                    Text(event.startDate, style: .time)
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.primaryText)
                                }
                                
                                Divider().overlay(WPStyles.cardBorder)
                                
                                timelineRow(icon: "car.fill", label: "Commute", value: "\(plan.commuteTime.rawValue)m")
                                timelineRow(icon: "cup.and.saucer.fill", label: "Prep Time", value: "\(plan.prepTime.rawValue)m")
                                
                                Divider().overlay(WPStyles.cardBorder)
                                
                                HStack {
                                    Image(systemName: "alarm.fill")
                                        .foregroundStyle(WPStyles.primaryOrange)
                                    Text("Wake Time")
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.primaryText)
                                    Spacer()
                                    Text(plan.calculatedWakeTime, style: .time)
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.primaryText)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "moon.zzz.fill")
                                        .foregroundStyle(.indigo)
                                    Text("No early events")
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.primaryText)
                                    Spacer()
                                }
                                Divider().overlay(WPStyles.cardBorder)
                                
                                HStack {
                                    Image(systemName: "alarm.fill")
                                        .foregroundStyle(WPStyles.primaryOrange)
                                    Text("Wake Time")
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.primaryText)
                                    Spacer()
                                    Text(plan.calculatedWakeTime, style: .time)
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.primaryText)
                                }
                            }
                        }
                        .padding(20)
                        .background(WPStyles.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
                        .padding(.horizontal, 20)
                        
                        // Match Conflicts
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
            .navigationTitle("Plan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(WPStyles.primaryOrange)
                }
            }
        }
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
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
            Text("-\(value)")
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(WPStyles.primaryText)
        }
    }
}

#if DEBUG
struct WakePlanDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WakePlanDetailsView(plan: samplePlanWithEvent)
            WakePlanDetailsView(plan: sampleFallbackPlan)
        }
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
            isFallback: true,
            reason: .fallback,
            appliedRuleName: nil,
            matchedRuleNames: []
        )
    }
}
#endif
