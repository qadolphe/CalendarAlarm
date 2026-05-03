import SwiftUI

struct OnboardingView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    var onFinish: (() -> Void)? = nil
    
    @State private var currentStep = 0
    private let totalSteps = 5
    
    var body: some View {
        ZStack {
            Color.clear.withAppBackground()
            
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
    
    // MARK: - Steps
    
    private var welcomeStep: some View {
        VStack(spacing: 28) {
            Spacer()
            
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(WPStyles.surfaceRaised)
                        .frame(width: 132, height: 132)
                    Image(systemName: "alarm.waves.left.and.right.fill")
                        .font(.system(size: 62))
                        .foregroundStyle(WPStyles.primaryOrange)
                }
                
                VStack(spacing: 10) {
                    Text("Welcome to \(AppConfiguration.appName)")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(WPStyles.primaryText)
                    Text("Your alarm, perfectly synced with your morning schedule.")
                        .font(.body)
                        .foregroundStyle(WPStyles.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            nextButton(title: "Get Started") {
                withAnimation { currentStep += 1 }
            }
        }
        .padding(20)
    }
    
    private var permissionsStep: some View {
        VStack(spacing: 28) {
            Spacer()
            
            VStack(spacing: 12) {
                Text("Core Access")
                    .font(.title.weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                
                Text("EarlyOtter needs access to your calendars to scan your schedule, and notifications to wake you up.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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
            
            Spacer()
            
            let bothGranted = appState.permissions.calendar == .authorized && appState.permissions.alarm == .authorized
            
            nextButton(title: bothGranted ? "Next" : "Grant Access to Continue") {
                withAnimation { currentStep += 1 }
            }
            .disabled(!bothGranted)
            .opacity(bothGranted ? 1.0 : 0.5)
        }
        .padding(20)
    }
    
    private var googleStep: some View {
        VStack(spacing: 28) {
            Spacer()
            
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
                
                Text("Do you use Google Calendar? You can connect it now to perfectly sync your schedule.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
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
        .padding(20)
    }
    
    private var routineStep: some View {
        VStack(spacing: 28) {
            Spacer()
            
            VStack(spacing: 12) {
                Text("Your Default Routine")
                    .font(.title.weight(.bold))
                    .foregroundStyle(WPStyles.primaryText)
                
                Text("How long does it typically take you to get ready and commute? We'll subtract this from your first event.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundStyle(WPStyles.primaryOrange)
                        .frame(width: 24)
                    Text("Prep Time")
                        .foregroundStyle(WPStyles.primaryText)
                    Spacer()
                    Stepper("", value: prepTimeBinding, in: 0...180, step: 5)
                        .labelsHidden()
                        .background(WPStyles.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("\(appState.preferences.defaultAlarmRule.prepTime.rawValue)m")
                        .font(.headline)
                        .foregroundStyle(WPStyles.primaryOrange)
                        .frame(width: 45, alignment: .trailing)
                }
                
                HStack {
                    Image(systemName: "car.fill")
                        .foregroundStyle(WPStyles.primaryOrange)
                        .frame(width: 24)
                    Text("Commute Time")
                        .foregroundStyle(WPStyles.primaryText)
                    Spacer()
                    Stepper("", value: commuteTimeBinding, in: 0...180, step: 5)
                        .labelsHidden()
                        .background(WPStyles.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("\(appState.preferences.defaultAlarmRule.commuteTime.rawValue)m")
                        .font(.headline)
                        .foregroundStyle(WPStyles.primaryOrange)
                        .frame(width: 45, alignment: .trailing)
                }
            }
            .padding()
            .background(WPStyles.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
            
            Spacer()
            
            nextButton(title: "Next") {
                withAnimation { currentStep += 1 }
            }
        }
        .padding(20)
    }
    
    private var finishStep: some View {
        VStack(spacing: 28) {
            Spacer()
            
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
                
                Text("EarlyOtter is now analyzing your calendar and scheduling your first smart alarm.")
                    .font(.body)
                    .foregroundStyle(WPStyles.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                finish()
            }
        }
    }
    
    // MARK: - Components & Bindings
    
    private func permissionRow(title: String, icon: String, isGranted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 32)
            
            Text(title)
                .font(.headline)
                .foregroundStyle(WPStyles.primaryText)
            
            Spacer()
            
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
