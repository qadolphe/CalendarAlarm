import XCTest
@testable import WakePlan

final class AlarmSyncServiceTests: XCTestCase {
    func testSchedulesAlarmWhenNoExistingAlarm() async throws {
        let targetDay = TargetDay(date: Date(timeIntervalSince1970: 1_000_000))
        let preferencesStore = FakePreferencesStore()
        let alarmStore = FakeScheduledAlarmStore()
        let calendarReader = FakeCalendarReader(
            events: [makeEvent(startOffset: 3_600)]
        )
        let alarmScheduler = FakeAlarmScheduler()

        let service = AlarmSyncService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler,
            preferencesStore: preferencesStore,
            alarmStore: alarmStore
        )

        let plan = try await service.recalculateAndSyncAlarm(targetDay: targetDay)

        XCTAssertEqual(plan.reason, .event)
        XCTAssertEqual(alarmScheduler.scheduledPlans.count, 1)
        XCTAssertEqual(alarmStore.record?.planID, plan.id)
    }

    func testDoesNotRescheduleWhenPlanIDMatches() async throws {
        let targetDay = TargetDay(date: Date(timeIntervalSince1970: 1_000_000))
        let preferencesStore = FakePreferencesStore()
        let alarmStore = FakeScheduledAlarmStore()
        let calendarReader = FakeCalendarReader(
            events: [makeEvent(startOffset: 3_600)]
        )
        let alarmScheduler = FakeAlarmScheduler()

        let existingPlan = WakePlanCalculator().calculate(
            events: calendarReader.stubbedEvents,
            preferences: preferencesStore.preferences,
            targetDay: targetDay
        )
        alarmStore.record = ScheduledAlarmRecord(
            planID: existingPlan.id,
            nativeAlarmID: "existing-alarm",
            scheduledWakeTime: existingPlan.calculatedWakeTime,
            targetEventID: existingPlan.targetEvent?.id,
            createdAt: Date(),
            updatedAt: Date()
        )

        let service = AlarmSyncService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler,
            preferencesStore: preferencesStore,
            alarmStore: alarmStore
        )

        let plan = try await service.recalculateAndSyncAlarm(targetDay: targetDay)

        XCTAssertEqual(plan.id, existingPlan.id)
        XCTAssertTrue(alarmScheduler.scheduledPlans.isEmpty)
        XCTAssertTrue(alarmScheduler.canceledIDs.isEmpty)
    }

    func testCancelsExistingAlarmWhenPlanChanges() async throws {
        let targetDay = TargetDay(date: Date(timeIntervalSince1970: 1_000_000))
        let preferencesStore = FakePreferencesStore()
        let alarmStore = FakeScheduledAlarmStore()
        let calendarReader = FakeCalendarReader(
            events: [makeEvent(startOffset: 7_200)]
        )
        let alarmScheduler = FakeAlarmScheduler()
        alarmStore.record = ScheduledAlarmRecord(
            planID: "old-plan",
            nativeAlarmID: "old-native-id",
            scheduledWakeTime: Date(),
            targetEventID: "old-event",
            createdAt: Date(),
            updatedAt: Date()
        )

        let service = AlarmSyncService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler,
            preferencesStore: preferencesStore,
            alarmStore: alarmStore
        )

        _ = try await service.recalculateAndSyncAlarm(targetDay: targetDay)

        XCTAssertEqual(alarmScheduler.canceledIDs, ["old-native-id"])
        XCTAssertEqual(alarmScheduler.scheduledPlans.count, 1)
        XCTAssertEqual(alarmStore.clearCallCount, 1)
        XCTAssertNotNil(alarmStore.record)
    }

    func testDoesNotScheduleWhenPreferencesDisabled() async throws {
        let targetDay = TargetDay(date: Date(timeIntervalSince1970: 1_000_000))
        let preferencesStore = FakePreferencesStore()
        preferencesStore.preferences.isEnabled = false

        let service = AlarmSyncService(
            calendarReader: FakeCalendarReader(events: [makeEvent(startOffset: 3_600)]),
            alarmScheduler: FakeAlarmScheduler(),
            preferencesStore: preferencesStore,
            alarmStore: FakeScheduledAlarmStore()
        )

        let plan = try await service.recalculateAndSyncAlarm(targetDay: targetDay)

        XCTAssertEqual(plan.reason, .disabled)
    }

    func testReturnsAuthorizationMissingWhenAlarmPermissionDenied() async throws {
        let targetDay = TargetDay(date: Date(timeIntervalSince1970: 1_000_000))
        let alarmScheduler = FakeAlarmScheduler()
        alarmScheduler.state = .denied

        let service = AlarmSyncService(
            calendarReader: FakeCalendarReader(events: [makeEvent(startOffset: 3_600)]),
            alarmScheduler: alarmScheduler,
            preferencesStore: FakePreferencesStore(),
            alarmStore: FakeScheduledAlarmStore()
        )

        let plan = try await service.recalculateAndSyncAlarm(targetDay: targetDay)

        XCTAssertEqual(plan.reason, .authorizationMissing)
        XCTAssertTrue(alarmScheduler.scheduledPlans.isEmpty)
    }

    func testRequestsAuthorizationWhenAlarmPermissionIsNotDetermined() async throws {
        let targetDay = TargetDay(date: Date(timeIntervalSince1970: 1_000_000))
        let alarmScheduler = FakeAlarmScheduler()
        alarmScheduler.state = .notDetermined
        alarmScheduler.requestAuthorizationResult = .authorized

        let service = AlarmSyncService(
            calendarReader: FakeCalendarReader(events: [makeEvent(startOffset: 3_600)]),
            alarmScheduler: alarmScheduler,
            preferencesStore: FakePreferencesStore(),
            alarmStore: FakeScheduledAlarmStore()
        )

        let plan = try await service.recalculateAndSyncAlarm(targetDay: targetDay)

        XCTAssertEqual(plan.reason, .event)
        XCTAssertEqual(alarmScheduler.requestAuthorizationCallCount, 1)
        XCTAssertEqual(alarmScheduler.scheduledPlans.count, 1)
    }

    func testReturnsAuthorizationMissingWhenAuthorizationRequestDoesNotAuthorize() async throws {
        let targetDay = TargetDay(date: Date(timeIntervalSince1970: 1_000_000))
        let alarmScheduler = FakeAlarmScheduler()
        alarmScheduler.state = .notDetermined
        alarmScheduler.requestAuthorizationResult = .denied

        let service = AlarmSyncService(
            calendarReader: FakeCalendarReader(events: [makeEvent(startOffset: 3_600)]),
            alarmScheduler: alarmScheduler,
            preferencesStore: FakePreferencesStore(),
            alarmStore: FakeScheduledAlarmStore()
        )

        let plan = try await service.recalculateAndSyncAlarm(targetDay: targetDay)

        XCTAssertEqual(plan.reason, .authorizationMissing)
        XCTAssertEqual(alarmScheduler.requestAuthorizationCallCount, 1)
        XCTAssertTrue(alarmScheduler.scheduledPlans.isEmpty)
    }

    func testSchedulesTestAlarmWithoutReplacingManagedAlarm() async throws {
        let calendar = configuredCalendar()
        let now = makeDate(
            year: 2026,
            month: 5,
            day: 2,
            hour: 7,
            minute: 24,
            second: 42,
            calendar: calendar
        )
        let alarmStore = FakeScheduledAlarmStore()
        alarmStore.record = ScheduledAlarmRecord(
            planID: "managed-plan",
            nativeAlarmID: "managed-alarm",
            scheduledWakeTime: now.addingTimeInterval(86_400),
            targetEventID: "event-1",
            createdAt: now,
            updatedAt: now
        )
        let alarmScheduler = FakeAlarmScheduler()

        let service = AlarmSyncService(
            calendarReader: FakeCalendarReader(events: [makeEvent(startOffset: 3_600)]),
            alarmScheduler: alarmScheduler,
            preferencesStore: FakePreferencesStore(),
            alarmStore: alarmStore
        )

        let plan = try await service.scheduleTestAlarm(now: now, calendar: calendar)

        XCTAssertEqual(plan.reason, .manualOverride)
        XCTAssertEqual(plan.calculatedWakeTime, makeDate(
            year: 2026,
            month: 5,
            day: 2,
            hour: 7,
            minute: 25,
            second: 0,
            calendar: calendar
        ))
        XCTAssertEqual(alarmScheduler.scheduledPlans.count, 1)
        XCTAssertEqual(alarmStore.record?.planID, "managed-plan")
        XCTAssertTrue(alarmScheduler.canceledIDs.isEmpty)
    }

    func testTestAlarmReturnsAuthorizationMissingWhenAlarmAccessDenied() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let alarmScheduler = FakeAlarmScheduler()
        alarmScheduler.state = .denied

        let service = AlarmSyncService(
            calendarReader: FakeCalendarReader(events: [makeEvent(startOffset: 3_600)]),
            alarmScheduler: alarmScheduler,
            preferencesStore: FakePreferencesStore(),
            alarmStore: FakeScheduledAlarmStore()
        )

        let plan = try await service.scheduleTestAlarm(now: now)

        XCTAssertEqual(plan.reason, .authorizationMissing)
        XCTAssertTrue(alarmScheduler.scheduledPlans.isEmpty)
    }

    private func makeEvent(startOffset: TimeInterval) -> ParsedEvent {
        ParsedEvent(
            id: "event-\(startOffset)",
            calendarID: "work",
            title: "Standup",
            startDate: Date(timeIntervalSince1970: 1_000_000).addingTimeInterval(startOffset),
            endDate: Date(timeIntervalSince1970: 1_000_000).addingTimeInterval(startOffset + 1_800),
            timeZoneIdentifier: nil,
            isAllDay: false,
            status: .confirmed,
            availability: .busy,
            location: nil,
            notes: nil
        )
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
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )

        return calendar.date(from: components)!
    }
}

