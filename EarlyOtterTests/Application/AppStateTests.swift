import XCTest
@testable import EarlyOtter

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
        let earlyOtterService = EarlyOtterService(
            calendarProvider: CompositeCalendarProvider(providers: [
                StubCalendarProvider(error: StubCalendarProviderError.googleExpired)
            ]),
            preferencesStore: preferencesStore
        )
        let refreshService = EarlyOtterRefreshService(
            earlyOtterService: earlyOtterService,
            permissionService: permissionService,
            alarmSyncService: AlarmSyncService(
                alarmScheduler: alarmScheduler,
                alarmStore: StubScheduledAlarmStore()
            )
        )
        let appState = AppState(
            accountStore: accountStore,
            accountService: AccountService(
                accountStore: accountStore,
                googleAuthenticator: StubGoogleAuthenticator()
            ),
            preferencesStore: preferencesStore,
            permissionService: permissionService,
            alarmSyncService: AlarmSyncService(
                alarmScheduler: alarmScheduler,
                alarmStore: StubScheduledAlarmStore()
            ),
            refreshService: refreshService
        )

        await appState.load()

        XCTAssertEqual(appState.permissions.calendar, .authorized)
        XCTAssertEqual(appState.permissions.alarm, .authorized)
        XCTAssertEqual(
            appState.errorMessage,
            StubCalendarProviderError.googleExpired.localizedDescription
        )
    }

    func testRequestCalendarAccessOpensSettingsWhenPermissionWasPreviouslyDenied() async {
        let accountStore = StubAccountStore()
        let preferencesStore = StubPreferencesStore()
        let calendarReader = StubCalendarReader(state: .denied)
        let alarmScheduler = StubAlarmScheduler(state: .authorized)
        let permissionService = PermissionService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler
        )
        let earlyOtterService = EarlyOtterService(
            calendarProvider: CompositeCalendarProvider(providers: []),
            preferencesStore: preferencesStore
        )
        let refreshService = EarlyOtterRefreshService(
            earlyOtterService: earlyOtterService,
            permissionService: permissionService,
            alarmSyncService: AlarmSyncService(
                alarmScheduler: alarmScheduler,
                alarmStore: StubScheduledAlarmStore()
            )
        )
        var openedSettings = false
        let appState = AppState(
            accountStore: accountStore,
            accountService: AccountService(
                accountStore: accountStore,
                googleAuthenticator: StubGoogleAuthenticator()
            ),
            preferencesStore: preferencesStore,
            permissionService: permissionService,
            alarmSyncService: AlarmSyncService(
                alarmScheduler: alarmScheduler,
                alarmStore: StubScheduledAlarmStore()
            ),
            refreshService: refreshService,
            openAppSettings: {
                openedSettings = true
            }
        )

        await appState.requestCalendarAccess()

        XCTAssertFalse(openedSettings)
        XCTAssertEqual(calendarReader.requestAuthorizationCallCount, 0)
        XCTAssertEqual(
            appState.settingsAlertMessage,
            "Calendar access was previously denied. Enable it in Settings to connect Apple Calendar."
        )
    }

    func testRequestAlarmAccessOpensSettingsWhenPermissionWasPreviouslyDenied() async {
        let accountStore = StubAccountStore()
        let preferencesStore = StubPreferencesStore()
        let calendarReader = StubCalendarReader(state: .authorized)
        let alarmScheduler = StubAlarmScheduler(state: .denied)
        let permissionService = PermissionService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler
        )
        let earlyOtterService = EarlyOtterService(
            calendarProvider: CompositeCalendarProvider(providers: []),
            preferencesStore: preferencesStore
        )
        let refreshService = EarlyOtterRefreshService(
            earlyOtterService: earlyOtterService,
            permissionService: permissionService,
            alarmSyncService: AlarmSyncService(
                alarmScheduler: alarmScheduler,
                alarmStore: StubScheduledAlarmStore()
            )
        )
        var openedSettings = false
        let appState = AppState(
            accountStore: accountStore,
            accountService: AccountService(
                accountStore: accountStore,
                googleAuthenticator: StubGoogleAuthenticator()
            ),
            preferencesStore: preferencesStore,
            permissionService: permissionService,
            alarmSyncService: AlarmSyncService(
                alarmScheduler: alarmScheduler,
                alarmStore: StubScheduledAlarmStore()
            ),
            refreshService: refreshService,
            openAppSettings: {
                openedSettings = true
            }
        )

        await appState.requestAlarmAccess()

        XCTAssertFalse(openedSettings)
        XCTAssertEqual(alarmScheduler.requestAuthorizationCallCount, 0)
        XCTAssertEqual(
            appState.settingsAlertMessage,
            "Alarm access was previously denied. Enable it in Settings to schedule wake-up alarms."
        )
    }

    func testShouldShowCalendarAccessPromptWhenNoAccessibleCalendarsExist() {
        let appState = makeAppState(calendarPermission: .denied)

        XCTAssertTrue(appState.shouldShowCalendarAccessPrompt)
    }

    func testShouldNotShowCalendarAccessPromptWhenGoogleCalendarsAreAvailable() {
        let appState = makeAppState(calendarPermission: .denied)
        appState.calendars = [
            CalendarSource(
                id: "google:primary",
                title: "Primary",
                isSelected: true,
                accountID: "google-account",
                provider: .google
            )
        ]

        XCTAssertFalse(appState.shouldShowCalendarAccessPrompt)
    }

    func testUpdatePreferencesKeepsPreviousTomorrowPlanPreviewWhileRefreshIsInFlight() async throws {
        let preferencesStore = StubPreferencesStore(preferences: .default)
        let provider = SuspendingCalendarProvider()
        let calendarReader = StubCalendarReader(state: .authorized)
        let alarmScheduler = StubAlarmScheduler(state: .authorized)
        let permissionService = PermissionService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler
        )
        let earlyOtterService = EarlyOtterService(
            calendarProvider: provider,
            preferencesStore: preferencesStore
        )
        let alarmSyncService = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: StubScheduledAlarmStore()
        )
        let refreshService = EarlyOtterRefreshService(
            earlyOtterService: earlyOtterService,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService
        )
        let appState = AppState(
            accountStore: StubAccountStore(),
            accountService: AccountService(
                accountStore: StubAccountStore(),
                googleAuthenticator: StubGoogleAuthenticator()
            ),
            preferencesStore: preferencesStore,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService,
            refreshService: refreshService
        )

        await appState.load()

        let originalPlan = try XCTUnwrap(appState.tomorrowPlanPreview)
        XCTAssertEqual(originalPlan.reason, .noSchedule)

        var updatedPreferences = appState.preferences
        let tomorrowWeekday = Calendar.current.component(
            .weekday,
            from: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        )
        updatedPreferences.fallbackEnabledDays.insert(tomorrowWeekday)

        await provider.suspendNextEventsRequest()

        let updateTask = Task {
            await appState.updatePreferences(updatedPreferences)
        }

        await provider.waitUntilSuspended()

        XCTAssertEqual(appState.dashboardState, .loading)
        XCTAssertEqual(appState.tomorrowPlanPreview, originalPlan)

        await provider.resumeSuspendedRequest()
        await updateTask.value

        XCTAssertEqual(appState.tomorrowPlanPreview?.reason, .fallback)
    }

    func testRefreshOnAppOpenRunsEvenWhenDashboardIsLoading() async {
        let accountStore = StubAccountStore()
        let preferencesStore = StubPreferencesStore()
        let rangeProvider = RangeRecordingCalendarProvider()
        let calendarReader = StubCalendarReader(state: .authorized)
        let alarmScheduler = StubAlarmScheduler(state: .authorized)
        let permissionService = PermissionService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler
        )
        let alarmSyncService = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: StubScheduledAlarmStore()
        )
        let refreshService = EarlyOtterRefreshService(
            earlyOtterService: EarlyOtterService(
                calendarProvider: rangeProvider,
                preferencesStore: preferencesStore
            ),
            permissionService: permissionService,
            alarmSyncService: alarmSyncService
        )
        let appState = AppState(
            accountStore: accountStore,
            accountService: AccountService(
                accountStore: accountStore,
                googleAuthenticator: StubGoogleAuthenticator()
            ),
            preferencesStore: preferencesStore,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService,
            refreshService: refreshService
        )

        await appState.load()
        let initialRangeRequestCount = await rangeProvider.rangeRequestCount
        XCTAssertEqual(initialRangeRequestCount, 1)

        appState.dashboardState = .loading
        await appState.refreshOnAppOpen()

        let resumedRangeRequestCount = await rangeProvider.rangeRequestCount
        XCTAssertEqual(resumedRangeRequestCount, 2)
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

    private func makeAppState(
        calendarPermission: CalendarAuthorizationState,
        alarmPermission: AlarmAuthorizationState = .authorized
    ) -> AppState {
        let accountStore = StubAccountStore()
        let preferencesStore = StubPreferencesStore()
        let calendarReader = StubCalendarReader(state: calendarPermission)
        let alarmScheduler = StubAlarmScheduler(state: alarmPermission)
        let permissionService = PermissionService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler
        )
        let earlyOtterService = EarlyOtterService(
            calendarProvider: CompositeCalendarProvider(providers: []),
            preferencesStore: preferencesStore
        )
        let alarmSyncService = AlarmSyncService(
            alarmScheduler: alarmScheduler,
            alarmStore: StubScheduledAlarmStore()
        )
        let refreshService = EarlyOtterRefreshService(
            earlyOtterService: earlyOtterService,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService
        )
        let appState = AppState(
            accountStore: accountStore,
            accountService: AccountService(
                accountStore: accountStore,
                googleAuthenticator: StubGoogleAuthenticator()
            ),
            preferencesStore: preferencesStore,
            permissionService: permissionService,
            alarmSyncService: alarmSyncService,
            refreshService: refreshService
        )
        appState.permissions = PermissionSnapshot(
            calendar: calendarPermission,
            alarm: alarmPermission,
            notification: .notDetermined
        )
        return appState
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

