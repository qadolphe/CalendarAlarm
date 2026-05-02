import SwiftUI

struct DashboardView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = DashboardViewModel(appState: appState)

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header(viewModel: viewModel)
                    content(viewModel: viewModel)
                    actionCard

                    if let permissionBanner = viewModel.permissionBanner {
                        banner(permissionBanner, tint: WPStyles.warningBanner)
                    }

                    if let noticeMessage = appState.noticeMessage {
                        banner(noticeMessage, tint: .green)
                    }

                    if let errorMessage = appState.errorMessage {
                        banner(errorMessage, tint: .red)
                    }

#if DEBUG
                    VStack(alignment: .leading, spacing: 12) {
                        Button(AppConfiguration.testAlarmButtonTitle) {
                            Task {
                                await appState.scheduleTestAlarm()
                            }
                        }
                        .buttonStyle(.bordered)

                        Text(AppConfiguration.testAlarmDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
#endif
                }
                .padding(24)
            }
            .withAppBackground()
            .navigationTitle(AppConfiguration.appName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(appState: appState)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
    }

    private func header(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Text("A gentle plan for tomorrow morning.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var actionCard: some View {
        VStack(spacing: 0) {
            Button {
                Task { await appState.refreshPlan() }
            } label: {
                actionLabel("Refresh Plan", systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)

            Divider().padding(.vertical, 14)

            NavigationLink {
                TimingSettingsView(appState: appState)
            } label: {
                actionLabel("Edit Timing", systemName: "clock")
            }
            .buttonStyle(.plain)

            Divider().padding(.vertical, 14)

            NavigationLink {
                RulesView(appState: appState)
            } label: {
                actionLabel("View Rules", systemName: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .cardStyle()
    }

    private func actionLabel(_ title: String, systemName: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemName)
                .foregroundStyle(WPStyles.primaryOrange)
                .font(.title3)
                .frame(width: 24)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.subheadline.weight(.semibold))
        }
        .contentShape(Rectangle())
    }

    private func content(viewModel: DashboardViewModel) -> some View {
        Group {
            switch appState.dashboardState {
            case .loading:
                ProgressView("Calculating wake-up plan...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .frame(minHeight: 220)
            case .needsCalendarPermission:
                messageCard(
                    title: "Calendar access needed",
                    message: "Connect your calendar to calculate tomorrow's alarm."
                )
            case .error:
                messageCard(
                    title: "Wake-up plan unavailable",
                    message: "Refresh to try again."
                )
            case .needsAlarmPermission(let viewState),
                 .ready(let viewState),
                 .emptyFallback(let viewState):
                planCard(for: viewState.plan, viewModel: viewModel)
            }
        }
    }

    private func messageCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.weight(.bold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    @ViewBuilder
    private func planCard(for plan: WakeUpPlan, viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.calculatedWakeTime, style: .time)
                        .font(WPStyles.timeDisplayFont)

                    if let eventSummary = viewModel.eventSummary {
                        Text(eventSummary)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                statusPill(viewModel.statusTitle)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let timingSummary = viewModel.timingSummary {
                    Text(timingSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let calendarSummary = viewModel.calendarSummary {
                    Text(calendarSummary)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let statusMessage = viewModel.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    private func statusPill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(WPStyles.pillBackground)
            )
            .foregroundStyle(WPStyles.pillText)
    }

    @ViewBuilder
    private func banner(_ text: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}
