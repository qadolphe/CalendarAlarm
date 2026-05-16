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
                Text("Week View")
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
            weeklyOverviewCard(viewModel: viewModel, viewState: viewState)
        }
    }

    private func weeklyOverviewCard(
        viewModel: DashboardViewModel,
        viewState: WakePlanViewState
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Week View")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(WPStyles.secondaryText)

                    Text(viewModel.summaryHeadline)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(WPStyles.primaryText)

                    Text(viewModel.summaryMessage)
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let pillText = viewModel.statusPillText {
                        statusPill(text: pillText, tint: statusTint(for: viewState.alarmStatus))
                    }
                }

                Spacer(minLength: 0)

                Image("OtterOverlook")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84)
                    .offset(x: 4, y: -8)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    legendItem(color: WPStyles.primaryOrange, label: "Alarm")
                    legendItem(color: WPStyles.secondaryBlue, label: "First event")
                    dashLegend
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        legendItem(color: WPStyles.primaryOrange, label: "Alarm")
                        legendItem(color: WPStyles.secondaryBlue, label: "First event")
                    }
                    dashLegend
                }
            }

            weeklyViewer(viewModel: viewModel)

            Text("Tap any day to open the same detail sheet with that day's alarm and event context.")
                .font(.caption)
                .foregroundStyle(WPStyles.tertiaryText)
        }
        .cardStyle()
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

    private func weeklyViewer(viewModel: DashboardViewModel) -> some View {
        GeometryReader { geometry in
            let spacing: CGFloat = geometry.size.width > 390 ? 12 : 8
            let columnWidth = max(34, min(48, (geometry.size.width - (spacing * 6)) / 7))

            HStack(alignment: .top, spacing: spacing) {
                ForEach(viewModel.weekEntries) { entry in
                    dayColumn(entry, viewModel: viewModel, columnWidth: columnWidth)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 320)
    }

    private func dayColumn(
        _ entry: DashboardViewModel.WeekEntry,
        viewModel: DashboardViewModel,
        columnWidth: CGFloat
    ) -> some View {
        Button {
            selectedDayDetails = DayDetailsPresentation(entry: entry)
        } label: {
            VStack(spacing: 12) {
                Text(viewModel.daySymbol(for: entry.targetDay.date))
                    .font(.caption.weight(viewModel.isPrimary(entry) ? .bold : .semibold))
                    .foregroundStyle(viewModel.isPrimary(entry) ? WPStyles.primaryText : WPStyles.secondaryText)
                    .frame(height: 18)

                weekPillBar(entry: entry, isPrimary: viewModel.isPrimary(entry))
                    .frame(width: columnWidth, height: 248)

                Text(viewModel.footerText(for: entry))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(footerTint(for: entry))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.accessibilityLabel(for: entry))
    }

    private func weekPillBar(
        entry: DashboardViewModel.WeekEntry,
        isPrimary: Bool
    ) -> some View {
        GeometryReader { geometry in
            let markerPadding: CGFloat = 18
            let outlineColor = isPrimary
                ? WPStyles.secondaryBlue.opacity(0.95)
                : WPStyles.secondaryBlue.opacity(0.72)

            ZStack {
                Capsule()
                    .fill(WPStyles.secondaryBlue.opacity(isPrimary ? 0.14 : 0.08))

                Capsule()
                    .stroke(outlineColor, lineWidth: isPrimary ? 2.4 : 1.8)

                if entry.hasConnectedMarkers,
                   let eventY = markerY(for: entry.eventDate, on: entry.targetDay, height: geometry.size.height, padding: markerPadding),
                   let alarmY = markerY(for: entry.alarmDate, on: entry.targetDay, height: geometry.size.height, padding: markerPadding) {
                    Path { path in
                        let x = geometry.size.width / 2
                        path.move(to: CGPoint(x: x, y: min(eventY, alarmY)))
                        path.addLine(to: CGPoint(x: x, y: max(eventY, alarmY)))
                    }
                    .stroke(
                        WPStyles.primaryOrange.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5])
                    )
                }

                if let alarmY = markerY(for: entry.alarmDate, on: entry.targetDay, height: geometry.size.height, padding: markerPadding) {
                    marker(color: WPStyles.primaryOrange, y: alarmY, in: geometry.size, isPrimary: isPrimary)
                }

                if let eventY = markerY(for: entry.eventDate, on: entry.targetDay, height: geometry.size.height, padding: markerPadding) {
                    marker(color: WPStyles.secondaryBlue, y: eventY, in: geometry.size, isPrimary: isPrimary)
                }
            }
        }
    }

    private func marker(
        color: Color,
        y: CGFloat,
        in size: CGSize,
        isPrimary: Bool
    ) -> some View {
        Circle()
            .fill(WPStyles.background)
            .frame(width: isPrimary ? 18 : 16, height: isPrimary ? 18 : 16)
            .overlay {
                Circle()
                    .fill(color)
                    .padding(isPrimary ? 4 : 3)
            }
            .shadow(color: color.opacity(0.35), radius: isPrimary ? 6 : 3)
            .position(x: size.width / 2, y: y)
    }

    private func markerY(
        for date: Date?,
        on targetDay: TargetDay,
        height: CGFloat,
        padding: CGFloat
    ) -> CGFloat? {
        guard let date else { return nil }

        let clampedInterval = min(max(date.timeIntervalSince(targetDay.date), 0), (24 * 60 * 60) - 1)
        let fraction = clampedInterval / (24 * 60 * 60)
        return padding + (height - (padding * 2)) * fraction
    }

    private func statusPill(text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WPStyles.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.14))
        .clipShape(Capsule())
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(WPStyles.secondaryText)
        }
    }

    private var dashLegend: some View {
        HStack(spacing: 8) {
            Capsule()
                .stroke(WPStyles.primaryOrange.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [3, 5]))
                .frame(width: 24, height: 8)

            Text("Dashed line = event-based alarm")
                .font(.caption.weight(.medium))
                .foregroundStyle(WPStyles.secondaryText)
        }
    }

    private func statusTint(for status: AlarmScheduleStatus) -> Color {
        switch status {
        case .scheduled:
            return WPStyles.successGreen
        case .needsPermission:
            return WPStyles.primaryOrange
        case .disabled, .notScheduled:
            return WPStyles.tertiaryText
        case .failed:
            return .red
        }
    }

    private func footerTint(for entry: DashboardViewModel.WeekEntry) -> Color {
        switch entry.plan.reason {
        case .event, .fallback, .authorizationMissing, .manualOverride:
            return WPStyles.primaryText
        case .disabled, .inactiveDay, .noSchedule, .systemDisabled:
            return WPStyles.tertiaryText
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
