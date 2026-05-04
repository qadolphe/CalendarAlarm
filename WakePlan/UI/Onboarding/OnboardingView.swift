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
                googleStep.tag(2)
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
                    .font(.title2.weight(.medium))
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                
                Text(AppConfiguration.appName)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(WPStyles.primaryOrange)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                Text("Your alarm, perfectly synced with your morning schedule.")
                    .font(.body)
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
                    .font(.title.weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("EarlyOtter needs access to your calendars to scan your schedule, and notifications to wake you up.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 16) {
                permissionRow(
                    title: "Apple Calendar",
                    icon: "calendar",
                    isGranted: appState.permissions.calendar == .authorized,
                    action: { Task { await appState.requestCalendarAccess() } }
                )
                
                permissionRow(
                    title: "Alarms & Notifications",
                    icon: "bell.fill",
                    isGranted: appState.permissions.alarm == .authorized,
                    action: { Task { await appState.requestAlarmAccess() } }
                )
            }
            .cardStyle()
        } footer: {
            let bothGranted = appState.permissions.calendar == .authorized && appState.permissions.alarm == .authorized
            
            nextButton(title: bothGranted ? "Next" : "Grant Access to Continue") {
                withAnimation { currentStep += 1 }
            }
            .disabled(!bothGranted)
            .opacity(bothGranted ? 1.0 : 0.5)
        }
    }
    
    private var googleStep: some View {
        onboardingPage {
            ZStack {
                Circle()
                    .fill(WPStyles.surfaceRaised)
                    .frame(width: 100, height: 100)
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(WPStyles.primaryOrange)
            }
            
            VStack(spacing: 12) {
                Text("Google Calendar")
                    .font(.title.weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Do you use Google Calendar? You can connect it now to perfectly sync your schedule.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            VStack(spacing: 12) {
                Button(action: {
                    withAnimation { currentStep += 1 }
                }) {
                    Text("Connect Google Account")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(WPStyles.primaryOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                Button("Skip for now") {
                    withAnimation { currentStep += 1 }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WPStyles.secondaryText)
                .padding()
            }
        }
    }
    
    private var routineStep: some View {
        onboardingPage {
            VStack(spacing: 12) {
                Text("Your Default Routine")
                    .font(.title.weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("How long does it typically take you to get ready and commute? We'll subtract this from your first event.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 20) {
                routineRow(
                    title: "Prep Time",
                    icon: "cup.and.saucer.fill",
                    value: appState.preferences.defaultAlarmRule.prepTime.rawValue,
                    binding: prepTimeBinding
                )
                
                routineRow(
                    title: "Commute Time",
                    icon: "car.fill",
                    value: appState.preferences.defaultAlarmRule.commuteTime.rawValue,
                    binding: commuteTimeBinding
                )
            }
            .padding()
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
                    .font(.title.weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("EarlyOtter is now analyzing your calendar and scheduling your first smart alarm.")
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
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            
            VStack(spacing: 28) {
                content()
            }
            .frame(maxWidth: 380)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            footer()
                .frame(maxWidth: 380)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func permissionRow(title: String, icon: String, isGranted: Bool, action: @escaping () -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                permissionLabel(title: title, icon: icon)
                Spacer(minLength: 12)
                permissionTrailingControl(isGranted: isGranted, action: action)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                permissionLabel(title: title, icon: icon)
                permissionTrailingControl(isGranted: isGranted, action: action)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func nextButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(WPStyles.primaryOrange)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(WPStyles.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(WPStyles.surfaceRaised)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private func routineRow(title: String, icon: String, value: Int, binding: Binding<Int>) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(WPStyles.primaryOrange)
                        .frame(width: 24)
                    Text(title)
                        .foregroundStyle(WPStyles.primaryText)
                }
                
                Spacer(minLength: 8)
                
                Stepper("", value: binding, in: 0...180, step: 5)
                    .labelsHidden()
                    .background(WPStyles.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("\(value)m")
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryOrange)
                    .frame(width: 45, alignment: .trailing)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(WPStyles.primaryOrange)
                        .frame(width: 24)
                    Text(title)
                        .foregroundStyle(WPStyles.primaryText)
                }
                
                HStack(spacing: 12) {
                    Stepper("", value: binding, in: 0...180, step: 5)
                        .labelsHidden()
                        .background(WPStyles.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Text("\(value)m")
                        .font(.headline)
                        .foregroundStyle(WPStyles.primaryOrange)
                        .frame(width: 45, alignment: .trailing)
                }
            }
        }
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