final class EarlyOtterRefreshServiceTests: XCTestCase {
    func testRefreshAndSyncBatchesPlanningWindowEventFetches() async throws {
        let calendar = configuredCalendar()
        let now = makeDate(
            year: 2026,
            month: 5,
            day: 4,
            hour: 9,
            minute: 0,
            calendar: calendar
        )
        let rangeProvider = RangeRecordingCalendarProvider()
        let preferencesStore = StubPreferencesStore()
        let calendarReader = StubCalendarReader(state: .authorized)
        let alarmScheduler = StubAlarmScheduler(state: .authorized)
        let permissionService = PermissionService(
            calendarReader: calendarReader,
            alarmScheduler: alarmScheduler
        )
        let earlyOtterService = EarlyOtterService(
            calendarProvider: rangeProvider,
            preferencesStore: preferencesStore
        )
        let refreshService = EarlyOtterRefreshService(
            earlyOtterService: earlyOtterService,
            permissionService: permissionService,
            alarmSyncService: AlarmSyncService(
                alarmScheduler: alarmScheduler,
                alarmStore: StubScheduledAlarmStore()
            ),
            planningWindowCount: 4
        )

        _ = try await refreshService.refreshAndSync(
            reason: .manual,
            now: now,
            calendar: calendar
        )

        let rangeRequestCount = await rangeProvider.rangeRequestCount
        let dayRequestCount = await rangeProvider.dayRequestCount

        XCTAssertEqual(rangeRequestCount, 1)
        XCTAssertEqual(dayRequestCount, 0)
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
    private(set) var requestAuthorizationCallCount = 0

    init(state: CalendarAuthorizationState) {
        self.state = state
    }

    func authorizationState() -> CalendarAuthorizationState {
        state
    }

    func requestAuthorization() async throws -> CalendarAuthorizationState {
        requestAuthorizationCallCount += 1
        return state
    }
}

private actor RangeRecordingCalendarProvider: CalendarEventProviding {
    private(set) var dayRequestCount = 0
    private(set) var rangeRequestCount = 0

    func accounts() async throws -> [ConnectedCalendarAccount] {
        []
    }

    func calendars() async throws -> [CalendarSource] {
        []
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        dayRequestCount += 1
        return []
    }

    func events(in interval: DateInterval, calendar: Calendar) async throws -> [ParsedEvent] {
        _ = interval
        _ = calendar
        rangeRequestCount += 1
        return []
    }
}

private final class StubAlarmScheduler: AlarmScheduling {
    let state: AlarmAuthorizationState
    private(set) var requestAuthorizationCallCount = 0

