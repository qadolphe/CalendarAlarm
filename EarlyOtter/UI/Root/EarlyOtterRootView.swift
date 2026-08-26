import StoreKit
import SwiftUI

struct EarlyOtterRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppConfiguration.reviewPromptQualifiedOpenCountStorageKey)
    private var reviewPromptQualifiedOpenCount = 0
    @AppStorage(AppConfiguration.reviewPromptLastRequestedVersionStorageKey)
    private var reviewPromptLastRequestedVersion = ""
    @Bindable var appState: AppState
    @State private var forceOnboardingThisLaunch: Bool
    @State private var hasEvaluatedReviewPromptThisLaunch = false
    @State private var selectedTab: MainTab = .home

    init(appState: AppState) {
        self.appState = appState
        _forceOnboardingThisLaunch = State(
            initialValue: LaunchArguments.allForceOnboarding.contains {
                ProcessInfo.processInfo.arguments.contains($0)
            }
        )
    }

    var body: some View {
        Group {
            if !appState.hasLoadedInitialState {
                loadingView
            } else if shouldShowOnboarding {
                OnboardingView(
                    appState: appState,
                    onFinish: {
                        hasCompletedOnboarding = true
                        forceOnboardingThisLaunch = false
                    }
                )
            } else {
                mainTabView
            }
        }
        .task {
            await appState.loadIfNeeded()
            await evaluateReviewPrompt()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            guard appState.hasLoadedInitialState else { return }
            guard !shouldShowOnboarding else { return }

            Task {
                await appState.refreshOnAppOpen()
            }
        }
        .alert(
            "Action Required",
            isPresented: Binding(
                get: { appState.settingsAlertMessage != nil },
                set: { if !$0 { appState.settingsAlertMessage = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                appState.openSettings()
            }
        } message: {
            if let message = appState.settingsAlertMessage {
                Text(message)
            }
        }
    }

    private var shouldShowOnboarding: Bool {
        forceOnboardingThisLaunch || !hasCompletedOnboarding
    }

    @MainActor
    private func evaluateReviewPrompt() async {
        guard !hasEvaluatedReviewPromptThisLaunch else { return }
        hasEvaluatedReviewPromptThisLaunch = true

        let evaluation = AppReviewPromptPolicy.evaluate(
            qualifiedOpenCount: reviewPromptQualifiedOpenCount,
            lastRequestedVersion: reviewPromptLastRequestedVersion,
            currentVersion: AppConfiguration.currentAppVersion,
            isQualifiedOpen: !shouldShowOnboarding && hasScheduledAlarm
        )
        reviewPromptQualifiedOpenCount = evaluation.qualifiedOpenCount

        guard evaluation.shouldRequestReview else { return }

        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled,
              scenePhase == .active,
              selectedTab == .home else {
            return
        }

        reviewPromptQualifiedOpenCount = 0
        reviewPromptLastRequestedVersion = AppConfiguration.currentAppVersion
        requestReview()
    }

    private var hasScheduledAlarm: Bool {
        appState.alarmStatusesByPlanID.values.contains { status in
            if case .scheduled = status {
                return true
            }
            return false
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(appState: appState, onOpenSchedule: { selectedTab = .schedule })
            }
            .tag(MainTab.home)
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                ScheduleView(appState: appState)
            }
            .tag(MainTab.schedule)
            .tabItem { Label("Schedule", systemImage: "calendar") }

            NavigationStack {
                RulesView(appState: appState)
            }
            .tag(MainTab.rules)
            .tabItem { Label("Rules", systemImage: "gearshape.fill") }
        }
        .tint(WPStyles.tabSelection)
        .toolbarBackground(WPStyles.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    private var loadingView: some View {
        ZStack {
            Color.clear
                .withAppBackground()
                .ignoresSafeArea()

            ProgressView("Preparing EarlyOtter...")
                .tint(WPStyles.primaryOrange)
                .foregroundStyle(WPStyles.primaryText)
        }
    }
}

private enum MainTab {
    case home
    case schedule
    case rules
}
