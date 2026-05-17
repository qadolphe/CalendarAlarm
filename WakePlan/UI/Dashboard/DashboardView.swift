import SwiftUI

struct DashboardView: View {
    private struct DayDetailsPresentation: Identifiable {
        let entry: DashboardViewModel.WeekEntry

        var id: Date {
            entry.id
        }
    }

    @Bindable var appState: AppState
    @State private var selectedDayDetails: DayDetailsPresentation? = nil

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
                    }
                    .opacity(appState.preferences.isSystemEnabled ? 1 : 0.4)
                    .disabled(!appState.preferences.isSystemEnabled)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .refreshable {
            await appState.refreshPlan()
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.loadIfNeeded()
        }
        .sheet(item: $selectedDayDetails) { item in
            WakePlanDetailsView(plan: item.entry.plan, alarmStatus: item.entry.alarmStatus)
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
        case .needsCalendarPermission:
            permissionPromptCard(viewModel: viewModel)
        case .error:
            ContentUnavailableView("Unavailable", systemImage: "exclamationmark.triangle")
        case .needsAlarmPermission(let viewState),
             .ready(let viewState),
             .emptyFallback(let viewState):
            VStack(alignment: .leading, spacing: 24) {
                ZStack(alignment: .topTrailing) {
                    if viewState.plan.reason == .disabled
                        || viewState.plan.reason == .inactiveDay
                        || viewState.plan.reason == .noSchedule
                        || viewState.plan.reason == .systemDisabled {
                        DashboardNoAlarmCardView(
                            message: noAlarmMessage(for: viewState.plan)
                        )
                    } else {
                        DashboardHeroCardView(
                            plan: viewState.plan,
                            viewModel: viewModel,
                            onTap: {
                                selectedDayDetails = DayDetailsPresentation(
                                    entry: viewModel.entry(
                                        for: viewState.plan,
                                        alarmStatus: viewState.alarmStatus
                                    )
                                )
                            }
                        )
                    }

                    Image("OtterOverlook")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88)
                        .offset(x: -20, y: -70)
                }
                .padding(.top, 16)

                DashboardWeeklyCardView(viewModel: viewModel) { entry in
                    selectedDayDetails = DayDetailsPresentation(entry: entry)
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text(AppConfiguration.appName)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(WPStyles.primaryOrange)
                .padding(.leading, 10)
                .offset(y: 15)

            Spacer()
        }
        .padding(.bottom, -12)
    }

    private func noAlarmMessage(for plan: WakeUpPlan) -> String {
        switch plan.reason {
        case .inactiveDay:
            return "Auto-Pilot is paused for this day."
        case .noSchedule:
            return "No scheduled events or fallback alarms are coming up."
        case .disabled:
            return "Automatic alarms are turned off."
        case .systemDisabled:
            return "EarlyOtter is disabled."
        case .fallback, .authorizationMissing, .manualOverride, .event:
            return "No alarm is currently scheduled."
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
            Text("EarlyOtter is completely disabled. No alarms will run.")
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
}

private struct DashboardHeroCardView: View {
    let plan: WakeUpPlan
    let viewModel: DashboardViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
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

                if let event = plan.targetEvent {
                    HStack(spacing: 8) {
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
                    .padding(.top, 4)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundStyle(.indigo)
                        Text(viewModel.statusMessage ?? "Sleeping in")
                            .font(.headline)
                            .lineLimit(2)
                            .foregroundStyle(WPStyles.primaryText)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .cardStyle()
    }
}

private struct DashboardNoAlarmCardView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Next Alarm")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title)
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 4) {
                    Text("No alarm scheduled")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(WPStyles.primaryText)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.secondaryText)
                }
            }
            .padding(.vertical, 8)
        }
        .cardStyle()
    }
}

private struct DashboardWeeklyCardView: View {
    let viewModel: DashboardViewModel
    let onSelect: (DashboardViewModel.WeekEntry) -> Void
    @State private var selectedWeekIndex: Int

    init(
        viewModel: DashboardViewModel,
        onSelect: @escaping (DashboardViewModel.WeekEntry) -> Void
    ) {
        self.viewModel = viewModel
        self.onSelect = onSelect
        _selectedWeekIndex = State(initialValue: viewModel.defaultWeekPageIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !viewModel.weekPages.isEmpty {
                Text(viewModel.weekRangeTitle(for: currentPage))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)

                TabView(selection: $selectedWeekIndex) {
                    ForEach(viewModel.weekPages) { page in
                        DashboardWeekPageView(
                            page: page,
                            viewModel: viewModel,
                            onSelect: onSelect
                        )
                        .tag(page.index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 270)
            }
        }
        .cardStyle()
    }

    private var currentPage: DashboardViewModel.WeekPage {
        let safeIndex = min(selectedWeekIndex, max(viewModel.weekPages.count - 1, 0))
        return viewModel.weekPages[safeIndex]
    }
}

private struct DashboardWeekPageView: View {
    let page: DashboardViewModel.WeekPage
    let viewModel: DashboardViewModel
    let onSelect: (DashboardViewModel.WeekEntry) -> Void

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = geometry.size.width > 390 ? 12 : 8
            let edgePadding: CGFloat = geometry.size.width > 390 ? 6 : 4
            let availableWidth = geometry.size.width - (edgePadding * 2)
            let columnWidth = max(34, min(48, (availableWidth - (spacing * 6)) / 7))

