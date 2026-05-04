import XCTest
@testable import WakePlan

final class AlarmSyncServiceTests: XCTestCase {
    func testSchedulesAlarmWhenNoExistingAlarm() async throws {
        let plan = makePlan(startOffset: 3_600)
        let alarmStore = FakeScheduledAlarmStore()
        let alarmScheduler = FakeAlarmScheduler()

        let service = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: alarmStore
        )

        let status = try await service.sync(plan: plan)

        guard case .scheduled(let record) = status else {
            return XCTFail("Expected scheduled status")
        }

        XCTAssertEqual(alarmScheduler.scheduledPlans.count, 1)
        XCTAssertEqual(record.planID, plan.id)
        XCTAssertEqual(alarmStore.record?.planID, plan.id)
    }

    func testDoesNotRescheduleWhenPlanIDMatches() async throws {
        let plan = makePlan(startOffset: 3_600)
        let alarmStore = FakeScheduledAlarmStore()
        let alarmScheduler = FakeAlarmScheduler()

        alarmStore.record = ScheduledAlarmRecord(
            planID: plan.id,
            nativeAlarmID: "existing-alarm",
            scheduledWakeTime: .distantFuture,
            targetEventID: plan.targetEvent?.id,
            createdAt: Date(),
            updatedAt: Date()
        )

        let service = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: alarmStore
        )

        let status = try await service.sync(plan: plan)

        guard case .scheduled(let record) = status else {
            return XCTFail("Expected scheduled status")
        }

        XCTAssertEqual(record.planID, plan.id)
        XCTAssertTrue(alarmScheduler.scheduledPlans.isEmpty)
        XCTAssertTrue(alarmScheduler.canceledIDs.isEmpty)
    }

    func testCancelsExistingAlarmWhenPlanChanges() async throws {
        let plan = makePlan(startOffset: 7_200)
        let alarmStore = FakeScheduledAlarmStore()
        let alarmScheduler = FakeAlarmScheduler()
        alarmStore.record = ScheduledAlarmRecord(
            planID: "old-plan",
            nativeAlarmID: "old-native-id",
            scheduledWakeTime: .distantFuture,
            targetEventID: "old-event",
            createdAt: Date(),
            updatedAt: Date()
        )

        let service = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: alarmStore
        )

        let status = try await service.sync(plan: plan)

        guard case .scheduled = status else {
            return XCTFail("Expected scheduled status")
        }
        XCTAssertEqual(alarmScheduler.canceledIDs, ["old-native-id"])
        XCTAssertEqual(alarmScheduler.scheduledPlans.count, 1)
        XCTAssertEqual(alarmStore.clearCallCount, 1)
        XCTAssertNotNil(alarmStore.record)
    }

    func testExpiredStoredAlarmIsClearedWithoutCancelBeforeSchedulingReplacement() async throws {
        let plan = makeFallbackPlan(wakeTime: Date().addingTimeInterval(86_400))
        let alarmStore = FakeScheduledAlarmStore()
        let alarmScheduler = FakeAlarmScheduler()
        alarmScheduler.cancelError = NSError(domain: "AlarmKit", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "The operation couldn’t be completed."
        ])
        alarmStore.record = ScheduledAlarmRecord(
            planID: "expired-plan",
            nativeAlarmID: "expired-native-id",
            scheduledWakeTime: .distantPast,
            targetEventID: nil,
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
        let service = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: alarmStore
        )

        let status = try await service.sync(plan: plan)

        guard case .scheduled(let record) = status else {
            return XCTFail("Expected scheduled status")
        }

        XCTAssertEqual(record.planID, plan.id)
        XCTAssertTrue(alarmScheduler.canceledIDs.isEmpty)
        XCTAssertEqual(alarmStore.clearCallCount, 1)
        XCTAssertEqual(alarmScheduler.scheduledPlans.count, 1)
    }

    func testCancelFailureForFutureAlarmIncludesReplacementContext() async throws {
        let now = Date()
        let plan = makeFallbackPlan(wakeTime: now.addingTimeInterval(86_400))
        let alarmStore = FakeScheduledAlarmStore()
        let alarmScheduler = FakeAlarmScheduler()
        alarmScheduler.cancelError = NSError(domain: "AlarmKit", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "The operation couldn’t be completed."
        ])
        alarmStore.record = ScheduledAlarmRecord(
            planID: "future-plan",
            nativeAlarmID: "future-native-id",
            scheduledWakeTime: now.addingTimeInterval(3_600),
            targetEventID: nil,
            createdAt: now,
            updatedAt: now
        )
        let service = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: alarmStore
        )

        let status = try await service.sync(plan: plan)

        guard case .failed(let message) = status else {
            return XCTFail("Expected failed status")
        }

        XCTAssertTrue(message.contains("Couldn't replace previous alarm"))
        XCTAssertTrue(message.contains("future-native-id"))
        XCTAssertEqual(alarmScheduler.scheduledPlans.count, 0)
    }

    func testClearsExistingAlarmWhenPlanDisabled() async throws {
        var plan = makePlan(startOffset: 3_600)
        plan = WakeUpPlan(
            id: plan.id,
            targetDay: plan.targetDay,
            targetEvent: plan.targetEvent,
            calculatedWakeTime: plan.calculatedWakeTime,
            eventStartTime: plan.eventStartTime,
            prepTime: plan.prepTime,
            commuteTime: plan.commuteTime,
            alarmSettings: plan.alarmSettings,
            isFallback: plan.isFallback,
            reason: .disabled,
            appliedRuleName: nil,
            matchedRuleNames: []
        )
        let alarmStore = FakeScheduledAlarmStore()
        alarmStore.record = ScheduledAlarmRecord(
            planID: "managed-plan",
            nativeAlarmID: "managed-alarm",
            scheduledWakeTime: .distantFuture,
            targetEventID: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let alarmScheduler = FakeAlarmScheduler()

        let service = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: alarmStore
        )

        let status = try await service.sync(plan: plan)

        XCTAssertEqual(status, .disabled)
        XCTAssertEqual(alarmScheduler.canceledIDs, ["managed-alarm"])
        XCTAssertNil(alarmStore.record)
    }

    func testReturnsNeedsPermissionWhenAlarmPermissionDenied() async throws {
        let plan = makePlan(startOffset: 3_600)
        let alarmScheduler = FakeAlarmScheduler()
        alarmScheduler.state = .denied

        let service = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: FakeScheduledAlarmStore()
        )

        let status = try await service.sync(plan: plan)

        XCTAssertEqual(status, .needsPermission)
        XCTAssertTrue(alarmScheduler.scheduledPlans.isEmpty)
    }

    func testClearsExistingAlarmWhenPlanHasNoSchedule() async throws {
        var plan = makePlan(startOffset: 3_600)
        plan = WakeUpPlan(
            id: plan.id,
            targetDay: plan.targetDay,
            targetEvent: nil,
            calculatedWakeTime: plan.calculatedWakeTime,
            eventStartTime: nil,
            prepTime: plan.prepTime,
            commuteTime: plan.commuteTime,
            alarmSettings: plan.alarmSettings,
            isFallback: false,
            reason: .noSchedule,
            appliedRuleName: nil,
            matchedRuleNames: []
        )

        let alarmStore = FakeScheduledAlarmStore()
        alarmStore.record = ScheduledAlarmRecord(
            planID: "managed-plan",
            nativeAlarmID: "managed-alarm",
            scheduledWakeTime: .distantFuture,
            targetEventID: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let alarmScheduler = FakeAlarmScheduler()

        let service = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: alarmStore
        )

        let status = try await service.sync(plan: plan)

        XCTAssertEqual(status, .notScheduled)
        XCTAssertEqual(alarmScheduler.canceledIDs, ["managed-alarm"])
        XCTAssertNil(alarmStore.record)
    }

    func testDoesNotRequestAuthorizationWhenAlarmPermissionIsNotDetermined() async throws {
        let plan = makePlan(startOffset: 3_600)
        let alarmScheduler = FakeAlarmScheduler()
        alarmScheduler.state = .notDetermined
        alarmScheduler.requestAuthorizationResult = .authorized

        let service = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: FakeScheduledAlarmStore()
        )

        let status = try await service.sync(plan: plan)

        XCTAssertEqual(status, .needsPermission)
        XCTAssertEqual(alarmScheduler.requestAuthorizationCallCount, 0)
        XCTAssertTrue(alarmScheduler.scheduledPlans.isEmpty)
    }

