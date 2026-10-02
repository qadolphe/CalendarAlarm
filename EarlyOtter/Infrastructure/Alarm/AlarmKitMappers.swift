#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

@available(iOS 26.0, *)
enum AlarmKitMappers {
    static func configuration(from plan: WakeUpPlan) throws -> AlarmManager.AlarmConfiguration<EarlyOtterAlarmMetadata> {
        // Titled with the event it wakes you for, or a standard alarm's label.
        // An extra alarm also says how early it is.
        let baseTitle = plan.reason == .alarm
            ? plan.alarmTitle
            : normalizedEventTitle(from: plan) ?? AppConfiguration.genericAlarmTitle
        let title = plan.minutesEarly.map { "\(baseTitle) · \($0) min early" } ?? baseTitle
        let secondaryButton = snoozeButton(for: plan.alarmSettings)
        let countdownDuration = snoozeCountdownDuration(for: plan.alarmSettings)
        let alert: AlarmPresentation.Alert

        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: localized(title),
                secondaryButton: secondaryButton,
                secondaryButtonBehavior: secondaryButton == nil ? nil : .countdown
            )
        } else {
            let stopButton = AlarmButton(
                text: localized("Stop"),
                textColor: .white,
                systemImageName: "stop.fill"
            )

            alert = AlarmPresentation.Alert(
                title: localized(title),
                stopButton: stopButton,
                secondaryButton: secondaryButton,
                secondaryButtonBehavior: secondaryButton == nil ? nil : .countdown
            )
        }

        let presentation = AlarmPresentation(alert: alert)

        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: EarlyOtterAlarmMetadata(
                planID: plan.id.rawValue,
                eventTitle: title
            ),
            tintColor: .orange
        )

        return AlarmManager.AlarmConfiguration(
            countdownDuration: countdownDuration,
            schedule: .fixed(plan.calculatedWakeTime),
            attributes: attributes,
            sound: sound(for: plan.alarmSettings)
        )
    }

    private static func sound(for settings: RuleAlarmSettings) -> ActivityKit.AlertConfiguration.AlertSound {
        guard let resourceName = settings.sound.resourceName else {
            return .default
        }

        return .named(resourceName)
    }

    private static func snoozeButton(for settings: RuleAlarmSettings) -> AlarmButton? {
        guard settings.snoozeEnabled else { return nil }

        return AlarmButton(
            text: localized("Snooze"),
            textColor: .white,
            systemImageName: "zzz"
        )
    }

    private static func snoozeCountdownDuration(for settings: RuleAlarmSettings) -> Alarm.CountdownDuration? {
        guard settings.snoozeEnabled else { return nil }

        return Alarm.CountdownDuration(
            preAlert: nil,
            postAlert: TimeInterval(settings.snoozeDuration.rawValue * 60)
        )
    }

    private static func localized(_ text: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(text))
    }

    private static func normalizedEventTitle(from plan: WakeUpPlan) -> String? {
        guard let rawTitle = plan.targetEvent?.title else {
            return nil
        }

        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return nil
        }

        return title
    }
}
#endif
