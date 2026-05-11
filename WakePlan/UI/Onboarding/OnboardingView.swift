import SwiftUI

struct OnboardingView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    var onFinish: (() -> Void)? = nil
    
    @State private var currentStep = 0
    @State private var selectedWeekday: WeekdayOption?
    @State private var finishPhase = 0
    private let totalSteps = 5
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.clear.withAppBackground()
            
            persistentBackground
            
            ZStack {
                currentStepView
                    .id(currentStep)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
            .animation(.easeInOut, value: currentStep)
        }
        .sheet(item: $selectedWeekday) { option in
            DaySettingsView(appState: appState, weekdayOption: option)
        }
    }
    
    // MARK: - Persistent Background
    
    private var persistentBackground: some View {
        Image("OtterSwim")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: 380)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.15),
                        .init(color: .black, location: 0.65),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
    
    // MARK: - Steps

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0:
            welcomeStep
        case 1:
            permissionsStep
        case 2:
            calendarStep
        case 3:
            routineStep
        default:
            finishStep
        }
    }
    
    private var welcomeStep: some View {
        onboardingPage {
            VStack(spacing: 8) {
                Text("Welcome to")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WPStyles.secondaryText)
                    .textCase(.uppercase)
                    .tracking(2)
                    .multilineTextAlignment(.center)
                
                Text(AppConfiguration.appName)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(WPStyles.primaryText)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                Text("Perfectly synced with your morning schedule.")
                    .font(.title3)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }
        } footer: {
            nextButton(title: "Get Started") {
                advanceToNextStep()
            }
        }
    }
    
    private var permissionsStep: some View {
        onboardingPage {
            VStack(spacing: 12) {
                Text("Grant Permissions")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                    .multilineTextAlignment(.center)
                
                Text(AppConfiguration.onboardingAlarmPermissionExplanation)
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage = appState.errorMessage {
                statusBanner(errorMessage, tint: .red, icon: "exclamationmark.triangle.fill")
            }

            if let noticeMessage = appState.noticeMessage {
                statusBanner(noticeMessage, tint: WPStyles.primaryOrange, icon: "info.circle.fill")
            }
            
            VStack(spacing: 16) {
                permissionRow(
                    title: "Alarm Access",
                    icon: "alarm.fill",
                    isGranted: appState.permissions.alarm == .authorized,
                    actionTitle: "Allow",
                    action: { Task { await appState.requestAlarmAccess() } }
                )
                
                permissionRow(
                    title: "Notifications",
                    icon: "bell.fill",
                    isGranted: appState.permissions.notification == .authorized,
                    actionTitle: "Allow",
                    action: { Task { await appState.requestNotificationAccess() } }
                )
            }
            .cardStyle()
        } footer: {
            let alarmGranted = appState.permissions.alarm == .authorized

            nextButton(
                title: alarmGranted ? "Next" : "Allow Alarms to Continue",
                color: alarmGranted ? WPStyles.primaryOrange : .black
            ) {
                if alarmGranted {
                    advanceToNextStep()
                } else {
                    Task { await appState.requestAlarmAccess() }
                }
            }
        }
    }
    
    private var calendarStep: some View {
        onboardingPage {
            VStack(spacing: 12) {
                Text("Add Your Calendar")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Connect at least one calendar source to get started.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 16) {
                calendarSourceRow(
                    title: "Apple Calendar",
                    subtitle: hasAppleCalendarSource ? nil : "Use your on-device calendars and subscriptions",
                    icon: "apple.logo",
                    isConnected: hasAppleCalendarSource,
                    actionTitle: "Add",
                    action: { Task { await appState.connectAppleCalendar() } }
                )
                
                calendarSourceRow(
                    title: "Google Calendar",
                    subtitle: googleCalendarSubtitle,
                    icon: "g.circle.fill",
                    isConnected: hasGoogleCalendarSource,
                    actionTitle: "Add",
                    action: { Task { await appState.addGoogleAccount() } }
                )
            }
            .cardStyle()
        } footer: {
            nextButton(title: hasAnyCalendarSource ? "Next" : "Add a Calendar to Continue") {
                advanceToNextStep()
            }
            .disabled(!hasAnyCalendarSource)
            .opacity(hasAnyCalendarSource ? 1.0 : 0.5)
        }
    }
    
    private var routineStep: some View {
        onboardingPage {
            VStack(spacing: 12) {
                Text("Your Default Routine")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("We'll subtract this prep and commute time from your first event.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 0) {
                routineRow(
                    title: "Prep",
                    icon: "cup.and.saucer.fill",
                    value: appState.preferences.defaultAlarmRule.prepTime.rawValue,
                    binding: prepTimeBinding
                )
                
                Divider().overlay(WPStyles.cardBorder).padding(.leading, 16)
                
                routineRow(
                    title: "Commute",
                    icon: "car.fill",
                    value: appState.preferences.defaultAlarmRule.commuteTime.rawValue,
                    binding: commuteTimeBinding
                )
            }
            .background(WPStyles.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
        } footer: {
            nextButton(title: "Next") {
                advanceToNextStep()
            }
        }
    }
    
    private var finishStep: some View {
        onboardingPage {
            VStack(spacing: 32) {
                if finishPhase == 1 {
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(WPStyles.successGreen)
                        
                        Text("You're All Set!")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(WPStyles.primaryText)
                            .multilineTextAlignment(.center)
                    }
                    .transition(.opacity.combined(with: .scale))
                } else if finishPhase == 2 {
                    VStack(spacing: 24) {
                        ProgressView()
                            .tint(WPStyles.primaryOrange)
                            .scaleEffect(1.8)
                        
                        Text("Generating alarms...")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(WPStyles.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .transition(.opacity.combined(with: .scale))
                } else if finishPhase == 3 {
                    if let plan = finishStepPlan {
                        VStack(spacing: 24) {
                            Text(plan.reason == .event ? "Your First Smart Alarm" : "No Events Tomorrow!")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(WPStyles.primaryText)
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 12) {
                                if plan.reason == .event {
                                    if let title = plan.targetEvent?.title, !title.isEmpty {
                                        Text(title)
                                            .font(.headline)
                                            .foregroundStyle(WPStyles.primaryText)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                    
                                    let isTomorrow = Calendar.current.isDateInTomorrow(plan.calculatedWakeTime)
                                    let isToday = Calendar.current.isDateInToday(plan.calculatedWakeTime)
                                    
                                    Text(isToday ? "Today" : (isTomorrow ? "Tomorrow" : plan.calculatedWakeTime.formatted(.dateTime.weekday(.wide))))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(WPStyles.secondaryText)
                                        .textCase(.uppercase)
                                        .padding(.bottom, -8)
                                    
                                    Text(plan.calculatedWakeTime.formatted(date: .omitted, time: .shortened))
                                        .font(WPStyles.timeDisplayFont)
                                        .minimumScaleFactor(0.8)
                                        .foregroundStyle(WPStyles.primaryOrange)
                                        .lineLimit(1)
                                } else {
                                    Text("Enjoy sleeping in!")
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.secondaryText)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(28)
                            .frame(maxWidth: .infinity)
                            .background(WPStyles.surface)
                            .clipShape(RoundedRectangle(cornerRadius: WPStyles.cardCornerRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: WPStyles.cardCornerRadius, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
                        }
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .move(edge: .top))))
                    } else {
                        VStack(spacing: 16) {
                            Text("You're All Set!")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundStyle(WPStyles.primaryText)
                                .multilineTextAlignment(.center)

                            Text("We couldn't check tomorrow yet, but you can finish and adjust things from the dashboard.")
                                .font(.body)
                                .foregroundStyle(WPStyles.secondaryText)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .transition(.opacity)
                    }
                } else if finishPhase >= 4 {
                    if finishStepPlan != nil {
                        VStack(spacing: 28) {
                            Text("Set a fixed alarm for days without morning events.")
                                .font(.body.weight(.medium))
                                .multilineTextAlignment(finishPhase == 4 ? .center : .leading)
                                .foregroundStyle(WPStyles.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .scaleEffect(finishPhase == 4 ? 1.08 : 1.0, anchor: finishPhase == 4 ? .center : .leading)
                                .frame(maxWidth: .infinity, alignment: finishPhase == 4 ? .center : .leading)
                                .padding(.horizontal, finishPhase == 4 ? 12 : 0)
                                .padding(.top, finishPhase == 4 ? 40 : 0)

                            if finishPhase >= 5 {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Fixed Alarms")
                                        .font(.headline)
                                        .foregroundStyle(WPStyles.primaryText)
                                    
                                    scheduleCard
                                }
                                .cardStyle()
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        VStack(spacing: 16) {
                            Text("You're All Set!")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundStyle(WPStyles.primaryText)
                                .multilineTextAlignment(.center)

                            Text("We couldn't check tomorrow yet, but you can finish and adjust things from the dashboard.")
                                .font(.body)
                                .foregroundStyle(WPStyles.secondaryText)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .transition(.opacity)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        } footer: {
            if finishPhase >= 5 {
                nextButton(title: "Finish & Go to Dashboard") {
                    finish()
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if finishPhase >= 3 && finishStepPlan == nil {
                nextButton(title: "Finish & Go to Dashboard") {
                    finish()
                }
            } else {
                Color.clear.frame(height: 56)
            }
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    finishPhase = 1
                }
                
                try? await Task.sleep(for: .milliseconds(1800))
                guard !Task.isCancelled else { return }
                
                withAnimation(.easeOut(duration: 0.4)) {
                    finishPhase = 2
                }
                
                await appState.refreshPlan()
                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled else { return }
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    finishPhase = 3
                }
                
                try? await Task.sleep(for: .milliseconds(2500))
                guard !Task.isCancelled else { return }
                
                if finishStepPlan != nil {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        finishPhase = 4
                    }
                    
                    try? await Task.sleep(for: .milliseconds(2800))
                    guard !Task.isCancelled else { return }
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        finishPhase = 5
                    }
                }
            }
        }
    }
    
    private var scheduleCard: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
            spacing: 8
        ) {
            ForEach(WakePlanUIConfiguration.sundayFirstWeekdays) { option in
                weekdayCell(option)
            }
        }
    }
    
    private func weekdayCell(_ option: WeekdayOption) -> some View {
        let isEnabled = appState.preferences.fallbackEnabledDays.contains(option.weekday)

        return Button { selectedWeekday = option } label: {
            VStack(spacing: 8) {
                Text(option.shortLabel).font(.system(size: 9, weight: .bold))
                Circle()
                    .fill(isEnabled ? WPStyles.primaryOrange : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isEnabled ? WPStyles.surfaceRaised : WPStyles.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isEnabled ? WPStyles.primaryOrange.opacity(0.8) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .foregroundStyle(isEnabled ? WPStyles.primaryText : WPStyles.secondaryText.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Components & Bindings
    
    private func onboardingPage<Content: View, Footer: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        let builtContent = content()
        let builtFooter = footer()
        
        return GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 28) {
                    builtContent
                }
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, topContentInset(for: geometry.size.height))
                
                Spacer(minLength: 24)
                
                builtFooter
                    .frame(maxWidth: 340)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    private func permissionRow(
        title: String,
        icon: String,
        isGranted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            permissionLabel(title: title, icon: icon)
            Spacer(minLength: 12)
            permissionTrailingControl(
                isGranted: isGranted,
                actionTitle: actionTitle,
                action: action
            )
        }
    }
    
    private func nextButton(title: String, color: Color = WPStyles.primaryOrange, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color)
                .clipShape(Capsule())
                .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .padding(.bottom, 24)
    }
    
    private func permissionLabel(title: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 32)
            
            Text(title)
                .font(.headline)
                .foregroundStyle(WPStyles.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func permissionTrailingControl(
        isGranted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(WPStyles.primaryOrange)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private func calendarSourceRow(
        title: String,
        subtitle: String?,
        icon: String,
        isConnected: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer(minLength: 12)
            sourceTrailingControl(isConnected: isConnected, actionTitle: actionTitle, action: action)
        }
    }
    
    private func sourceTrailingControl(
        isConnected: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(WPStyles.primaryOrange)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private func topContentInset(for screenHeight: CGFloat) -> CGFloat {
        min(max(screenHeight * 0.3, 260), 340)
    }

    private var finishStepPlan: WakeUpPlan? {
        appState.tomorrowPlanPreview
    }

    private func finishStepHeadline(for plan: WakeUpPlan) -> Text {
        let timeString = plan.calculatedWakeTime.formatted(date: .omitted, time: .shortened)

        switch plan.reason {
        case .event:
            if let title = plan.targetEvent?.title, !title.isEmpty {
                return Text(title)
            }
            return Text("Tomorrow's alarm is ") + Text(timeString).bold() + Text(".")
        case .fallback, .manualOverride:
            return Text("Fixed alarm at ") + Text(timeString).bold() + Text(".")
        case .authorizationMissing:
            return Text("Alarm access is still off.")
        case .noSchedule, .inactiveDay:
            return Text("No alarm for tomorrow.")
        case .disabled, .systemDisabled:
            return Text("Automatic alarms are currently paused.")
        }
    }

    private func finishStepDetail(for plan: WakeUpPlan) -> String? {
        switch plan.reason {
        case .event:
            return "Alarm \(plan.calculatedWakeTime.formatted(date: .omitted, time: .shortened))"
        case .fallback, .manualOverride:
            return nil
        case .authorizationMissing:
            return nil
        case .noSchedule, .inactiveDay:
            return nil
        case .disabled, .systemDisabled:
            return nil
        }
    }

    private func statusBanner(_ text: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(WPStyles.primaryText)
                .fixedSize(horizontal: false, vertical: true)
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
    
    private var hasAppleCalendarSource: Bool {
        appState.permissions.calendar == .authorized
            && (appState.accounts.first { $0.id == AppleCalendarProvider.appleAccountID }?.isEnabled ?? false)
    }
    
    private var connectedGoogleAccounts: [ConnectedCalendarAccount] {
        appState.accounts.filter { $0.provider == .google && $0.isEnabled }
    }
    
    private var hasGoogleCalendarSource: Bool {
        !connectedGoogleAccounts.isEmpty
    }
    
    private var hasAnyCalendarSource: Bool {
        hasAppleCalendarSource || hasGoogleCalendarSource
    }
    
    private var googleCalendarSubtitle: String {
        switch connectedGoogleAccounts.count {
        case 0:
            return "Sync events from a Google account"
        case 1:
            return connectedGoogleAccounts[0].displayName
        default:
            return "\(connectedGoogleAccounts.count) Google accounts connected"
        }
    }
    
    private func routineRow(title: String, icon: String, value: Int, binding: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 24)
            Text(title)
                .font(.body)
                .foregroundStyle(WPStyles.primaryText)
                .lineLimit(1)
                .layoutPriority(1)
            
            Spacer()
            
            Stepper(
                "",
                value: binding,
                in: 0...180,
                step: 5
            )
            .labelsHidden()
            
            Text("\(value)m")
                .font(.body.monospacedDigit())
                .foregroundStyle(WPStyles.secondaryText)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private var prepTimeBinding: Binding<Int> {
        Binding(
            get: { appState.preferences.defaultAlarmRule.prepTime.rawValue },
            set: { v in
                var copy = appState.preferences
                let minutes = Minutes(v)
                copy.prepTime = minutes
                if let idx = copy.alarmRules.firstIndex(where: { $0.isDefault }) {
                    copy.alarmRules[idx].prepTime = minutes
                }
                Task { await appState.updatePreferences(copy) }
            }
        )
    }
    
    private var commuteTimeBinding: Binding<Int> {
        Binding(
            get: { appState.preferences.defaultAlarmRule.commuteTime.rawValue },
            set: { v in
                var copy = appState.preferences
                let minutes = Minutes(v)
                copy.defaultCommuteTime = minutes
                if let idx = copy.alarmRules.firstIndex(where: { $0.isDefault }) {
                    copy.alarmRules[idx].commuteTime = minutes
                }
                Task { await appState.updatePreferences(copy) }
            }
        )
    }
    
    private func finish() {
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }

    private func advanceToNextStep() {
        let nextStep = min(currentStep + 1, totalSteps - 1)
        withAnimation {
            currentStep = nextStep
        }
    }
}
