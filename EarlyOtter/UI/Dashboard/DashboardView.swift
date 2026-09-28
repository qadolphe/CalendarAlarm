import SwiftUI

struct DashboardView: View {
    @Bindable var appState: AppState
    var onOpenSchedule: () -> Void = {}
    /// The day open in the planner; the week card folds into date circles above it.
    @State private var openDayID: Date?
    /// 0 is the Home layout, 1 the planner fully open. Drags drive it directly.
    @State private var dayProgress: CGFloat = 0
    @State private var weekCardFrame: CGRect = .zero
    @State private var editingPlan: WakeUpPlan?
    @State private var alarmMove: AlarmMove?

    /// A drag-moved alarm, kept long enough to offer Undo.
    private struct AlarmMove: Equatable {
        let day: TargetDay
        let time: Date
        let previousOverride: DayAlarmOverride?
        let ruleName: String?
    }
    // Kept from the standby prompt, so anyone who closed that one isn't asked again.
    @AppStorage("hasDismissedStandbyPrompt") private var hasDismissedAlarmPrompt = false
    @State private var isShowingFeedback = false

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
                ZStack(alignment: .topLeading) {
                    Color.clear.withAppBackground()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            topBar

                            if !appState.preferences.isSystemEnabled {
                                disabledContent(viewModel: viewModel)
                            } else {
                                VStack(alignment: .leading, spacing: 24) {
                                    if let permissionBanner = viewModel.permissionBanner {
                                        banner(permissionBanner, tint: WPStyles.accent, icon: "bell.badge.fill")
                                    }

                                    if let noticeMessage = appState.noticeMessage {
                                        banner(noticeMessage, tint: .green, icon: "checkmark.circle.fill")
                                    }

                                    if let errorMessage = appState.errorMessage {
                                        banner(errorMessage, tint: .red, icon: "exclamationmark.triangle.fill")
                                    }

                                    content(viewModel: viewModel)
                                }
                            }

                            feedbackFooter
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    }
                    .refreshable {
                        await appState.refreshPlan()
                    }
                    .opacity(1 - dayProgress)
                    .allowsHitTesting(openDayID == nil)

