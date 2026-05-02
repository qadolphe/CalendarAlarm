#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

@available(iOS 26.0, *)
struct WakePlanAlarmMetadata: AlarmMetadata {
    let planID: String
    let eventTitle: String?
}

@available(iOS 26.0, *)
enum AlarmKitMappers {
    static func configuration(from plan: WakeUpPlan) throws -> AlarmManager.AlarmConfiguration<WakePlanAlarmMetadata> {
        let title = AppConfiguration.alarmTitle(for: plan.targetEvent?.title)
        let stopButton = AlarmButton(
            text: localized("Stop"),
            textColor: .white,
            systemImageName: "stop.fill"
        )
        let snoozeButton = AlarmButton(
            text: localized("Snooze"),
            textColor: .white,
            systemImageName: "zzz"
        )
        let resumeButton = AlarmButton(
            text: localized("Resume"),
            textColor: .white,
            systemImageName: "play.fill"
        )

        let alert: AlarmPresentation.Alert

        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: localized(title),
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .countdown
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: localized(title),
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .countdown
            )
        }

        let presentation = AlarmPresentation(
            alert: alert,
            countdown: AlarmPresentation.Countdown(
                title: localized("Snoozing")
            ),
            paused: AlarmPresentation.Paused(
                title: localized("Snoozed"),
                resumeButton: resumeButton
            )
        )

        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: WakePlanAlarmMetadata(
                planID: plan.id.rawValue,
                eventTitle: plan.targetEvent?.title
            ),
            tintColor: .orange
        )

        return .alarm(
            schedule: .fixed(plan.calculatedWakeTime),
            attributes: attributes,
            sound: .default
        )
    }

    private static func localized(_ text: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(text))
    }
}
#endif
