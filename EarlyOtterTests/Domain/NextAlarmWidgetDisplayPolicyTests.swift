import UIKit
import XCTest
@testable import EarlyOtter

final class NextAlarmWidgetDisplayPolicyTests: XCTestCase {
    func testEmptySnapshotHasNoLockScreenAlarm() {
        let now = Date()
        let snapshot = NextAlarmWidgetSnapshot.empty(
            detailText: "No upcoming alarms.",
            lastUpdatedAt: now
        )

        XCTAssertFalse(
            NextAlarmWidgetDisplayPolicy.hasLockScreenUpcomingAlarm(snapshot, now: now)
        )
    }

    func testAlarmWithin24HoursShowsOnLockScreen() {
        let now = Date()
        let snapshot = NextAlarmWidgetSnapshot.scheduled(
            nextAlarmDate: now.addingTimeInterval(23 * 60 * 60),
            lastUpdatedAt: now
        )

        XCTAssertTrue(
            NextAlarmWidgetDisplayPolicy.hasLockScreenUpcomingAlarm(snapshot, now: now)
        )
    }

    func testAlarmAt24HoursShowsOnLockScreen() {
        let now = Date()
        let snapshot = NextAlarmWidgetSnapshot.scheduled(
            nextAlarmDate: now.addingTimeInterval(24 * 60 * 60),
            lastUpdatedAt: now
        )

        XCTAssertTrue(
            NextAlarmWidgetDisplayPolicy.hasLockScreenUpcomingAlarm(snapshot, now: now)
        )
    }

    func testAlarmBeyond24HoursDoesNotShowOnLockScreen() {
        let now = Date()
        let snapshot = NextAlarmWidgetSnapshot.scheduled(
            nextAlarmDate: now.addingTimeInterval(24 * 60 * 60 + 1),
            lastUpdatedAt: now
        )

        XCTAssertFalse(
            NextAlarmWidgetDisplayPolicy.hasLockScreenUpcomingAlarm(snapshot, now: now)
        )
    }

    func testPastAlarmDoesNotShowOnLockScreen() {
        let now = Date()
        let snapshot = NextAlarmWidgetSnapshot.scheduled(
            nextAlarmDate: now.addingTimeInterval(-60),
            lastUpdatedAt: now
        )

        XCTAssertFalse(
            NextAlarmWidgetDisplayPolicy.hasLockScreenUpcomingAlarm(snapshot, now: now)
        )
    }

    func testTimelineRefreshesWhenLockScreenHorizonBegins() {
        let now = Date()
        let nextAlarmDate = now.addingTimeInterval(26 * 60 * 60)
        let snapshot = NextAlarmWidgetSnapshot.scheduled(
            nextAlarmDate: nextAlarmDate,
            lastUpdatedAt: now
        )

        let refreshDate = NextAlarmWidgetDisplayPolicy.nextTimelineDate(
            for: snapshot,
            from: now
        )

        XCTAssertEqual(
            refreshDate,
            now.addingTimeInterval(NextAlarmWidgetDisplayPolicy.defaultTimelineRefreshInterval)
        )
    }

    func testTimelineRefreshesAtHorizonStartWhenSoonerThanDefault() {
        let now = Date()
        let nextAlarmDate = now.addingTimeInterval(24 * 60 * 60 + 10 * 60)
        let snapshot = NextAlarmWidgetSnapshot.scheduled(
            nextAlarmDate: nextAlarmDate,
            lastUpdatedAt: now
        )

        let refreshDate = NextAlarmWidgetDisplayPolicy.nextTimelineDate(
            for: snapshot,
            from: now
        )

        XCTAssertEqual(refreshDate, nextAlarmDate.addingTimeInterval(-24 * 60 * 60))
    }

    func testEmptySymbolNameResolvesToRealSystemImage() {
        XCTAssertNotNil(
            UIImage(systemName: NextAlarmWidgetDisplayPolicy.emptySymbolName),
            "\(NextAlarmWidgetDisplayPolicy.emptySymbolName) is not a valid SF Symbol, so the widget renders a blank gap instead of an icon."
        )
    }
}
