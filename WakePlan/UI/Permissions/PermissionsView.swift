import SwiftUI

struct PermissionsView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = PermissionsViewModel(appState: appState)

        Form {
            if let errorMessage = appState.errorMessage {
                Section("Status") {
                    Text(errorMessage)
                        .font(.subheadline)
                }
            }

            Section("Calendar Access") {
                LabeledContent("Status", value: viewModel.calendarStatus)
                Text(AppConfiguration.calendarPermissionExplanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if appState.permissions.calendar != .authorized {
                    Button("Allow Calendar Access") {
                        Task {
                            await appState.requestCalendarAccess()
                        }
                    }
                }
            }

            Section("Alarm Access") {
                LabeledContent("Status", value: viewModel.alarmStatus)
                Text(AppConfiguration.alarmPermissionExplanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if appState.permissions.alarm != .authorized {
                    Button("Allow Alarm Access") {
                        Task {
                            await appState.requestAlarmAccess()
                        }
                    }
                }
            }

            Section {
                Button("Refresh Permission Status") {
                    Task {
                        await appState.load()
                    }
                }
            }
        }
        .navigationTitle("Permissions")
    }
}