    init(state: AlarmAuthorizationState) {
        self.state = state
    }

    func authorizationState() async -> AlarmAuthorizationState {
        state
    }

    func requestAuthorization() async throws -> AlarmAuthorizationState {
        requestAuthorizationCallCount += 1
        return state
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
    private var preferences: AlarmPreferences

    init(preferences: AlarmPreferences = .default) {
        self.preferences = preferences
    }

    func load() throws -> AlarmPreferences {
        preferences
    }

    func save(_ preferences: AlarmPreferences) throws {
        self.preferences = preferences
    }
}

private final class StubScheduledAlarmStore: ScheduledAlarmStoring {
    func load() throws -> [ScheduledAlarmRecord] { [] }

    func save(_ records: [ScheduledAlarmRecord]) throws {}

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

private actor SuspendingCalendarProvider: CalendarEventProviding {
    private var shouldSuspendNextEventsRequest = false
    private var hasSuspendedRequest = false
    private var suspensionObservedContinuation: CheckedContinuation<Void, Never>?
    private var resumeSuspendedRequestContinuation: CheckedContinuation<Void, Never>?

    func suspendNextEventsRequest() {
        shouldSuspendNextEventsRequest = true
        hasSuspendedRequest = false
    }

    func waitUntilSuspended() async {
        if hasSuspendedRequest {
            return
        }

        await withCheckedContinuation { continuation in
            suspensionObservedContinuation = continuation
        }
    }

    func resumeSuspendedRequest() {
        resumeSuspendedRequestContinuation?.resume()
        resumeSuspendedRequestContinuation = nil
    }

    func accounts() async throws -> [ConnectedCalendarAccount] {
        []
    }

    func calendars() async throws -> [CalendarSource] {
        []
    }

    func events(for targetDay: TargetDay) async throws -> [ParsedEvent] {
        _ = targetDay

        if shouldSuspendNextEventsRequest {
            shouldSuspendNextEventsRequest = false
            hasSuspendedRequest = true
            suspensionObservedContinuation?.resume()
            suspensionObservedContinuation = nil

            await withCheckedContinuation { continuation in
                resumeSuspendedRequestContinuation = continuation
            }
        }

        return []
    }
}
