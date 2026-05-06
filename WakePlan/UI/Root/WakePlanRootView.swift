import SwiftUI

struct WakePlanRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Bindable var appState: AppState
    @State private var forceOnboardingThisLaunch: Bool
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
                        Task {
                            await appState.load()
                        }
                    }
                )
            } else {
                mainTabView
            }
        }
        .task {
            await appState.loadIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            Task {
                await appState.refreshOnAppOpen()
            }
        }
    }

    private var shouldShowOnboarding: Bool {
        forceOnboardingThisLaunch || !hasCompletedOnboarding
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(appState: appState)
            }
            .tag(MainTab.home)
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                RulesView(appState: appState)
            }
            .tag(MainTab.rules)
            .tabItem { Label("Rules", systemImage: "slider.horizontal.3") }

            NavigationStack {
                SettingsView(appState: appState)
            }
            .tag(MainTab.settings)
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(WPStyles.primaryOrange)
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
    case rules
    case settings
}
