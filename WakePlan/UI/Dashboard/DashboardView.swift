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
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: SettingsView(appState: appState)) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(WPStyles.secondaryText)
                }
            }
        }
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
                tomorrowFlowCard(for: viewState.plan)
            }
        }
    }

    @ViewBuilder
    private func planCard(for plan: WakeUpPlan, viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Next Alarm")
                .font(.title3.weight(.semibold))
                .foregroundStyle(WPStyles.primaryText)

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

            HStack(spacing: 10) {
                infoPill(icon: "calendar_month", text: viewModel.heroContext)
                infoPill(icon: "auto_awesome", text: "Auto-Pilot")
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

    private func tomorrowFlowCard(for plan: WakeUpPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tomorrow's Flow")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)
                Spacer()
                NavigationLink(destination: TimingSettingsView(appState: appState)) {
                    Text("Edit")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WPStyles.secondaryBlue)
                }
            }

            timelineEntry(
                title: "Morning Routine",
                subtitle: "\(plan.prepTime.rawValue) mins",
                icon: "cup.and.saucer.fill"
            )

            if let event = plan.targetEvent {
                timelineEntry(
                    title: event.title,
                    subtitle: viewModelCalendarLabel(for: event),
                    icon: "calendar"
                )
            } else {
                timelineEntry(
                    title: "Baseline Wake Limit",
                    subtitle: "No calendar event matched",
                    icon: "moon.zzz.fill"
                )
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

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(WPStyles.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Capsule().fill(WPStyles.surfaceRaised))
    }

    private func timelineEntry(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(WPStyles.surfaceRaised)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(WPStyles.primaryOrange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(WPStyles.tertiaryText)
        }
        .padding(16)
        .insetSurfaceStyle(cornerRadius: 20)
    }

    private func viewModelCalendarLabel(for event: ParsedEvent) -> String {
        appState.calendars.first(where: { $0.id == event.calendarID })?.title ?? "Scheduled event"
    }
}
