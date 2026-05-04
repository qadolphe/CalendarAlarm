import SwiftUI

struct OnboardingView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    var onFinish: (() -> Void)? = nil
    
    @State private var currentStep = 0
    private let totalSteps = 5
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.clear.withAppBackground()
            
            persistentBackground
            
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                permissionsStep.tag(1)
                calendarStep.tag(2)
                routineStep.tag(3)
                finishStep.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
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
                withAnimation { currentStep += 1 }
            }
        }
    }
    
    private var permissionsStep: some View {
        onboardingPage {
            VStack(spacing: 12) {
                Text("Core Access")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("We need alarm and notification access to wake you up reliably.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 16) {
                permissionRow(
                    title: "Alarms & Notifications",
                    icon: "bell.fill",
                    isGranted: appState.permissions.alarm == .authorized,
                    action: { Task { await appState.requestAlarmAccess() } }
                )
            }
            .cardStyle()
        } footer: {
            let alarmGranted = appState.permissions.alarm == .authorized
            
            nextButton(title: alarmGranted ? "Next" : "Grant Access to Continue") {
                withAnimation { currentStep += 1 }
            }
            .disabled(!alarmGranted)
            .opacity(alarmGranted ? 1.0 : 0.5)
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
                    actionTitle: "Connect",
                    action: { Task { await appState.addGoogleAccount() } }
                )
            }
            .cardStyle()
        } footer: {
            nextButton(title: hasAnyCalendarSource ? "Next" : "Add a Calendar to Continue") {
                withAnimation { currentStep += 1 }
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
                    title: "Prep Time",
                    icon: "cup.and.saucer.fill",
                    value: appState.preferences.defaultAlarmRule.prepTime.rawValue,
                    binding: prepTimeBinding
                )
                
                Divider().overlay(WPStyles.cardBorder).padding(.leading, 16)
                
                routineRow(
                    title: "Commute Time",
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
                withAnimation { currentStep += 1 }
            }
        }
    }
    
    private var finishStep: some View {
        onboardingPage {
            ZStack {
                Circle()
                    .fill(WPStyles.primaryOrange.opacity(0.15))
                    .frame(width: 132, height: 132)
                Image(systemName: "checkmark")
                    .font(.system(size: 62, weight: .bold))
                    .foregroundStyle(WPStyles.primaryOrange)
            }
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("We are analyzing your calendar and scheduling your first smart alarm.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            EmptyView()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                finish()
            }
        }
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
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, topContentInset(for: geometry.size.height))
                
                Spacer(minLength: 24)
                
                builtFooter
                    .frame(maxWidth: 320)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    private func permissionRow(title: String, icon: String, isGranted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            permissionLabel(title: title, icon: icon)
            Spacer(minLength: 12)
            permissionTrailingControl(isGranted: isGranted, action: action)
        }
    }
    
    private func nextButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(WPStyles.primaryOrange)
                .clipShape(Capsule())
                .shadow(color: WPStyles.primaryOrange.opacity(0.2), radius: 8, x: 0, y: 4)
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
    
    private func permissionTrailingControl(isGranted: Bool, action: @escaping () -> Void) -> some View {
        Group {
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                Button(action: action) {
                    Text("Grant")
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(WPStyles.primaryText)
            
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
                .frame(width: 45, alignment: .trailing)
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
}
