import XCTest
@testable import WakePlan

@MainActor
final class AppStateTests: XCTestCase {
    func testPrimaryDashboardPlanReturnsNoSchedulePlaceholderWhenNoFuturePlansExist() {
        let calendar = configuredCalendar()
        let now = makeDate(
            year: 2026,
            month: 5,
            day: 4,
            hour: 10,
            minute: 40,
            calendar: calendar
        )

        let plan = AppState.primaryDashboardPlan(
            from: [],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(plan.reason, .noSchedule)
        XCTAssertFalse(plan.isFallback)
        XCTAssertNil(plan.targetEvent)
        XCTAssertEqual(plan.targetDay, TargetDay.tomorrow(from: now, calendar: calendar))
        XCTAssertEqual(plan.calculatedWakeTime, TargetDay.tomorrow(from: now, calendar: calendar).date)
    }

    func testPrimaryDashboardPlanPrefersFirstFutureDisplayPlan() {
        let calendar = configuredCalendar()
        let now = makeDate(
            year: 2026,
            month: 5,
            day: 4,
            hour: 10,
            minute: 40,
            calendar: calendar
        )
        let expectedWakeTime = makeDate(
            year: 2026,
            month: 5,
            day: 5,
            hour: 8,
            minute: 30,
            calendar: calendar
        )
        let expectedPlan = WakeUpPlan(
            id: "future-plan",
            targetDay: TargetDay(date: expectedWakeTime, calendar: calendar),
            targetEvent: nil,
            calculatedWakeTime: expectedWakeTime,
            eventStartTime: nil,
            prepTime: Minutes(0),
            commuteTime: Minutes(0),
            alarmSettings: .default,
            isFallback: true,
            reason: .fallback,
            appliedRuleName: nil,
            matchedRuleNames: []
        )

        let plan = AppState.primaryDashboardPlan(
            from: [expectedPlan],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(plan, expectedPlan)
    }

    func testLoadPublishesPermissionSnapshotEvenWhenCalendarRefreshFails() async {
        let accountStore = StubAccountStore()
        let preferencesStore = StubPreferencesStore()
        let calendarReader = StubCalendarReader(state: .authorized)
        let alarmScheduler = StubAlarmScheduler(state: .authorized)
        let permissionService = PermissionService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler
        )
        let wakePlanService = WakePlanService(
            calendarProvider: CompositeCalendarProvider(providers: [
                StubCalendarProvider(error: StubCalendarProviderError.googleExpired)
            ]),
            preferencesStore: preferencesStore
        )
        let appState = AppState(
            accountStore: accountStore,
            accountService: AccountService(
                accountStore: accountStore,
                googleAuthenticator: StubGoogleAuthenticator()
            ),
            preferencesStore: preferencesStore,
            wakePlanService: wakePlanService,
            permissionService: permissionService,
            alarmSyncService: AlarmSyncService(
                alarmScheduler: alarmScheduler,
                alarmStore: StubScheduledAlarmStore()
            )
        )

        await appState.load()

        XCTAssertEqual(
            appState.permissions,
            PermissionSnapshot(calendar: .authorized, alarm: .authorized)
        )
        XCTAssertEqual(
            appState.errorMessage,
            StubCalendarProviderError.googleExpired.localizedDescription
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
        calendar: Calendar
    ) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )

        return calendar.date(from: components)!
    }
}

final class CompositeCalendarProviderTests: XCTestCase {
    func testCalendarsIgnoreFailingProviderWhenAnotherProviderSucceeds() async throws {
        let appleCalendar = CalendarSource(
            id: "apple-work",
            title: "Work",
            isSelected: true,
            accountID: AppleCalendarProvider.appleAccountID,
            provider: .apple
        )
        let provider = CompositeCalendarProvider(providers: [
            StubCalendarProvider(calendars: [appleCalendar]),
            StubCalendarProvider(error: StubCalendarProviderError.googleExpired)
        ])

        let calendars = try await provider.calendars()

        XCTAssertEqual(calendars, [appleCalendar])
    }

    func testEventsIgnoreFailingProviderWhenAnotherProviderSucceeds() async throws {
        let targetDay = TargetDay(date: Date().addingTimeInterval(86_400))
        let event = ParsedEvent(
            id: "apple-event",
            calendarID: "apple-work",
            sourceAccountID: AppleCalendarProvider.appleAccountID,
            provider: .apple,
            title: "Standup",
            startDate: targetDay.date.addingTimeInterval(3_600),
            endDate: targetDay.date.addingTimeInterval(5_400),
            timeZoneIdentifier: nil,
            isAllDay: false,
            status: .confirmed,
            availability: .busy,
            location: nil,
            notes: nil
        )
        let provider = CompositeCalendarProvider(providers: [
            StubCalendarProvider(events: [event]),
            StubCalendarProvider(error: StubCalendarProviderError.googleExpired)
        ])

        let events = try await provider.events(for: targetDay)

        XCTAssertEqual(events, [event])
    }

