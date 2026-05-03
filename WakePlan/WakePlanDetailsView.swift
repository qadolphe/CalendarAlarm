import SwiftUI

// Placeholder definitions to ensure compilation
struct WakeUpPlan {
    enum Reason {
        case inactiveDay
        case disabled
        case fallback
        case authorizationMissing
        case manualOverride
        case event
        case systemDisabled
    }
    let calculatedWakeTime: Date
    let targetEvent: Event?
    let reason: Reason
    
    struct Event {
        let title: String
        let startDate: Date
    }
}

struct WakePlanDetailsView: View {
    let plan: WakeUpPlan

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Wake time
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wake Time")
                            .font(.headline)
                        Text(plan.calculatedWakeTime, style: .time)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Event details if present
                    if let event = plan.targetEvent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.orange)
                                Text("Target Event")
                                    .font(.headline)
                            }
                            Text(event.title)
                                .font(.body)
                                .lineLimit(2)
                            HStack {
                                Text("Starts:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(event.startDate, style: .date)
                                Text(event.startDate, style: .time)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "moon.zzz.fill")
                                    .foregroundStyle(.indigo)
                                Text("Plan Reason")
                                    .font(.headline)
                            }
                            Text(reasonDescription(plan))
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Notes / status
                    if let status = statusMessage(plan) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status")
                                .font(.headline)
                            Text(status)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(16)
            }
            .navigationTitle("Plan Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers
    private func reasonDescription(_ plan: WakeUpPlan) -> String {
        switch plan.reason {
        case .inactiveDay: return "Inactive day"
        case .disabled: return "Alarm disabled"
        case .fallback: return "Fallback schedule"
        case .authorizationMissing: return "Missing permissions"
        case .manualOverride: return "Manual override"
        case .event: return "Event-based"
        case .systemDisabled: return "System disabled"
        }
    }

    private func statusMessage(_ plan: WakeUpPlan) -> String? {
        // Basic placeholder that can be customized later
        if plan.targetEvent == nil {
            return "This plan is not linked to a calendar event."
        }
        return nil
    }
}

#if DEBUG
struct WakePlanDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEvent = WakeUpPlan.Event(title: "Morning Meeting", startDate: Date().addingTimeInterval(3600))
        let samplePlanWithEvent = WakeUpPlan(calculatedWakeTime: Date(), targetEvent: sampleEvent, reason: .event)
        let samplePlanWithoutEvent = WakeUpPlan(calculatedWakeTime: Date(), targetEvent: nil, reason: .manualOverride)
        
        Group {
            WakePlanDetailsView(plan: samplePlanWithEvent)
            WakePlanDetailsView(plan: samplePlanWithoutEvent)
        }
    }
}
#endif
