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

                    if let errorMessage = appState.errorMessage {
                        banner(errorMessage, tint: .red)
                    }

                    Group {
                        if let plan = appState.currentPlan {
                            planCard(for: plan)
                        } else if appState.isLoading {
                            ProgressView("Calculating wake-up plan...")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ContentUnavailableView(
                                "No wake-up plan yet",
                                systemImage: "alarm",
                                description: Text("Grant permissions and refresh to create your first automated alarm.")
                            )
                        }
                    }

                    Button("Refresh") {
                        Task {
                            await appState.refreshPlan()
                        }
                    }
                    .buttonStyle(.borderedProminent)
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
                if appState.currentPlan == nil && !appState.isLoading {
                    await appState.load()
                }
            }
        }
    }

    @ViewBuilder
    private func planCard(for plan: WakeUpPlan) -> some View {
        let viewModel = DashboardViewModel(appState: appState)

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

            if let statusMessage = viewModel.statusMessage {
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
