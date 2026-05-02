import SwiftUI

struct CalendarSelectionView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = CalendarSelectionViewModel(appState: appState)

        ZStack {
            Color.clear
                .withAppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Select Calendars")
                        .font(.largeTitle.weight(.bold))
                        .padding(.top, 20)

                    Text(viewModel.helperText)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    if appState.permissions.calendar != .authorized {
                        permissionCard
                    } else if appState.calendars.isEmpty {
                        emptyState
                    } else {
                        calendarList(helperText: viewModel.helperText)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Calendars")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar access needed")
                .font(.title3.weight(.semibold))

            Text(AppConfiguration.calendarPermissionExplanation)
                .font(.body)
                .foregroundStyle(.secondary)

            Button("Allow Calendar Access") {
                Task { await appState.requestCalendarAccess() }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .cardStyle()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No Calendars Found")
                .font(.headline)
            
            Text("Make sure WakePlan has permission to read your calendars.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cardStyle()
    }

    private func calendarList(helperText: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Choose which calendars WakePlan should scan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Use All") {
                    Task { await appState.selectAllCalendars() }
                }
                .font(.subheadline.weight(.semibold))
                .disabled(allCalendarsSelected)
            }

            VStack(spacing: 0) {
                ForEach(appState.calendars) { calendar in
                    Button {
                        Task { await appState.toggleCalendarSelection(id: calendar.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: calendar.isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(calendar.isSelected ? WPStyles.primaryOrange : .secondary)
                                .font(.title3)

                            Text(calendar.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    if calendar.id != appState.calendars.last?.id {
                        Divider()
                    }
                }
            }

            Text(helperText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var allCalendarsSelected: Bool {
        appState.preferences.selectedCalendarIDs.isEmpty || appState.calendars.allSatisfy(\.isSelected)
    }
}
