import Foundation
import XCTest
@testable import EarlyOtter

final class AlarmKitSchedulerTests: XCTestCase {
    func testAlarmStillAlertingLongAfterFiringIsStuck() {
        let firedAt = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertFalse(AlarmKitScheduler.isStuckAlerting(firedAt: firedAt, now: firedAt.addingTimeInterval(60)))
        XCTAssertTrue(AlarmKitScheduler.isStuckAlerting(firedAt: firedAt, now: firedAt.addingTimeInterval(6 * 60 * 60)))
    }
}
