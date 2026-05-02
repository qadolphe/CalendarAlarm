import SwiftUI

struct WakePlanRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Bindable var appState: AppState

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
                DashboardView(appState: appState)
            }
        }
        .task {
            await appState.loadIfNeeded()
        }
    }

    private var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
    }

    private var loadingView: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            ProgressView("Preparing WakePlan...")
                .tint(.orange)
        }
    }
}
