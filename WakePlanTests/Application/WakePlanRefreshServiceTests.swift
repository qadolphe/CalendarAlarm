import XCTest
@testable import WakePlan

final class WakePlanRefreshWidgetSnapshotTests: XCTestCase {
    func testRefreshAndSyncPublishesScheduledWidgetSnapshot() async throws {
        let calendar = configuredCalendar()
        let now = makeDate(
            year: 2026,
            month: 5,
            day: 15,
            hour: 18,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        let eventStart = makeDate(
            year: 2026,
            month: 5,
            day: 16,
            hour: 9,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        let provider = StubCalendarProvider(
            events: [
                makeEvent(
                    id: "event-1",
                    title: "Design Review",
                    startDate: eventStart,
                    calendarID: "work"
                )
            ]
        )
        let preferencesStore = InMemoryPreferencesStore(preferences: .default)
        let wakePlanService = WakePlanService(
            calendarProvider: provider,
            preferencesStore: preferencesStore
        )
        let alarmScheduler = FakeAlarmScheduler()
        let alarmStore = FakeScheduledAlarmStore()
        let alarmSyncService = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: alarmStore
        )
        let permissionService = PermissionService(
            calendarReader: StubCalendarReader(),
            alarmScheduler: alarmScheduler
        )
        let widgetSnapshotStore = InMemoryWidgetSnapshotStore()
        let service = WakePlanRefreshService(
            wakePlanService: wakePlanService,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService,
            widgetSnapshotStore: widgetSnapshotStore,
            planningWindowCount: 3
        )

        let outcome = try await service.refreshAndSync(
            reason: .manual,
            now: now,
            calendar: calendar
        )

        let widgetSnapshot = try XCTUnwrap(widgetSnapshotStore.snapshot)
        let scheduledRecord = try XCTUnwrap(outcome.snapshot.syncResult.records.first)

        XCTAssertEqual(widgetSnapshot.state, .scheduled)
        XCTAssertEqual(widgetSnapshot.nextAlarmDate, scheduledRecord.scheduledWakeTime)
        XCTAssertEqual(widgetSnapshot.eventTitle, "Design Review")
        XCTAssertEqual(widgetSnapshot.lastUpdatedAt, now)
    }

    func testRefreshAndSyncPublishesEmptyWidgetSnapshotWhenNoAlarmIsScheduled() async throws {
        let calendar = configuredCalendar()
        let now = makeDate(
            year: 2026,
            month: 5,
            day: 15,
            hour: 18,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        var preferences = AlarmPreferences.default
        preferences.isSystemEnabled = true
        preferences.schedule.isEnabled = true
        preferences.schedule.fallbackEnabledDays = []
        let provider = StubCalendarProvider(events: [])
        let preferencesStore = InMemoryPreferencesStore(preferences: preferences)
        let wakePlanService = WakePlanService(
            calendarProvider: provider,
            preferencesStore: preferencesStore
        )
        let alarmScheduler = FakeAlarmScheduler()
        let alarmSyncService = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: FakeScheduledAlarmStore()
        )
        let permissionService = PermissionService(
            calendarReader: StubCalendarReader(),
            alarmScheduler: alarmScheduler
        )
        let widgetSnapshotStore = InMemoryWidgetSnapshotStore()
        let service = WakePlanRefreshService(
            wakePlanService: wakePlanService,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService,
            widgetSnapshotStore: widgetSnapshotStore,
            planningWindowCount: 2
        )

        _ = try await service.refreshAndSync(
            reason: .manual,
            now: now,
            calendar: calendar
        )

        let widgetSnapshot = try XCTUnwrap(widgetSnapshotStore.snapshot)

        XCTAssertEqual(widgetSnapshot.state, .empty)
        XCTAssertNil(widgetSnapshot.nextAlarmDate)
        XCTAssertEqual(widgetSnapshot.detailText, "No upcoming alarms.")
    }

    func testRefreshAndSyncPublishesStaleSnapshotWhenRefreshFails() async throws {
        let calendar = configuredCalendar()
        let now = makeDate(
            year: 2026,
            month: 5,
            day: 15,
            hour: 18,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        let previousAlarmDate = now.addingTimeInterval(3_600)
        let widgetSnapshotStore = InMemoryWidgetSnapshotStore()
        widgetSnapshotStore.snapshot = .scheduled(
            nextAlarmDate: previousAlarmDate,
            eventTitle: "Existing Alarm",
            context: "9:00 AM",
            detailText: nil,
            lastUpdatedAt: now.addingTimeInterval(-600)
        )
        let wakePlanService = WakePlanService(
            calendarProvider: FailingCalendarProvider(),
            preferencesStore: InMemoryPreferencesStore(preferences: .default)
        )
        let alarmScheduler = FakeAlarmScheduler()
        let alarmSyncService = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: FakeScheduledAlarmStore()
        )
        let permissionService = PermissionService(
            calendarReader: StubCalendarReader(),
            alarmScheduler: alarmScheduler
        )
        let service = WakePlanRefreshService(
            wakePlanService: wakePlanService,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService,
            widgetSnapshotStore: widgetSnapshotStore
        )

        await XCTAssertThrowsErrorAsync(
            try await service.refreshAndSync(
                reason: .manual,
                now: now,
                calendar: calendar
            )
        )

        let widgetSnapshot = try XCTUnwrap(widgetSnapshotStore.snapshot)

        XCTAssertEqual(widgetSnapshot.state, .stale)
        XCTAssertEqual(widgetSnapshot.nextAlarmDate, previousAlarmDate)
        XCTAssertEqual(widgetSnapshot.eventTitle, "Existing Alarm")
        XCTAssertEqual(widgetSnapshot.detailText, TestFailure.expected.localizedDescription)
        XCTAssertEqual(widgetSnapshot.lastUpdatedAt, now)
    }

    private func configuredCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Detroit")!
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )!
    }

    private func makeEvent(
        id: String,
        title: String,
        startDate: Date,
        calendarID: String
    ) -> ParsedEvent {
        ParsedEvent(
            id: id,
            calendarID: calendarID,
            title: title,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3_600),
            timeZoneIdentifier: nil,
            isAllDay: false,
            status: .confirmed,
            availability: .busy,
            location: nil,
            notes: nil
        )
    }
}

