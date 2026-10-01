import EventKit
import XCTest
@testable import EarlyOtter

/// Fills a simulator with the demo week shown in the App Store screenshots, in
/// one language: calendar events, rules, Clock-style alarms and a finished
/// onboarding. Skipped unless SCREENSHOT_SEED names a language, e.g.
///
///     xcrun simctl privacy <device> grant calendar com.quentinadolphe.wakeplan
///     TEST_RUNNER_SCREENSHOT_SEED=es xcodebuild test -scheme EarlyOtter \
///       -destination 'platform=iOS Simulator,id=<device>' \
///       -only-testing:EarlyOtterTests/ScreenshotSeedTests
///
/// Then launch the app with `-AppleLanguages "(es)"` and capture the screens
/// into app-store/source/screenshots/app/<lang>/.
final class ScreenshotSeedTests: XCTestCase {
    private static let marker = "earlyotter-screenshot-seed"

    func testSeedScreenshotDemo() async throws {
        guard let lang = ProcessInfo.processInfo.environment["SCREENSHOT_SEED"] else {
            throw XCTSkip("Set SCREENSHOT_SEED=<lang> to seed the screenshot demo.")
        }
        let copy = try XCTUnwrap(DemoCopy.all[lang], "No demo copy for \(lang)")

        try await seedEvents(copy)
        try seedPreferences(copy)
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    private func seedEvents(_ copy: DemoCopy) async throws {
        let store = EKEventStore()
        let granted = try await store.requestFullAccessToEvents()
        XCTAssertTrue(granted, "Grant calendar access with `xcrun simctl privacy` first.")
        let calendar = try XCTUnwrap(store.defaultCalendarForNewEvents)

        let today = Calendar.current.startOfDay(for: Date())
        let window = store.predicateForEvents(
            withStart: today.addingTimeInterval(-86_400),
            end: today.addingTimeInterval(15 * 86_400),
            calendars: [calendar]
        )
        for event in store.events(matching: window) where event.notes == Self.marker {
            try store.remove(event, span: .thisEvent, commit: false)
        }

        for (dayOffset, title, location, start, end) in copy.events {
            let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: today)!
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = title
            event.location = location
            event.notes = Self.marker
            event.startDate = Calendar.current.date(bySettingHour: start.hour, minute: start.minute, second: 0, of: day)!
            event.endDate = Calendar.current.date(bySettingHour: end.hour, minute: end.minute, second: 0, of: day)!
            try store.save(event, span: .thisEvent, commit: false)
        }
        try store.commit()
    }

    private func seedPreferences(_ copy: DemoCopy) throws {
        var preferences = AlarmPreferences.default
        preferences.alarmRules = copy.rules.map { name, keyword, prep, commute, symbol in
            AlarmRule(
                id: UUID(),
                name: name,
                isDefault: false,
                activeWeekdays: Set(1...7),
                selectedCalendarIDs: [],
                conditions: [.titleContains(keyword)],
                prepTime: Minutes(prep),
                commuteTime: Minutes(commute),
                alarmSettings: .default,
                symbol: symbol
            )
        } + [AlarmRule.makeDefault(prepTime: Minutes(45), commuteTime: Minutes(15))]
        preferences.filters.ignoreAllDayEvents = true
        preferences.schedule.activeDays = Set(2...6)
        preferences.schedule.alarms = [
            StandardAlarm(time: ClockTime(hour: 5, minute: 15), label: copy.alarms[0], isEnabled: false),
            StandardAlarm(time: ClockTime(hour: 6, minute: 30), repeatDays: [2, 4, 6], label: copy.alarms[1], calendarSkip: .within(CalendarSkipRule.defaultWindow)),
            StandardAlarm(time: ClockTime(hour: 7, minute: 45), repeatDays: Set(2...6), label: copy.alarms[2], calendarSkip: .within(CalendarSkipRule.defaultWindow)),
            StandardAlarm(time: ClockTime(hour: 9, minute: 30), repeatDays: [1, 7], label: copy.alarms[3]),
        ]
        try UserDefaultsPreferencesStore().save(preferences)
        try UserDefaultsAccountStore().save([
            ConnectedCalendarAccount(
                id: AppleCalendarProvider.appleAccountID,
                provider: .apple,
                displayName: "Apple Calendar",
                isEnabled: true
            )
        ])
    }
}

/// The demo's user content in each language. Rule keywords must appear in the
/// matching event titles so the right rule times each alarm.
private struct DemoCopy {
    typealias Event = (day: Int, title: String, location: String, start: ClockTime, end: ClockTime)
    typealias Rule = (name: String, keyword: String, prep: Int, commute: Int, symbol: RuleSymbol)

    let events: [Event]
    let rules: [Rule]
    /// Airport, gym, wake up, sleep in.
    let alarms: [String]

    private static func t(_ hour: Int, _ minute: Int = 0) -> ClockTime { ClockTime(hour: hour, minute: minute) }

    static let all: [String: DemoCopy] = [
        "en": DemoCopy(
            events: [
                (1, "Biology Class", "Science Hall 204", t(9), t(10, 15)),
                (1, "Study Group", "Library", t(12, 30), t(13, 30)),
                (1, "Chem Lab", "Science Hall 310", t(14, 30), t(16)),
                (2, "Work Shift", "Campus Café", t(8, 5), t(12)),
                (3, "Calculus Class", "Math Building 101", t(9), t(10)),
                (4, "Gym Session", "Rec Center", t(8, 55), t(10)),
                (5, "History Class", "Humanities 12", t(9), t(10)),
            ],
            rules: [
                ("Class", "class", 35, 30, .school),
                ("Flights", "flight", 90, 45, .flight),
                ("Gym", "gym", 10, 15, .gym),
                ("Work", "work", 40, 25, .work),
            ],
            alarms: ["Airport", "Gym", "Wake up", "Sleep in"]
        ),
        "es": DemoCopy(
            events: [
                (1, "Clase de Biología", "Edificio de Ciencias 204", t(9), t(10, 15)),
                (1, "Grupo de estudio", "Biblioteca", t(12, 30), t(13, 30)),
                (1, "Laboratorio de Química", "Edificio de Ciencias 310", t(14, 30), t(16)),
                (2, "Turno de trabajo", "Cafetería del campus", t(8, 5), t(12)),
                (3, "Clase de Cálculo", "Edificio de Matemáticas 101", t(9), t(10)),
                (4, "Sesión de gimnasio", "Centro deportivo", t(8, 55), t(10)),
                (5, "Clase de Historia", "Humanidades 12", t(9), t(10)),
            ],
            rules: [
                ("Clase", "clase", 35, 30, .school),
                ("Vuelos", "vuelo", 90, 45, .flight),
                ("Gimnasio", "gimnasio", 10, 15, .gym),
                ("Trabajo", "trabajo", 40, 25, .work),
            ],
            alarms: ["Aeropuerto", "Gimnasio", "Despertar", "Dormir de más"]
        ),
    ]
}
