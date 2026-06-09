import XCTest
@testable import EarlyOtter

final class WakeUpGreetingTests: XCTestCase {
    // MARK: - WakeWindow boundaries

    func testWakeWindowBoundaries() {
        XCTAssertEqual(WakeWindow(hour: 0, minute: 0), .predawn)
        XCTAssertEqual(WakeWindow(hour: 5, minute: 0), .predawn)
        XCTAssertEqual(WakeWindow(hour: 5, minute: 1), .earlyMorning)
        XCTAssertEqual(WakeWindow(hour: 8, minute: 0), .earlyMorning)
        XCTAssertEqual(WakeWindow(hour: 8, minute: 1), .midMorning)
        XCTAssertEqual(WakeWindow(hour: 10, minute: 0), .midMorning)
        XCTAssertEqual(WakeWindow(hour: 10, minute: 1), .lateMorning)
        XCTAssertEqual(WakeWindow(hour: 11, minute: 0), .lateMorning)
        XCTAssertEqual(WakeWindow(hour: 23, minute: 59), .lateMorning)
    }

    func testWakeWindowFromDateUsesProvidedCalendar() {
        let date = makeDate(hour: 6, minute: 30)
        XCTAssertEqual(WakeWindow(date: date, calendar: Self.fixedCalendar), .earlyMorning)
    }

    // MARK: - WakeUpMessages selection

    func testMessageSelectionIsDeterministicAndRotates() {
        let messages = WakeUpMessages("a", "b", "c")

        XCTAssertEqual(messages.line(seed: 0), "a")
        XCTAssertEqual(messages.line(seed: 1), "b")
        XCTAssertEqual(messages.line(seed: 2), "c")
        XCTAssertEqual(messages.line(seed: 3), "a")
    }

    func testMessageSelectionHandlesNegativeSeed() {
        let messages = WakeUpMessages("a", "b", "c")
        XCTAssertEqual(messages.line(seed: -1), "c")
    }

    func testSingleMessageAlwaysReturnsTheOnlyLine() {
        let messages = WakeUpMessages("only")
        XCTAssertEqual(messages.line(seed: 0), "only")
        XCTAssertEqual(messages.line(seed: 42), "only")
    }

    // MARK: - Greeting provider

    func testTitleSelectsWindowByWakeTime() {
        let provider = makeProvider()

        XCTAssertEqual(provider.title(eventTitle: nil, wakeTime: makeDate(hour: 4, minute: 0)), "predawn")
        XCTAssertEqual(provider.title(eventTitle: nil, wakeTime: makeDate(hour: 7, minute: 0)), "early")
        XCTAssertEqual(provider.title(eventTitle: nil, wakeTime: makeDate(hour: 9, minute: 0)), "mid")
        XCTAssertEqual(provider.title(eventTitle: nil, wakeTime: makeDate(hour: 11, minute: 0)), "late")
    }

    func testTitleAppendsEventTitleAsSuffix() {
        let provider = makeProvider()
        let title = provider.title(eventTitle: "Standup", wakeTime: makeDate(hour: 7, minute: 0))
        XCTAssertEqual(title, "early — Standup")
    }

    func testTitleIgnoresBlankEventTitle() {
        let provider = makeProvider()
        let title = provider.title(eventTitle: "   ", wakeTime: makeDate(hour: 7, minute: 0))
        XCTAssertEqual(title, "early")
    }

    func testTitleIsStableForSameDayAndRotatesAcrossDays() {
        let catalog = WakeUpMessageCatalog(
            predawn: WakeUpMessages("p1", "p2"),
            earlyMorning: WakeUpMessages("e1", "e2"),
            midMorning: WakeUpMessages("m1", "m2"),
            lateMorning: WakeUpMessages("l1", "l2")
        )
        let provider = WakeUpGreetingProvider(catalog: catalog, calendar: Self.fixedCalendar)

        let earlyOnDay = makeDate(year: 2026, month: 6, day: 1, hour: 7, minute: 0)
        let lateOnSameDay = makeDate(year: 2026, month: 6, day: 1, hour: 7, minute: 45)
        let nextDay = makeDate(year: 2026, month: 6, day: 2, hour: 7, minute: 0)

        // Same calendar day → identical line regardless of the exact minute.
        XCTAssertEqual(
            provider.title(eventTitle: nil, wakeTime: earlyOnDay),
            provider.title(eventTitle: nil, wakeTime: lateOnSameDay)
        )
        // Consecutive days → the two-line set flips to the next line.
        XCTAssertNotEqual(
            provider.title(eventTitle: nil, wakeTime: earlyOnDay),
            provider.title(eventTitle: nil, wakeTime: nextDay)
        )
    }

    // MARK: - Helpers

    private static let fixedCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Detroit")!
        return calendar
    }()

    private func makeProvider() -> WakeUpGreetingProvider {
        let catalog = WakeUpMessageCatalog(
            predawn: WakeUpMessages("predawn"),
            earlyMorning: WakeUpMessages("early"),
            midMorning: WakeUpMessages("mid"),
            lateMorning: WakeUpMessages("late")
        )
        return WakeUpGreetingProvider(catalog: catalog, calendar: Self.fixedCalendar)
    }

    private func makeDate(
        year: Int = 2026,
        month: Int = 6,
        day: Int = 1,
        hour: Int,
        minute: Int
    ) -> Date {
        let components = DateComponents(
            timeZone: Self.fixedCalendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )

        return Self.fixedCalendar.date(from: components)!
    }
}