                    if let openDayID, let page = viewModel.page(containing: openDayID),
                       let entry = page.entries.first(where: { $0.id == openDayID }) {
                        dayOverlay(page: page, entry: entry, viewModel: viewModel)
                    }
                }
                .coordinateSpace(.named(Self.coordinateSpace))
                .toolbar(openDayID == nil ? .visible : .hidden, for: .tabBar)
                .transition(.opacity)
                .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isLoading)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.loadIfNeeded()
        }
        .sheet(item: $editingPlan) { plan in
            DayAlarmEditView(appState: appState, plan: plan) { editingPlan = nil }
                .withAppBackground()
                .presentationDetents([.fraction(0.6)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingFeedback) {
            NavigationStack {
                FeedbackView(appState: appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { isShowingFeedback = false }
                                .fontWeight(.bold)
                                .foregroundStyle(WPStyles.accent)
                        }
                    }
            }
        }
    }

    private static let coordinateSpace = "dashboard"

    /// The week card lifted out of the scroll view and folded to the top, with the
    /// planner sliding up under it. At progress 0 it sits exactly over the real card.
    private func dayOverlay(
        page: DashboardViewModel.WeekPage,
        entry: DashboardViewModel.WeekEntry,
        viewModel: DashboardViewModel
    ) -> some View {
        GeometryReader { proxy in
            let collapsedTop: CGFloat = 8
            let panelTop = collapsedTop + WeekStrip.collapsedCardHeight + 8
            let panelHeight = proxy.size.height - panelTop

            ZStack(alignment: .topLeading) {
                DashboardWeekCardView(title: viewModel.weekRangeTitle(for: page), collapse: dayProgress) {
                    DashboardWeekPageView(
                        page: page,
                        viewModel: viewModel,
                        collapse: dayProgress,
                        selectedDayID: entry.id,
                        onSelect: openDay
                    )
                }
                .frame(width: weekCardFrame.width)
                .offset(x: weekCardFrame.minX, y: lerp(weekCardFrame.minY, collapsedTop, dayProgress))

                // Swiping sideways moves between the week's days, like tapping the circles.
                TabView(selection: Binding(get: { openDayID ?? entry.id }, set: { openDayID = $0 })) {
                    ForEach(page.entries) { dayEntry in
                        DayPlannerView(
                            entry: dayEntry,
                            onEditAlarm: { editingPlan = dayEntry.plan },
                            onMoveAlarm: { moveAlarm(of: dayEntry.plan, to: $0) },
                            onPull: { dayProgress = max(0, 1 - $0 / panelHeight) },
                            onRelease: { $0 ? closeDay() : reopenDay() }
                        )
                        .tag(dayEntry.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(
                    WPStyles.surface,
                    in: UnevenRoundedRectangle(topLeadingRadius: WPStyles.cardCornerRadius, topTrailingRadius: WPStyles.cardCornerRadius, style: .continuous)
                )
                .overlay(alignment: .bottom) {
                    if let alarmMove {
                        alarmMoveToast(alarmMove)
                            .padding(.bottom, 40)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.smooth(duration: 0.3), value: alarmMove)
                .frame(height: panelHeight)
                .offset(y: panelTop + (1 - dayProgress) * panelHeight)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func openDay(_ entry: DashboardViewModel.WeekEntry) {
        guard openDayID != nil else {
            openDayID = entry.id
            withAnimation(.smooth(duration: 0.5)) { dayProgress = 1 }
            return
        }
        withAnimation(.smooth(duration: 0.35)) { openDayID = entry.id }
    }

    /// Saves a dragged alarm as a one-day override, like the editor does, with Undo.
    private func moveAlarm(of plan: WakeUpPlan, to time: Date) {
        let day = plan.targetDay
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let move = AlarmMove(
            day: day,
            time: time,
            previousOverride: appState.preferences.override(for: day),
            ruleName: plan.reason == .event ? plan.appliedRuleName : nil
        )
        alarmMove = move
        Task {
            await appState.setDayOverride(
                DayAlarmOverride(customWakeTime: ClockTime(hour: components.hour ?? 0, minute: components.minute ?? 0)),
                for: day
            )
            try? await Task.sleep(for: .seconds(4))
            if alarmMove == move { alarmMove = nil }
        }
    }

    private func undoAlarmMove(_ move: AlarmMove) {
        alarmMove = nil
        Task { await appState.setDayOverride(move.previousOverride, for: move.day) }
    }

    private func alarmMoveToast(_ move: AlarmMove) -> some View {
        let dayName = move.day.date.formatted(.dateTime.weekday(.wide))

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Alarm moved to \(move.time.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)
                Text(move.ruleName.map { "Overrides \($0) for \(dayName) only" } ?? "For \(dayName) only")
                    .font(.caption)
                    .foregroundStyle(WPStyles.secondaryText)
            }

            Spacer(minLength: 8)

            Button("Undo") { undoAlarmMove(move) }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(WPStyles.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(WPStyles.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.accent.opacity(0.5), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    /// A drag that didn't go far enough springs back open.
    private func reopenDay() {
        withAnimation(.smooth(duration: 0.35)) { dayProgress = 1 }
    }

    private func closeDay() {
        withAnimation(.smooth(duration: 0.45)) {
            dayProgress = 0
        } completion: {
            if dayProgress == 0 { openDayID = nil }
        }
    }

    @ViewBuilder
    private var feedbackFooter: some View {
        if AppConfiguration.showsHomeFeedbackFooter {
            VStack(spacing: 8) {
                Divider()
                    .overlay(WPStyles.cardBorder)
                    .padding(.bottom, 4)

                Button {
                    isShowingFeedback = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("Send feedback")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WPStyles.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send feedback")
            }
            .frame(maxWidth: .infinity)
            // Pull back most of the parent VStack's 24pt spacing so the footer tucks
            // under the weekly card, then hold it clear of the floating tab bar.
            .padding(.top, -12)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func disabledContent(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                systemDisabledBanner
                otterOverlook
            }
            .padding(.top, 16)

            switch appState.dashboardState {
            case .needsAlarmPermission(_),
                 .ready(_),
                 .emptyFallback(_):
                DashboardWeeklyCardView(viewModel: viewModel) { _ in }
                .opacity(0.4)
                .disabled(true)
                .accessibilityHidden(true)
            case .loading, .needsCalendarPermission, .error:
                EmptyView()
            }
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
                                openDay(viewModel.entry(for: viewState.plan, alarmStatus: viewState.alarmStatus))
                            }
                        )
                    }

                    otterOverlook
                }
                .padding(.top, 16)

                if appState.preferences.standardAlarms.isEmpty && !hasDismissedAlarmPrompt {
                    addAlarmPromptCard
                }

                DashboardWeeklyCardView(viewModel: viewModel, onSelect: openDay)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.coordinateSpace)) } action: {
                        weekCardFrame = $0
                    }
                    // The overlay's copy stands in while a day is open.
                    .opacity(openDayID == nil ? 1 : 0)
            }
        }
    }

    private var otterOverlook: some View {
        Image("OtterOverlook")
            .resizable()
            .scaledToFit()
            .frame(width: 88)
            .offset(x: -20, y: -70)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var addAlarmPromptCard: some View {
        // Two sibling buttons (not nested): the card navigates, the corner ✕ dismisses.
        ZStack(alignment: .topTrailing) {
            Button {
                onOpenSchedule()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "alarm.fill")
                        .font(.title3)
                        .foregroundStyle(WPStyles.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add a backup alarm")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WPStyles.primaryText)
                        Text("For days without early events")
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
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.accent.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                hasDismissedAlarmPrompt = true
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
                .foregroundStyle(WPStyles.accent)
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
            return "No calendar events or alarms are coming up."
        case .disabled:
            return "Automatic alarms are turned off."
        case .systemDisabled:
            return "EarlyOtter is disabled."
        case .manualSkip:
            return "You turned off the alarm for this day."
        case .alarm, .authorizationMissing, .manualOverride, .event:
            return "No alarm is currently scheduled."
        }
    }

    private func showsNoAlarmCard(for plan: WakeUpPlan) -> Bool {
        switch plan.reason {
        case .disabled, .inactiveDay, .noSchedule, .systemDisabled, .manualSkip:
            return true
        case .alarm, .authorizationMissing, .manualOverride, .event:
            return false
        }
    }

    @ViewBuilder
    private func permissionPromptCard(viewModel: DashboardViewModel) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 40))
                .foregroundStyle(WPStyles.accent)

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
                    .foregroundStyle(WPStyles.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(WPStyles.accent)
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
        HStack(spacing: 10) {
            Image(systemName: "power")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red)

            Text("System disabled")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WPStyles.primaryText)

            Spacer(minLength: 8)

            Button {
                Task { await appState.mutatePreferences { $0.isSystemEnabled = true } }
            } label: {
                Text("Reactivate")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WPStyles.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(WPStyles.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WPStyles.surface)
        )
    }
}

