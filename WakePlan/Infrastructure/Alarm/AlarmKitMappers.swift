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
        let alert: AlarmPresentation.Alert

        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: localized(title)
            )
        } else {
            let stopButton = AlarmButton(
                text: localized("Stop"),
                textColor: .white,
                systemImageName: "stop.fill"
            )

            alert = AlarmPresentation.Alert(
                title: localized(title),
                stopButton: stopButton
            )
        }

        let presentation = AlarmPresentation(alert: alert)

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
            attributes: attributes
        )
    }

    private static func localized(_ text: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(text))
    }
}
#endif
