import SwiftUI

struct WakePlanRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Bindable var appState: AppState
    @State private var selectedTab: MainTab = .home

    var body: some View {
        Group {
            if !appState.hasLoadedInitialState {
                loadingView
            } else if shouldShowOnboarding {
                OnboardingView(
                    appState: appState,
                    onFinish: { hasCompletedOnboarding = true }
                )
            } else {
                mainTabView
            }
        }
        .task {
            await appState.loadIfNeeded()
        }
    }

    private var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(appState: appState)
            }
            .tag(MainTab.home)
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                SettingsView(appState: appState)
            }
            .tag(MainTab.schedule)
            .tabItem {
                Label("Schedule", systemImage: "calendar.badge.clock")
            }

            NavigationStack {
                RulesView(appState: appState)
            }
            .tag(MainTab.rules)
            .tabItem {
                Label("Rules", systemImage: "slider.horizontal.3")
            }

            NavigationStack {
                ManualAlarmListView(appState: appState)
            }
            .tag(MainTab.alarms)
            .tabItem {
                Label("Alarms", systemImage: "alarm.fill")
            }
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

            ProgressView("Preparing WakePlan...")
                .tint(WPStyles.primaryOrange)
                .foregroundStyle(WPStyles.primaryText)
        }
    }
}

private enum MainTab {
    case home
    case schedule
    case rules
    case alarms
}