private struct DashboardHeroCardView: View {
    let plan: WakeUpPlan
    let viewModel: DashboardViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            WakeUpTimetableView(plan: plan, note: viewModel.statusMessage)
                .padding(.horizontal, 4)
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
                        .font(.system(.title2, design: .rounded).weight(.bold))
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

/// Sizes shared by the Home week card and its folded copy above the planner.
private enum WeekStrip {
    static let pillHeight: CGFloat = 200
    static let circleSize: CGFloat = 36
    static let titleHeight: CGFloat = 22
    /// Day letter, wake label and the gaps around the pill.
    static let columnChrome: CGFloat = 52

    static func pageHeight(_ collapse: CGFloat) -> CGFloat {
        columnChrome + lerp(pillHeight, circleSize, collapse)
    }

    /// Card padding plus a fully folded page.
    static let collapsedCardHeight = 32 + pageHeight(1)
}

private func lerp(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
    from + (to - from) * progress
}

/// The week card's frame: its title folds away as `collapse` goes to 1.
private struct DashboardWeekCardView<Pages: View>: View {
    let title: String
    var collapse: CGFloat = 0
    @ViewBuilder let pages: Pages

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * (1 - collapse)) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(WPStyles.primaryText)
                .frame(height: WeekStrip.titleHeight * (1 - collapse), alignment: .top)
                .clipped()
                .opacity(1 - collapse * 2)