private final class FakeCalendarReader: CalendarReading {
    var calendarState: CalendarAuthorizationState = .authorized
    let stubbedEvents: [ParsedEvent]

    init(events: [ParsedEvent]) {
        self.stubbedEvents = events
    }

    func authorizationState() -> CalendarAuthorizationState {
        calendarState
    }

    func requestAuthorization() async throws -> CalendarAuthorizationState {
        calendarState
    }

    func calendars() async throws -> [CalendarSource] {
        [CalendarSource(id: "work", title: "Work", isSelected: true)]
    }

    func events(
        for targetDay: TargetDay,
        selectedCalendarIDs: Set<String>
    ) async throws -> [ParsedEvent] {
        stubbedEvents.filter { targetDay.interval.contains($0.startDate) }
    }
}

private final class FakeAlarmScheduler: AlarmScheduling {
    var state: AlarmAuthorizationState = .authorized
    var requestAuthorizationResult: AlarmAuthorizationState?
    var requestAuthorizationCallCount = 0
    var scheduledPlans: [WakeUpPlan] = []
    var canceledIDs: [String] = []

    func authorizationState() async -> AlarmAuthorizationState {
        state
    }

    func requestAuthorization() async throws -> AlarmAuthorizationState {
        requestAuthorizationCallCount += 1

        if let requestAuthorizationResult {
            state = requestAuthorizationResult
        }

        return state
    }

    func schedule(plan: WakeUpPlan) async throws -> ScheduledAlarmRecord {
        scheduledPlans.append(plan)
        return ScheduledAlarmRecord(
            planID: plan.id,
            nativeAlarmID: "native-\(scheduledPlans.count)",
            scheduledWakeTime: plan.calculatedWakeTime,
            targetEventID: plan.targetEvent?.id,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func cancel(nativeAlarmID: String) async throws {
        canceledIDs.append(nativeAlarmID)
    }
}

private final class FakePreferencesStore: PreferencesStoring {
    var preferences: AlarmPreferences = .default

    func load() throws -> AlarmPreferences {
        preferences
    }

    func save(_ preferences: AlarmPreferences) throws {
        self.preferences = preferences
    }
}

private final class FakeScheduledAlarmStore: ScheduledAlarmStoring {
    var record: ScheduledAlarmRecord?
    var clearCallCount = 0

    func load() throws -> ScheduledAlarmRecord? {
        record
    }

    func save(_ record: ScheduledAlarmRecord) throws {
        self.record = record
    }

    func clear() throws {
        clearCallCount += 1
        record = nil
    }
}