#if DEBUG
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
            alarmScheduler: alarmScheduler,
            alarmStore: alarmStore
        )

        let status = try await service.scheduleTestAlarm(now: now, calendar: calendar)

        guard case .scheduled(let record) = status else {
            return XCTFail("Expected scheduled status")
        }

        XCTAssertEqual(record.scheduledWakeTime, makeDate(
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

    func testTestAlarmReturnsNeedsPermissionWhenAlarmAccessDenied() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let alarmScheduler = FakeAlarmScheduler()
        alarmScheduler.state = .denied

        let service = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: FakeScheduledAlarmStore()
        )

        let status = try await service.scheduleTestAlarm(now: now)

        XCTAssertEqual(status, .needsPermission)
        XCTAssertTrue(alarmScheduler.scheduledPlans.isEmpty)
    }
#endif

    private func makePlan(startOffset: TimeInterval) -> WakeUpPlan {
        let targetDay = TargetDay(date: Date(timeIntervalSince1970: 1_000_000))

        return WakePlanCalculator().calculate(
            events: [makeEvent(startOffset: startOffset)],
            preferences: .default,
            targetDay: targetDay
        )
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

    private func makeFallbackPlan(wakeTime: Date) -> WakeUpPlan {
        WakeUpPlan(
            id: WakePlanID(rawValue: "fallback-\(Int(wakeTime.timeIntervalSince1970))"),
            targetDay: TargetDay(date: wakeTime),
            targetEvent: nil,
            calculatedWakeTime: wakeTime,
            eventStartTime: nil,
            prepTime: Minutes(45),
            commuteTime: Minutes(20),
            alarmSettings: .default,
            isFallback: true,
            reason: .fallback,
            appliedRuleName: "Fallback",
            matchedRuleNames: []
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
        if let cancelError {
            throw cancelError
        }
    }

    var cancelError: Error?
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
