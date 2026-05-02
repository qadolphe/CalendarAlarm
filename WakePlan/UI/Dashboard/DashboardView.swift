import SwiftUI

struct DashboardView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = DashboardViewModel(appState: appState)

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let permissionBanner = viewModel.permissionBanner {
                        banner(permissionBanner, tint: .amber)
                    }

                    if let noticeMessage = appState.noticeMessage {
                        banner(noticeMessage, tint: .green)
                    }

                    if let errorMessage = appState.errorMessage {
                        banner(errorMessage, tint: .red)
                    }

                    content(viewModel: viewModel)

                    VStack(alignment: .leading, spacing: 12) {
#if DEBUG
                        Button(AppConfiguration.testAlarmButtonTitle) {
                            Task {
                                await appState.scheduleTestAlarm()
                            }
                        }
                        .buttonStyle(.bordered)

                        Text(AppConfiguration.testAlarmDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
#endif

                        Button("Refresh") {
                            Task {
                                await appState.refreshPlan()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle(AppConfiguration.appName)
            .toolbar {
                NavigationLink("Settings") {
                    SettingsView(appState: appState)
                }
            }
            .task {
                await appState.loadIfNeeded()
            }
        }
    }

    private func content(viewModel: DashboardViewModel) -> some View {
        Group {
            switch appState.dashboardState {
            case .loading:
                ProgressView("Calculating wake-up plan...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .needsCalendarPermission:
                ContentUnavailableView(
                    "Calendar access needed",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Grant calendar access to calculate your first automated wake-up plan.")
                )
            case .error:
                ContentUnavailableView(
                    "Wake-up plan unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Refresh to try again.")
                )
            case .needsAlarmPermission(let viewState),
                 .ready(let viewState),
                 .emptyFallback(let viewState):
                planCard(for: viewState.plan, statusMessage: viewModel.statusMessage)
            }
        }
    }

    @ViewBuilder
    private func planCard(for plan: WakeUpPlan, statusMessage: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.calculatedWakeTime, style: .time)
                .font(.system(size: 56, weight: .bold, design: .rounded))

            if let event = plan.targetEvent {
                Text("For \(event.title)")
                    .font(.title3.weight(.semibold))

                Text("Starts \(event.startDate, style: .time)")
                    .foregroundStyle(.secondary)
            } else {
                Text("Fallback wake time")
                    .font(.title3.weight(.semibold))
                Text("Latest allowed wake-up time for tomorrow.")
                    .foregroundStyle(.secondary)
            }

                Text("Prep \(plan.prepTime.rawValue) min • Commute \(plan.commuteTime.rawValue) min")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func banner(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
    }
}

private extension Color {
    static let amber = Color(red: 0.82, green: 0.56, blue: 0.12)
}
