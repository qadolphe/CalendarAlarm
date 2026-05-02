import SwiftUI

struct CalendarSelectionView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = CalendarSelectionViewModel(appState: appState)

        List {
            if appState.permissions.calendar != .authorized {
                Section {
                    Text(AppConfiguration.calendarPermissionExplanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Button("Use all calendars") {
                        Task {
                            await appState.selectAllCalendars()
                        }
                    }
                } footer: {
                    Text(viewModel.helperText)
                }

                Section("Calendars") {
                    ForEach(appState.calendars) { calendar in
                        Button {
                            Task {
                                await appState.toggleCalendarSelection(id: calendar.id)
                            }
                        } label: {
                            HStack {
                                Text(calendar.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: calendar.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(calendar.isSelected ? .accent : .secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Calendars")
    }
}

private extension ShapeStyle where Self == Color {
    static var accent: Color { .orange }
}
