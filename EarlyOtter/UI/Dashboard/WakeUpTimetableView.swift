import SwiftUI

/// A day's alarm as a timetable: the wake-up first, then how it was worked out
/// (prep, commute, event). Used by the Home card.
/// Numbers sit in the left column, labels in the middle, markers on the right.
struct WakeUpTimetableView: View {
    let plan: WakeUpPlan
    /// Shown under the rule when the day has no event to explain the alarm.
    var note: String? = nil

    private let numberColumnWidth: CGFloat = 140

    private var event: ParsedEvent? {
        plan.targetEvent ?? plan.firstEventOfDay
    }

    /// A standard alarm didn't set its time, so say how the event sits against it.
    private func standardAlarmLabel(for event: ParsedEvent) -> String {
        event.startDate < plan.calculatedWakeTime ? String(localized: "Before alarm") : String(localized: "Next event")
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.everyMinute) { context in
                row(
                    title: plan.wakeTitle,
                    subtitle: TimetableFormat.countdown(from: context.date, to: plan.calculatedWakeTime).map { String(localized: "in \($0)", comment: "Time left until the alarm, e.g. in 8h 5m") },
                    isHero: true
                ) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(dayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WPStyles.secondaryText)
                        number(TimetableFormat.clock(plan.calculatedWakeTime), size: 46)
                    }
                } marker: {
                    dot(WPStyles.accent)
                }
            }

            Capsule()
                .fill(WPStyles.primaryText.opacity(0.5))
                .frame(height: 2)

            if let event {
                if plan.reason == .event {
                    row(title: String(localized: "Prep time")) {
                        number(TimetableFormat.duration(plan.prepTime), size: 22, muted: true)
                    } marker: {
                        icon("cup.and.saucer.fill")
                    }
                    Divider()
                    row(title: String(localized: "Commute")) {
                        number(TimetableFormat.duration(plan.commuteTime), size: 22, muted: true)
                    } marker: {
                        icon("car.fill")
                    }
                    Divider()
                }
                // Labelled so a standard alarm isn't mistaken for one set by this event.
                row(title: event.title, subtitle: plan.reason == .alarm ? standardAlarmLabel(for: event) : event.location) {
                    number(TimetableFormat.clock(event.startDate), size: 22)
                } marker: {
                    dot(WPStyles.eventTint)
                }
            } else {
                Label(note ?? emptyEventsText, systemImage: "moon.zzz.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WPStyles.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// A standard alarm's day has no events; a calendar alarm had nothing early enough.
    private var emptyEventsText: String {
        guard plan.reason == .alarm else { return String(localized: "No early events") }
        let calendar = Calendar.current
        let wake = plan.calculatedWakeTime
        if calendar.isDateInToday(wake) { return String(localized: "No events today") }
        if calendar.isDateInTomorrow(wake) { return String(localized: "No events tomorrow") }
        return String(localized: "No events on \(wake.formatted(.dateTime.weekday(.wide)))")
    }

    /// "Today", "Tomorrow", or the weekday.
    private var dayName: String {
        let calendar = Calendar.current
        let wake = plan.calculatedWakeTime
        if calendar.isDateInToday(wake) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(wake) { return String(localized: "Tomorrow") }
        return wake.formatted(.dateTime.weekday(.wide))
    }

    private func row<Number: View, Marker: View>(
        title: String,
        subtitle: String? = nil,
        isHero: Bool = false,
        @ViewBuilder number: () -> Number,
        @ViewBuilder marker: () -> Marker
    ) -> some View {
        // The hero label sits on the big number's baseline; other rows center.
        HStack(alignment: isHero ? .lastTextBaseline : .center, spacing: 0) {
            number()
                .frame(width: numberColumnWidth, alignment: .leading)
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isHero ? .headline : .subheadline.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(WPStyles.secondaryText)
                }
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            marker()
                .frame(width: 20)
                // On the hero row, center the marker on the numerals rather than the baseline.
                .alignmentGuide(.lastTextBaseline) { $0[VerticalAlignment.center] + 16 }
        }
        .padding(.vertical, isHero ? 6 : 11)
        .padding(.bottom, isHero ? 8 : 0)
    }

    /// A number with its unit set smaller beside it, e.g. "7:55 AM" or "45 min".
    /// One `Text`, so the pair scales down together when space is tight.
    private func number(_ parts: TimetableFormat.Parts, size: CGFloat, muted: Bool = false) -> some View {
        let value = Text(parts.value)
            .font(.system(size: size, weight: muted ? .semibold : .bold, design: .rounded))
            .foregroundStyle(muted ? WPStyles.secondaryText : WPStyles.primaryText)
        let unit = Text(parts.unit.map { " " + $0 } ?? "")
            .font(.system(size: size > 30 ? 17 : 12, weight: .semibold, design: .rounded))
            .foregroundStyle(WPStyles.tertiaryText)

        return Text("\(value)\(unit)")
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .background(Circle().fill(color.opacity(0.18)).padding(-5))
    }

    private func icon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.subheadline)
            .foregroundStyle(WPStyles.tertiaryText)
    }
}

/// Splits times and durations into a value and a smaller unit for the timetable.
enum TimetableFormat {
    struct Parts: Equatable {
        let value: String
        let unit: String?
    }

    /// "7:55" + "AM"; no unit in 24-hour locales.
    static func clock(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> Parts {
        let value = date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute().locale(locale))
        let uses12Hour = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale)?.contains("a") ?? false
        guard uses12Hour else { return Parts(value: value, unit: nil) }
        let isMorning = calendar.component(.hour, from: date) < 12
        return Parts(value: value, unit: isMorning ? calendar.amSymbol : calendar.pmSymbol)
    }

    /// "45" + "min", or "1:30" + "hr" from an hour up.
    static func duration(_ minutes: Minutes) -> Parts {
        let total = minutes.rawValue
        guard total >= 60 else { return Parts(value: "\(total)", unit: String(localized: "min", comment: "Minutes unit")) }
        let value = total % 60 == 0 ? "\(total / 60)" : String(format: "%d:%02d", total / 60, total % 60)
        return Parts(value: value, unit: String(localized: "hr", comment: "Hours unit"))
    }

    /// "14h 3m" until the alarm, or nil once it has passed.
    static func countdown(from now: Date, to date: Date) -> String? {
        let interval = date.timeIntervalSince(now)
        guard interval >= 60 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: interval)
    }
}
