import SwiftUI

struct DashboardView: View {
    private struct DayDetailsPresentation: Identifiable {
        let entry: DashboardViewModel.WeekEntry

        var id: Date {
            entry.id
        }
    }

    @Bindable var appState: AppState
    var onOpenSchedule: () -> Void = {}
    @State private var selectedDayDetails: DayDetailsPresentation? = nil
    @AppStorage("hasDismissedStandbyPrompt") private var hasDismissedStandbyPrompt = false

    private var isLoading: Bool {
        if case .loading = appState.dashboardState { return true }
        return false
    }

    var body: some View {
        let viewModel = DashboardViewModel(appState: appState)

        ZStack {
            if isLoading {
                DashboardLoadingView()
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .tabBar)
                    .transition(.opacity)
                    .zIndex(1)
            } else {
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
                .transition(.opacity)
                .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isLoading)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.loadIfNeeded()
        }
        .sheet(item: $selectedDayDetails) { item in
            EarlyOtterDetailsView(plan: item.entry.plan, alarmStatus: item.entry.alarmStatus)
        }
    }

    @ViewBuilder
    private func content(viewModel: DashboardViewModel) -> some View {
        switch appState.dashboardState {
        case .loading:
            EmptyView()
        case .needsCalendarPermission:
            permissionPromptCard(viewModel: viewModel)
        case .error:
            ContentUnavailableView("Unavailable", systemImage: "exclamationmark.triangle")
        case .needsAlarmPermission(let viewState),
             .ready(let viewState),
             .emptyFallback(let viewState):
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    if showsNoAlarmCard(for: viewState.plan) {
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

                if hasNoFixedAlarms && !hasDismissedStandbyPrompt {
                    setAlarmsPromptCard
                }

                DashboardWeeklyCardView(viewModel: viewModel) { entry in
                    selectedDayDetails = DayDetailsPresentation(entry: entry)
                }
            }
        }
    }

    private var hasNoFixedAlarms: Bool {
        appState.preferences.hasNoFixedAlarms
    }

    private var setAlarmsPromptCard: some View {
        // Two sibling buttons (not nested): the card navigates, the corner ✕ dismisses.
        ZStack(alignment: .topTrailing) {
            Button {
                onOpenSchedule()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "alarm.fill")
                        .font(.title3)
                        .foregroundStyle(WPStyles.primaryOrange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set your standby alarms")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WPStyles.primaryText)
                        Text("Pick wake-up times for days without events")
                            .font(.caption)
                            .foregroundStyle(WPStyles.secondaryText)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.leading, 16)
                .padding(.trailing, 30) // reserve room so text never sits under the ✕
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(WPStyles.surface))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.primaryOrange.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                hasDismissedStandbyPrompt = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WPStyles.tertiaryText)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
            .padding(.top, 4)
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
            return "Auto Alarms are paused for this day."
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

    private func showsNoAlarmCard(for plan: WakeUpPlan) -> Bool {
        switch plan.reason {
        case .disabled, .inactiveDay, .noSchedule, .systemDisabled:
            return true
        case .fallback, .authorizationMissing, .manualOverride, .event:
            return false
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
                Task { await appState.mutatePreferences { $0.isSystemEnabled = true } }
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
                            .foregroundStyle(WPStyles.secondaryBlue)
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
        let pages = viewModel.weekPages

        VStack(alignment: .leading, spacing: 14) {
            if let currentPage = currentPage(in: pages) {
                Text(viewModel.weekRangeTitle(for: currentPage))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)

                TabView(selection: $selectedWeekIndex) {
                    ForEach(pages) { page in
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

    private func currentPage(in pages: [DashboardViewModel.WeekPage]) -> DashboardViewModel.WeekPage? {
        guard !pages.isEmpty else {
            return nil
        }

        let safeIndex = min(max(selectedWeekIndex, 0), pages.count - 1)
        return pages[safeIndex]
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
