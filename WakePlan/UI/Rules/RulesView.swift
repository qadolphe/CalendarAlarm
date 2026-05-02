import SwiftUI

struct RulesView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = RulesViewModel(appState: appState)

        ZStack {
            WPStyles.bgGradientStart.ignoresSafeArea()
                .withAppBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("WakePlan Rules")
                        .font(.largeTitle.weight(.bold))
                        .padding(.top, 20)
                    
                    Text("How WakePlan decides when you should wake up.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        ruleSection(
                            title: "1. Find First Event",
                            description: "Looks at your selected calendars for the earliest event starting after midnight.",
                            icon: "magnifyingglass"
                        )
                        
                        ruleSection(
                            title: "2. Analyze Event",
                            description: "If the event has an alert, we calculate your commute buffer using the alert time. If no alert, we use the default commute buffer (\(viewModel.defaultCommute) min).",
                            icon: "clock.arrow.circlepath"
                        )
                        
                        ruleSection(
                            title: "3. Apply Prep Time",
                            description: "We subtract your morning prep time (\(viewModel.prepTime) min) from when you need to leave.",
                            icon: "person.crop.circle.badge.clock"
                        )
                        
                        ruleSection(
                            title: "4. Apply Fallback",
                            description: "If you have no events, or if the calculated time is later than your fallback time, WakePlan uses your fallback wake time (\(viewModel.fallbackTime)).",
                            icon: "bed.double"
                        )
                    }
                    .padding(.vertical, 8)
                    .cardStyle()
                }
                .padding(24)
            }
        }
        .navigationTitle("Rules")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func ruleSection(title: String, description: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
    }
}

private struct RulesViewModel {
    let defaultCommute: Int
    let prepTime: Int
    let fallbackTime: String

    @MainActor
    init(appState: AppState) {
        let prefs = appState.preferences
        self.defaultCommute = prefs.defaultCommuteTime.rawValue
        self.prepTime = prefs.prepTime.rawValue
        
        let targetDay = TargetDay(date: Date())
        let date = prefs.latestWakeTime.date(on: targetDay)
        self.fallbackTime = date.formatted(date: .omitted, time: .shortened)
    }
}