    func testCompositeProviderThrowsWhenEveryProviderFails() async {
        let provider = CompositeCalendarProvider(providers: [
            StubCalendarProvider(error: StubCalendarProviderError.googleExpired)
        ])

        do {
            _ = try await provider.calendars()
            XCTFail("Expected calendars() to throw")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                StubCalendarProviderError.googleExpired.localizedDescription
            )
        }
    }
}

final class AppleCalendarProviderTests: XCTestCase {
    func testAccountsIsEmptyWhenAppleCalendarWasNeverConnected() async throws {
        let provider = AppleCalendarProvider(
            calendarReader: EventKitCalendarReader(),
            accountStore: StubAccountStore()
        )

        let accounts = try await provider.accounts()

        XCTAssertTrue(accounts.isEmpty)
    }

    func testAccountsReturnsStoredAppleAccountWhenConnected() async throws {
        let storedAppleAccount = ConnectedCalendarAccount(
            id: AppleCalendarProvider.appleAccountID,
            provider: .apple,
            displayName: "Apple Calendar",
            isEnabled: true
        )
        let provider = AppleCalendarProvider(
            calendarReader: EventKitCalendarReader(),
            accountStore: StubAccountStore(accounts: [storedAppleAccount])
        )

        let accounts = try await provider.accounts()

        XCTAssertEqual(accounts, [storedAppleAccount])
    }
}

private enum StubCalendarProviderError: LocalizedError {
    case googleExpired

    var errorDescription: String? {
        switch self {
        case .googleExpired:
            return "Google Calendar access expired or was never granted. Reconnect your Google account."
        }
    }
}

private struct StubCalendarProvider: CalendarEventProviding {
    var accountsToReturn: [ConnectedCalendarAccount] = []
    var calendarsToReturn: [CalendarSource] = []
    var eventsToReturn: [ParsedEvent] = []
    var error: Error?

    init(
        accounts: [ConnectedCalendarAccount] = [],
        calendars: [CalendarSource] = [],
        events: [ParsedEvent] = [],
        error: Error? = nil
    ) {
        self.accountsToReturn = accounts
        self.calendarsToReturn = calendars
        self.eventsToReturn = events
        self.error = error
    }

    func accounts() async throws -> [ConnectedCalendarAccount] {
        accountsToReturn
    }

    func calendars() async throws -> [CalendarSource] {
        if let error {
            throw error
        }

        return calendarsToReturn
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        if let error {
            throw error
        }

        return eventsToReturn
    }
}

private final class StubCalendarReader: CalendarReading {
    let state: CalendarAuthorizationState

    init(state: CalendarAuthorizationState) {
        self.state = state
    }

    func authorizationState() -> CalendarAuthorizationState {
        state
    }

    func requestAuthorization() async throws -> CalendarAuthorizationState {
        state
    }
}

private final class StubAlarmScheduler: AlarmScheduling {
    let state: AlarmAuthorizationState

    init(state: AlarmAuthorizationState) {
        self.state = state
    }

    func authorizationState() async -> AlarmAuthorizationState {
        state
    }

    func requestAuthorization() async throws -> AlarmAuthorizationState {
        state
    }

    func schedule(plan: WakeUpPlan) async throws -> ScheduledAlarmRecord {
        ScheduledAlarmRecord(
            planID: plan.id,
            nativeAlarmID: "test-alarm",
            scheduledWakeTime: plan.calculatedWakeTime,
            targetEventID: plan.targetEvent?.id,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func cancel(nativeAlarmID: String) async throws {}
}

private final class StubAccountStore: AccountStoring {
    private var accounts: [ConnectedCalendarAccount]

    init(accounts: [ConnectedCalendarAccount] = []) {
        self.accounts = accounts
    }

    func load() throws -> [ConnectedCalendarAccount] {
        accounts
    }

    func save(_ accounts: [ConnectedCalendarAccount]) throws {
        self.accounts = accounts
    }
}

private final class StubPreferencesStore: PreferencesStoring {
    func load() throws -> AlarmPreferences {
        .default
    }

    func save(_ preferences: AlarmPreferences) throws {}
}

private final class StubScheduledAlarmStore: ScheduledAlarmStoring {
    func load() throws -> ScheduledAlarmRecord? {
        nil
    }

    func save(_ record: ScheduledAlarmRecord) throws {}

    func clear() throws {}
}

private struct StubGoogleAuthenticator: GoogleAccountAuthenticating {
    @MainActor
    func signIn() async throws -> GoogleAccountAuthResult {
        GoogleAccountAuthResult(
            accountID: "google-account",
            matchingAccountIDs: ["google-account"],
            displayName: "Test Google",
            email: "test@example.com"
        )
    }
}
