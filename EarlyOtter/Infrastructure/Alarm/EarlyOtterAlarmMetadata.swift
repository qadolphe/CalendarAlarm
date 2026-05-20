#if canImport(AlarmKit)
import AlarmKit
import Foundation

@available(iOS 26.0, *)
struct EarlyOtterAlarmMetadata: AlarmMetadata {
    let planID: String
    let eventTitle: String
}
#endif
