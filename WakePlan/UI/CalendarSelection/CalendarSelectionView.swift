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
                    Text("Calendars")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(WPStyles.primaryText)
                        .padding(.top, 20)

                    Text("Choose which calendars can contribute events to EarlyOtter's alarm rules.")
                        .font(.body)
                        .foregroundStyle(WPStyles.secondaryText)

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
                .foregroundStyle(WPStyles.primaryText)

            Text(AppConfiguration.calendarPermissionExplanation)
                .font(.body)
                .foregroundStyle(WPStyles.secondaryText)

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
                .foregroundStyle(WPStyles.tertiaryText)
            
            Text("No Calendars Found")
                .font(.headline)
                .foregroundStyle(WPStyles.primaryText)
            
            Text("Make sure EarlyOtter has permission to read your calendars.")
                .font(.subheadline)
                .foregroundStyle(WPStyles.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cardStyle()
    }

    private func calendarList(helperText: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Choose which calendars EarlyOtter should scan.")
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)

                Spacer()

                Button("Use All") {
                    Task { await appState.selectAllCalendars() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WPStyles.secondaryBlue)
                .disabled(allCalendarsSelected)
            }

            VStack(spacing: 0) {
                ForEach(appState.calendars) { calendar in
                    Button {
                        Task { await appState.toggleCalendarSelection(id: calendar.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: calendar.isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(calendar.isSelected ? WPStyles.primaryOrange : WPStyles.tertiaryText)
                                .font(.title3)

                            Text(calendar.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(WPStyles.primaryText)

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
                .foregroundStyle(WPStyles.secondaryText)
        }
        .cardStyle()
    }

    private var allCalendarsSelected: Bool {
        appState.preferences.selectedCalendarIDs.isEmpty || appState.calendars.allSatisfy(\.isSelected)
    }
}