            HStack(alignment: .top, spacing: spacing) {
                ForEach(page.entries) { entry in
                    DashboardWeekDayColumnView(
                        entry: entry,
                        viewModel: viewModel,
                        columnWidth: columnWidth,
                        onSelect: onSelect
                    )
                }
            }
            .padding(.horizontal, edgePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DashboardWeekDayColumnView: View {
    let entry: DashboardViewModel.WeekEntry
    let viewModel: DashboardViewModel
    let columnWidth: CGFloat
    let onSelect: (DashboardViewModel.WeekEntry) -> Void

    var body: some View {
        Button {
            onSelect(entry)
        } label: {
            VStack(spacing: 10) {
                Text(viewModel.daySymbol(for: entry.targetDay.date))
                    .font(.caption.weight(viewModel.isPrimary(entry) ? .bold : .semibold))
                    .foregroundStyle(viewModel.isPrimary(entry) ? WPStyles.primaryText : WPStyles.secondaryText)
                    .frame(height: 18)

                DashboardWeekPillBarView(
                    entry: entry,
                    isPrimary: viewModel.isPrimary(entry),
                    viewModel: viewModel
                )
                .frame(width: columnWidth, height: 236)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.accessibilityLabel(for: entry))
    }
}

private struct DashboardWeekPillBarView: View {
    let entry: DashboardViewModel.WeekEntry
    let isPrimary: Bool
    let viewModel: DashboardViewModel

    private let markerPadding: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let isElapsed = viewModel.isElapsed(entry)
            let dimmingOpacity = isElapsed ? 0.35 : 1.0
            let outlineColor = isPrimary
                ? WPStyles.deepOrange.opacity(0.92)
                : WPStyles.deepOrange.opacity(0.68)

            ZStack {
                Capsule()
                    .fill(WPStyles.deepOrange.opacity((isPrimary ? 0.16 : 0.09) * dimmingOpacity))

                Capsule()
                    .stroke(outlineColor.opacity(dimmingOpacity), lineWidth: isPrimary ? 2.4 : 1.8)

                if entry.hasConnectedMarkers,
                   let eventY = markerY(for: entry.eventDate, on: entry.targetDay, height: geometry.size.height),
                   let alarmY = markerY(for: entry.alarmDate, on: entry.targetDay, height: geometry.size.height) {
                    Path { path in
                        let x = geometry.size.width / 2
                        path.move(to: CGPoint(x: x, y: min(eventY, alarmY)))
                        path.addLine(to: CGPoint(x: x, y: max(eventY, alarmY)))
                    }
                    .stroke(
                        WPStyles.primaryOrange.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5])
                    )
                    .opacity(dimmingOpacity)
                }

                if let alarmY = markerY(for: entry.alarmDate, on: entry.targetDay, height: geometry.size.height) {
                    marker(color: WPStyles.primaryOrange, y: alarmY, in: geometry.size, opacity: dimmingOpacity)
                }

                if let eventY = markerY(for: entry.eventDate, on: entry.targetDay, height: geometry.size.height) {
                    marker(color: WPStyles.secondaryBlue, y: eventY, in: geometry.size, opacity: dimmingOpacity)
                }
            }
        }
    }

    private func marker(color: Color, y: CGFloat, in size: CGSize, opacity: Double) -> some View {
        Circle()
            .fill(WPStyles.background)
            .frame(width: isPrimary ? 18 : 16, height: isPrimary ? 18 : 16)
            .overlay {
                Circle()
                    .fill(color)
                    .padding(isPrimary ? 4 : 3)
            }
            .shadow(color: color.opacity(0.35), radius: isPrimary ? 6 : 3)
            .opacity(opacity)
            .position(x: size.width / 2, y: y)
    }

    private func markerY(for date: Date?, on targetDay: TargetDay, height: CGFloat) -> CGFloat? {
        guard let fraction = viewModel.markerFraction(for: date, on: targetDay) else {
            return nil
        }

        return markerPadding + (height - (markerPadding * 2)) * fraction
    }
}
