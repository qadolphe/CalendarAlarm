import SwiftUI

// MARK: - Schedule tab (the foundation: weekly wake-up defaults & backup alarms)

struct ScheduleView: View {
    @Bindable var appState: AppState
    @State private var selectedWeekday: WeekdayOption?

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Your Week")
                VStack(spacing: 8) {
                    ForEach(EarlyOtterUIConfiguration.sundayFirstWeekdays) { option in
                        dayRow(option)
                    }
                }

                Text("Standby is your latest wake-up. Earlier events move it earlier.")
                    .font(.footnote)
                    .foregroundStyle(WPStyles.tertiaryText)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedWeekday) { option in
            DaySettingsView(appState: appState, weekdayOption: option)
        }
    }

    // MARK: Weekly day cards

    private func dayRow(_ option: WeekdayOption) -> some View {
        let weekday = option.weekday
        let autoEnabled = appState.preferences.autoAlarmEnabled(on: weekday)
        let isFixed = appState.preferences.fixedAlarmEnabled(on: weekday)
        let isOff = !autoEnabled && !isFixed

        // Left stripe + outline light up when auto alarms drive the day.
        let accent: Color = autoEnabled ? WPStyles.accent
            : isFixed ? WPStyles.accent.opacity(0.55)
            : WPStyles.tertiaryText.opacity(0.3)

        return Button {
            selectedWeekday = option
        } label: {
            HStack(spacing: 14) {
                Capsule()
                    .fill(accent)
                    .frame(width: 4, height: 30)

                Text(option.fullLabel)
                    .font(.headline)
                    .foregroundStyle(isOff ? WPStyles.tertiaryText : WPStyles.primaryText)

                Spacer(minLength: 8)

                dayTrailing(weekday: weekday, autoEnabled: autoEnabled, isFixed: isFixed)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WPStyles.tertiaryText)
            }
            .frame(minHeight: 36)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(dayCardBackground(autoEnabled: autoEnabled, isFixed: isFixed))
            .opacity(isOff ? 0.55 : 1)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dayTrailing(weekday: Int, autoEnabled: Bool, isFixed: Bool) -> some View {
        if isFixed {
            VStack(alignment: .trailing, spacing: 1) {
                Text(fixedTimeString(for: weekday))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WPStyles.primaryText)
                Text("Standby")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WPStyles.secondaryText)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else if autoEnabled {
            Text("Calendar only")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WPStyles.secondaryText)
        } else {
            Label("Off", systemImage: "moon.zzz.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WPStyles.tertiaryText)
        }
    }

    @ViewBuilder
    private func dayCardBackground(autoEnabled: Bool, isFixed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        ZStack {
            shape.fill(WPStyles.surface)
            shape.stroke(
                autoEnabled ? WPStyles.accent.opacity(0.4)
                    : isFixed ? WPStyles.accent.opacity(0.22)
                    : WPStyles.cardBorder.opacity(0.5),
                lineWidth: 1
            )
        }
    }

    // MARK: Small pieces

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(WPStyles.secondaryText)
            .textCase(.uppercase)
    }

    private func fixedTimeString(for weekday: Int) -> String {
        appState.preferences.fallbackWakeTime(for: weekday)
            .date(on: TargetDay(date: Date()))
            .formatted(date: .omitted, time: .shortened)
    }
}
