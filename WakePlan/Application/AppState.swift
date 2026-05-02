import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var currentPlan: WakeUpPlan?
    var preferences: AlarmPreferences = .default
    var calendars: [CalendarSource] = []
    var permissions: PermissionSnapshot = .initial
    let usesFakeCalendarData: Bool

    var isLoading = false
    var errorMessage: String?

    private let preferencesStore: PreferencesStoring
    private let wakePlanService: WakePlanService
    private let permissionService: PermissionService
    private let alarmSyncService: AlarmSyncService

    init(
        preferencesStore: PreferencesStoring,
        wakePlanService: WakePlanService,
        permissionService: PermissionService,
        alarmSyncService: AlarmSyncService,
        usesFakeCalendarData: Bool = false
    ) {
        self.preferencesStore = preferencesStore
        self.wakePlanService = wakePlanService
        self.permissionService = permissionService
        self.alarmSyncService = alarmSyncService
        self.usesFakeCalendarData = usesFakeCalendarData
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            preferences = try preferencesStore.load()
            permissions = await permissionService.currentStatus()

            if permissions.calendar == .authorized {
                calendars = try await wakePlanService.calendars()
                currentPlan = try await alarmSyncService.recalculateAndSyncAlarm()
            } else {
                calendars = []
                currentPlan = nil
            }
        } catch {
            errorMessage = format(error)
        }
    }

    func updatePreferences(_ newPreferences: AlarmPreferences) async {
        errorMessage = nil

        do {
            preferences = newPreferences
            try preferencesStore.save(newPreferences)

            if permissions.calendar == .authorized {
                calendars = try await wakePlanService.calendars()
                currentPlan = try await alarmSyncService.recalculateAndSyncAlarm()
            }
        } catch {
            errorMessage = format(error)
        }
    }

    func refreshPlan() async {
        errorMessage = nil

        do {
            permissions = await permissionService.currentStatus()

            guard permissions.calendar == .authorized else {
                currentPlan = nil
                return
            }

            currentPlan = try await alarmSyncService.recalculateAndSyncAlarm()
        } catch {
            errorMessage = format(error)
        }
    }

    func requestCalendarAccess() async {
        errorMessage = nil

        do {
            _ = try await permissionService.requestCalendarAccess()
            await load()
        } catch {
            errorMessage = format(error)
        }
    }

    func requestAlarmAccess() async {
        errorMessage = nil

        do {
            let requestedState = try await permissionService.requestAlarmAccess()
            permissions = await permissionService.currentStatus()
            currentPlan = try await alarmSyncService.recalculateAndSyncAlarm()

            if requestedState == .notDetermined, permissions.alarm == .notDetermined {
                errorMessage = "Alarm access is still waiting for AlarmKit to present authorization. WakePlan will try again when it schedules the next alarm."
            }
        } catch {
            errorMessage = format(error)
        }
    }

    func toggleCalendarSelection(id: String) async {
        let allIDs = Set(calendars.map(\.id))
        guard !allIDs.isEmpty else { return }

        var nextPreferences = preferences

        if nextPreferences.selectedCalendarIDs.isEmpty {
            nextPreferences.selectedCalendarIDs = allIDs
        }

        if nextPreferences.selectedCalendarIDs.contains(id) {
            guard nextPreferences.selectedCalendarIDs.count > 1 else { return }
            nextPreferences.selectedCalendarIDs.remove(id)
        } else {
            nextPreferences.selectedCalendarIDs.insert(id)
        }

        if nextPreferences.selectedCalendarIDs == allIDs {
            nextPreferences.selectedCalendarIDs = []
        }

        await updatePreferences(nextPreferences)
    }

    func selectAllCalendars() async {
        var nextPreferences = preferences
        nextPreferences.selectedCalendarIDs = []
        await updatePreferences(nextPreferences)
    }

    private func format(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.localizedDescription) [\(nsError.domain) \(nsError.code)]"
    }
}
