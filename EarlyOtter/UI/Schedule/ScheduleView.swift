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
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
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
        let accent: Color = autoEnabled ? WPStyles.primaryOrange
            : isFixed ? WPStyles.primaryOrange.opacity(0.55)
            : WPStyles.tertiaryText.opacity(0.3)

        return Button {
            selectedWeekday = option
        } label: {
            HStack(spacing: 14) {
                Capsule()
                    .fill(accent)
                    .frame(width: 4, height: 30)

                Text(option.fullLabel)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(isOff ? WPStyles.tertiaryText : WPStyles.primaryText)

                Spacer(minLength: 8)

                dayTrailing(weekday: weekday, autoEnabled: autoEnabled, isFixed: isFixed)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WPStyles.tertiaryText)
            }
            .padding(.vertical, 14)
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
            // A fixed backup time exists — show it.
            Text(fixedTimeString(for: weekday))
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(WPStyles.primaryOrange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else if autoEnabled {
            // Auto alarms on, but no backup — flag the missing fallback.
            crossedAlarm
        } else {
            // Nothing scheduled this day.
            Image(systemName: "moon.zzz.fill")
                .font(.title3)
                .foregroundStyle(WPStyles.tertiaryText.opacity(0.7))
        }
    }

    // A crossed-out alarm (no SF Symbol exists for this, so we compose it).
    private var crossedAlarm: some View {
        Image(systemName: "alarm.fill")
            .font(.title3)
            .foregroundStyle(WPStyles.secondaryText)
            .overlay {
                Capsule()
                    .fill(WPStyles.surface)
                    .frame(width: 30, height: 5)
                    .rotationEffect(.degrees(-45))
            }
            .overlay {
                Capsule()
                    .fill(WPStyles.secondaryText)
                    .frame(width: 30, height: 2)
                    .rotationEffect(.degrees(-45))
            }
    }

    @ViewBuilder
    private func dayCardBackground(autoEnabled: Bool, isFixed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        ZStack {
            shape.fill(WPStyles.surface)
            shape.stroke(
                autoEnabled ? WPStyles.primaryOrange.opacity(0.4)
                    : isFixed ? WPStyles.primaryOrange.opacity(0.22)
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