            pages
                .frame(height: WeekStrip.pageHeight(collapse))
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

        if let currentPage = currentPage(in: pages) {
            DashboardWeekCardView(title: viewModel.weekRangeTitle(for: currentPage)) {
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
            }
        }
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
    var collapse: CGFloat = 0
    var selectedDayID: Date? = nil
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
                        collapse: collapse,
                        isSelected: entry.id == selectedDayID,
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
    let collapse: CGFloat
    let isSelected: Bool
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
                    isSelected: isSelected,
                    collapse: collapse,
                    viewModel: viewModel
                )
                .frame(
                    width: lerp(columnWidth, WeekStrip.circleSize, collapse),
                    height: lerp(WeekStrip.pillHeight, WeekStrip.circleSize, collapse)
                )

                ZStack {
                    Text(viewModel.wakeLabel(for: entry))
                        .font(.system(size: 12, weight: viewModel.isPrimary(entry) ? .bold : .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(wakeLabelColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity((viewModel.isElapsed(entry) ? 0.35 : 1) * (1 - collapse * 2))

                    // Folded, the day keeps a hint of what's on it.
                    HStack(spacing: 3) {
                        if entry.alarmDate != nil { hintDot(WPStyles.accent) }
                        if entry.displayedEvent != nil { hintDot(WPStyles.eventTint) }
                    }
                    .opacity(collapse * 2 - 1)
                }
                .frame(height: 14)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.accessibilityLabel(for: entry))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var wakeLabelColor: Color {
        if entry.alarmDate == nil { return WPStyles.tertiaryText }
        return viewModel.isPrimary(entry) ? WPStyles.primaryText : WPStyles.secondaryText
    }

    private func hintDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
    }
}

private struct DashboardWeekPillBarView: View {
    let entry: DashboardViewModel.WeekEntry
    let isPrimary: Bool
    let isSelected: Bool
    let collapse: CGFloat
    let viewModel: DashboardViewModel

    private let markerPadding: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let isElapsed = viewModel.isElapsed(entry)
            let dimmingOpacity = isElapsed ? 0.35 : 1.0
            // Markers fade out early in the fold; the date fades in late.
            let markerOpacity = dimmingOpacity * max(0, 1 - collapse * 1.5)
            let outlineColor = isPrimary
                ? WPStyles.accentMuted.opacity(0.92)
                : WPStyles.accentMuted.opacity(0.68)

            ZStack {
                Capsule()
                    .fill(WPStyles.accentMuted.opacity((isPrimary ? 0.16 : 0.09) * dimmingOpacity))

                Capsule()
                    .fill(WPStyles.accent)
                    .opacity(isSelected ? collapse : 0)

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
                        WPStyles.accent.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5])
                    )
                    .opacity(markerOpacity)
                }

                if let alarmY = markerY(for: entry.alarmDate, on: entry.targetDay, height: geometry.size.height) {
                    marker(color: WPStyles.accent, y: alarmY, in: geometry.size, opacity: markerOpacity)
                }

                if let eventY = markerY(for: entry.eventDate, on: entry.targetDay, height: geometry.size.height) {
                    marker(color: WPStyles.eventTint, y: eventY, in: geometry.size, opacity: markerOpacity)
                }

                Text(entry.targetDay.date.formatted(.dateTime.day()))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? WPStyles.onAccent : WPStyles.primaryText)
                    .opacity(dimmingOpacity * max(0, collapse * 1.6 - 0.6))
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
