import SwiftUI

struct RulesView: View {
    @Bindable var appState: AppState

    var body: some View {
        let viewModel = RulesViewModel(appState: appState)

        ZStack {
            Color.clear.withAppBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Alarm Rules & Logic")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(WPStyles.primaryText)
                        .padding(.top, 20)
                    
                    Text("Inspect the exact logic WakePlan applies before it schedules tomorrow's alarm.")
                        .font(.body)
                        .foregroundStyle(WPStyles.secondaryText)

                    rulesSection(
                        title: "Buffer Time",
                        content: {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Wake-up Lead Time")
                                        .font(.body)
                                        .foregroundStyle(WPStyles.primaryText)
                                    Spacer()
                                    Text("\(viewModel.prepTime) min")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(WPStyles.primaryOrange)
                                }

                                ProgressView(value: min(Double(viewModel.prepTime), 120), total: 120)
                                    .tint(WPStyles.primaryOrange)

                                HStack {
                                    Text("0m")
                                    Spacer()
                                    Text("120m")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WPStyles.secondaryText)

                                Text("How long before your first event the alarm should trigger.")
                                    .font(.footnote)
                                    .foregroundStyle(WPStyles.secondaryText)
                            }
                        }
                    )

                    rulesSection(
                        title: "Default Fallback",
                        content: {
                            rulesRow(
                                icon: "schedule",
                                title: "Default Time",
                                subtitle: "Used when no calendar events are found for the day.",
                                trailing: viewModel.fallbackTime
                            )
                        }
                    )

                    rulesSection(
                        title: "Safety Bounds",
                        content: {
                            VStack(spacing: 0) {
                                rulesRow(
                                    icon: "bed.double.fill",
                                    title: "Latest Wake Time",
                                    subtitle: "Prevents oversleeping",
                                    trailing: viewModel.fallbackTime
                                )

                                Divider().overlay(WPStyles.cardBorder).padding(.vertical, 6)

                                rulesRow(
                                    icon: "calendar.badge.clock",
                                    title: "Active Days",
                                    subtitle: "Only runs on enabled days",
                                    trailing: viewModel.activeDaysSummary
                                )
                            }
                        }
                    )

                    rulesSection(
                        title: "Decision Flow",
                        content: {
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
                                    description: "If you have no events, the day is inactive, or the result falls back, WakePlan uses your fallback wake time (\(viewModel.fallbackTime)).",
                                    icon: "bed.double"
                                )
                            }
                        }
                    )
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
                    .foregroundStyle(WPStyles.primaryText)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)
                    .lineSpacing(2)
            }
        }
    }

    private func rulesSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(WPStyles.secondaryText)
                .textCase(.uppercase)

            content()
        }
        .cardStyle()
    }

    private func rulesRow(icon: String, title: String, subtitle: String, trailing: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(WPStyles.surfaceRaised)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(WPStyles.primaryOrange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(WPStyles.primaryText)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(WPStyles.secondaryText)
            }

            Spacer()

            Text(trailing)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(WPStyles.secondaryText)
        }
    }
}

private struct RulesViewModel {
    let defaultCommute: Int
    let prepTime: Int
    let fallbackTime: String
    let activeDaysSummary: String

    @MainActor
    init(appState: AppState) {
        let prefs = appState.preferences
        self.defaultCommute = prefs.defaultCommuteTime.rawValue
        self.prepTime = prefs.prepTime.rawValue
        self.activeDaysSummary = RulesViewModel.describe(activeDays: prefs.activeDays)
        
        let targetDay = TargetDay(date: Date())
        let date = prefs.latestWakeTime.date(on: targetDay)
        self.fallbackTime = date.formatted(date: .omitted, time: .shortened)
    }

    private static func describe(activeDays: Set<Int>) -> String {
        if activeDays.count == 7 {
            return "Every day"
        }

        if activeDays == Set([2, 3, 4, 5, 6]) {
            return "Mon to Fri"
        }

        return "\(activeDays.count) days"
    }
}
