import AlarmKit
import SwiftUI
import WidgetKit

/// iOS draws a snoozed AlarmKit alarm with the app's Live Activity view.
/// Without one it shows an empty Dynamic Island circle, so this mirrors Clock's snooze.
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<EarlyOtterAlarmMetadata>.self) { context in
            HStack {
                SnoozeTitle(attributes: context.attributes)
                Spacer()
                SnoozeCountdown(state: context.state)
                    .font(.system(size: 40, weight: .medium, design: .rounded))
            }
            .foregroundStyle(context.attributes.tintColor)
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SnoozeTitle(attributes: context.attributes)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SnoozeCountdown(state: context.state)
                        .font(.system(size: 34, weight: .medium, design: .rounded))
                        .foregroundStyle(context.attributes.tintColor)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                SnoozeCountdown(state: context.state)
                    .foregroundStyle(context.attributes.tintColor)
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(context.attributes.tintColor)
            }
            .keylineTint(context.attributes.tintColor)
        }
    }
}

private struct SnoozeTitle: View {
    let attributes: AlarmAttributes<EarlyOtterAlarmMetadata>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Snoozed")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(attributes.metadata?.eventTitle ?? AppConfiguration.genericAlarmTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct SnoozeCountdown: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        case .paused(let paused):
            Text(
                Duration.seconds(paused.totalCountdownDuration - paused.previouslyElapsedDuration),
                format: .time(pattern: .minuteSecond)
            )
            .monospacedDigit()
        default:
            EmptyView()
        }
    }
}
