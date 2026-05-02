import SwiftUI

struct DashboardView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = DashboardViewModel(appState: appState)

        ZStack {
            Color.clear.withAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    topBar

                    if !appState.preferences.isSystemEnabled {
                        systemDisabledBanner
                    }

                    VStack(alignment: .leading, spacing: 24) {
                        if let permissionBanner = viewModel.permissionBanner {
                            banner(permissionBanner, tint: .orange, icon: "bell.badge.fill")
                        }

                        if let noticeMessage = appState.noticeMessage {
                            banner(noticeMessage, tint: .green, icon: "checkmark.circle.fill")
                        }

                        if let errorMessage = appState.errorMessage {
                            banner(errorMessage, tint: .red, icon: "exclamationmark.triangle.fill")
                        }

                        content(viewModel: viewModel)

                        quickActionRow
                    }
                    .opacity(appState.preferences.isSystemEnabled ? 1 : 0.4)
                    .disabled(!appState.preferences.isSystemEnabled)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func content(viewModel: DashboardViewModel) -> some View {
        switch appState.dashboardState {
        case .loading:
            VStack(alignment: .leading, spacing: 16) {
                Text("Next Alarm")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)

                ProgressView()
                    .tint(WPStyles.primaryOrange)
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
            .cardStyle()
        case .needsCalendarPermission, .needsAlarmPermission(_):
            permissionPromptCard(viewModel: viewModel)
        case .error:
            ContentUnavailableView("Unavailable", systemImage: "exclamationmark.triangle")
        case .ready(let viewState), .emptyFallback(let viewState):
            VStack(alignment: .leading, spacing: 24) {
                planCard(for: viewState.plan, viewModel: viewModel)

                if !viewModel.upcomingPlans.isEmpty {
                    upcomingPlansCard(viewModel: viewModel)
                }
            }
        }
    }

    @ViewBuilder
    private func planCard(for plan: WakeUpPlan, viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Next Alarm")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(WPStyles.primaryOrange.opacity(0.6))
            }

            if let timeUntilWake = viewModel.timeUntilWake {
                Text(timeUntilWake)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(WPStyles.secondaryText)
            }

            Text(plan.calculatedWakeTime, style: .time)
                .font(WPStyles.timeDisplayFont)
                .monospacedDigit()
                .foregroundStyle(WPStyles.primaryText)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if let ruleName = plan.appliedRuleName {
                Text(ruleName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WPStyles.tertiaryText)
            }

            VStack(alignment: .leading, spacing: 16) {
                if let event = plan.targetEvent {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(WPStyles.primaryOrange)
                        Text(event.title)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundStyle(WPStyles.primaryText)
                        Spacer()
                        Text(event.startDate, style: .time)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(WPStyles.secondaryText)
                    }

                    Divider()

                    timelineRow(icon: "cup.and.saucer.fill", label: "Prep Time", value: "\(plan.prepTime.rawValue)m")
                    timelineRow(icon: "car.fill", label: "Commute", value: "\(plan.commuteTime.rawValue)m")

                    if !plan.matchedRuleNames.isEmpty {
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(WPStyles.secondaryBlue)
                            Text("Matched \(plan.matchedRuleNames.joined(separator: " and ")). Using the earlier alarm.")
                                .font(.caption)
                                .foregroundStyle(WPStyles.secondaryText)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundStyle(.indigo)
                        Text("No early events")
                            .font(.headline)
                            .foregroundStyle(WPStyles.primaryText)
                        Spacer()
                    }
                    Divider()
                    Text(viewModel.statusMessage ?? "Sleeping in until your baseline limit.")
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
            .insetSurfaceStyle(cornerRadius: 24)
        }
        .cardStyle()
    }

    private func upcomingPlansCard(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Alarms")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)
            }

            ForEach(Array(viewModel.upcomingPlans.enumerated()), id: \.element.id) { index, plan in
                upcomingPlanRow(plan, viewModel: viewModel)

                if index < viewModel.upcomingPlans.count - 1 {
                    Divider()
                        .overlay(WPStyles.cardBorder)
                }
            }
        }
        .cardStyle()
    }

    private var topBar: some View {
        HStack {
            Text(AppConfiguration.appName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(WPStyles.secondaryText)

            Spacer()

#if DEBUG
            Button(AppConfiguration.testAlarmButtonTitle) {
                Task { await appState.scheduleTestAlarm() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(WPStyles.secondaryBlue)
#endif
        }
    }

    private func timelineRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(WPStyles.tertiaryText)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(WPStyles.secondaryText)
            Spacer()
            Text("-\(value)")
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(WPStyles.primaryText)
        }
    }

    @ViewBuilder
    private func permissionPromptCard(viewModel: DashboardViewModel) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 40))
                .foregroundStyle(WPStyles.primaryOrange)

            Text("Setup Required")
                .font(.title2.weight(.bold))
                .foregroundStyle(WPStyles.primaryText)

            Text(viewModel.permissionBanner ?? "Please complete setup in settings.")
                .font(.subheadline)
                .foregroundStyle(WPStyles.secondaryText)
                .multilineTextAlignment(.center)

            NavigationLink(destination: PermissionsView(appState: appState)) {
                Text("Fix Permissions")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(WPStyles.primaryOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.top, 8)
        }
        .padding(24)
        .cardStyle()
    }

    @ViewBuilder
    private func banner(_ text: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(WPStyles.primaryText)
            Spacer()
        }
        .padding()
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var systemDisabledBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "power.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                Text("System Disabled")
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
            }
            Text("WakePlan is completely disabled. No alarms will run.")
                .font(.subheadline)
                .foregroundStyle(WPStyles.secondaryText)
            
            Button {
                var copy = appState.preferences
                copy.isSystemEnabled = true
                Task { await appState.updatePreferences(copy) }
            } label: {
                Text("Reactivate")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WPStyles.primaryOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 4)
        }
        .cardStyle()
    }

    private var quickActionRow: some View {
        Button(action: {
            Task { await appState.refreshPlan() }
        }) {
            Label("Recalculate Plan", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(WPStyles.secondaryText)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(Capsule().fill(WPStyles.surfaceRaised))
        }
    }

    private func upcomingPlanRow(_ plan: WakeUpPlan, viewModel: DashboardViewModel) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(WPStyles.surfaceRaised)
                    .frame(width: 36, height: 36)
                Image(systemName: icon(for: plan))
                    .foregroundStyle(WPStyles.primaryOrange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.dayLabel(for: plan))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WPStyles.secondaryText)

                Text(viewModel.upcomingTitle(for: plan))
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)

                Text(viewModel.upcomingSubtitle(for: plan))
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)
            }

            Spacer()

            Text(plan.calculatedWakeTime, style: .time)
                .font(.headline.monospacedDigit())
                .foregroundStyle(WPStyles.primaryText)
        }
    }

    private func icon(for plan: WakeUpPlan) -> String {
        if plan.targetEvent != nil {
            return "calendar"
        }

        switch plan.reason {
        case .inactiveDay:
            return "pause.circle"
        case .disabled:
            return "bed.double.fill"
        case .fallback, .authorizationMissing, .manualOverride, .event, .systemDisabled:
            return "moon.zzz.fill"
        }
    }
}