private enum TestFailure: LocalizedError {
    case expected

    var errorDescription: String? {
        switch self {
        case .expected:
            return "Expected refresh failure"
        }
    }
}

private struct StubCalendarProvider: CalendarEventProviding {
    var events: [ParsedEvent]
    var calendarsResult: [CalendarSource] = [
        CalendarSource(id: "work", title: "Work", isSelected: true)
    ]

    func accounts() async throws -> [ConnectedCalendarAccount] {
        []
    }

    func calendars() async throws -> [CalendarSource] {
        calendarsResult
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
		let interval = targetDay.interval(calendar: .current)
        return events.filter { interval.contains($0.startDate) }
    }

    func events(in interval: DateInterval, calendar: Calendar) async throws -> [ParsedEvent] {
        events.filter { interval.contains($0.startDate) }
    }
}

private struct FailingCalendarProvider: CalendarEventProviding {
    func accounts() async throws -> [ConnectedCalendarAccount] {
        throw TestFailure.expected
    }

    func calendars() async throws -> [CalendarSource] {
        []
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        []
    }

    func events(in interval: DateInterval, calendar: Calendar) async throws -> [ParsedEvent] {
        []
    }
}

private final class InMemoryPreferencesStore: PreferencesStoring {
    private var preferences: AlarmPreferences

    init(preferences: AlarmPreferences) {
        self.preferences = preferences
    }

    func load() throws -> AlarmPreferences {
        preferences
    }

    func save(_ preferences: AlarmPreferences) throws {
        self.preferences = preferences
    }
}

private final class InMemoryWidgetSnapshotStore: NextAlarmWidgetSnapshotStoring {
    var snapshot: NextAlarmWidgetSnapshot?

    func load() throws -> NextAlarmWidgetSnapshot? {
        snapshot
    }

    func save(_ snapshot: NextAlarmWidgetSnapshot) throws {
        self.snapshot = snapshot
    }

    func clear() throws {
        snapshot = nil
    }
}

private final class StubCalendarReader: CalendarReading {
    func authorizationState() -> CalendarAuthorizationState {
        .authorized
    }

    func requestAuthorization() async throws -> CalendarAuthorizationState {
        .authorized
    }
}

private final class FakeAlarmScheduler: AlarmScheduling {
    var state: AlarmAuthorizationState = .authorized

    func authorizationState() async -> AlarmAuthorizationState {
        state
    }

    func requestAuthorization() async throws -> AlarmAuthorizationState {
        state
    }

    func schedule(plan: WakeUpPlan) async throws -> ScheduledAlarmRecord {
        ScheduledAlarmRecord(
            planID: plan.id,
            nativeAlarmID: "native-1",
            scheduledWakeTime: plan.calculatedWakeTime,
            targetEventID: plan.targetEvent?.id,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func cancel(nativeAlarmID: String) async throws {}
}

private final class FakeScheduledAlarmStore: ScheduledAlarmStoring {
    private var records: [ScheduledAlarmRecord] = []

    func load() throws -> [ScheduledAlarmRecord] {
        records
    }

    func save(_ records: [ScheduledAlarmRecord]) throws {
        self.records = records
    }

    func clear() throws {
        records = []
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
    }
}