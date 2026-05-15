import SwiftUI
import WidgetKit

struct NextAlarmWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: NextAlarmWidgetSnapshot
}

struct NextAlarmWidgetProvider: TimelineProvider {
    private let snapshotStore = UserDefaultsNextAlarmWidgetSnapshotStore()

    func placeholder(in context: Context) -> NextAlarmWidgetEntry {
        makeEntry(snapshot: Self.previewSnapshot, now: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (NextAlarmWidgetEntry) -> Void) {
        let now = Date()
        let snapshot = context.isPreview ? Self.previewSnapshot : loadSnapshot(now: now)
        completion(makeEntry(snapshot: snapshot, now: now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = loadSnapshot(now: now)
        completion(Timeline(entries: [makeEntry(snapshot: snapshot, now: now)], policy: .after(nextRefreshDate(for: snapshot, from: now))))
    }

    private func makeEntry(snapshot: NextAlarmWidgetSnapshot, now: Date) -> NextAlarmWidgetEntry {
        NextAlarmWidgetEntry(date: now, snapshot: snapshot)
    }

    private func loadSnapshot(now: Date) -> NextAlarmWidgetSnapshot {
        (try? snapshotStore.load()) ?? .empty(detailText: "Open EarlyOtter", lastUpdatedAt: now)
    }

    private func nextRefreshDate(for snapshot: NextAlarmWidgetSnapshot, from now: Date) -> Date {
        let defaultRefreshDate = now.addingTimeInterval(30 * 60)
        guard let nextAlarmDate = snapshot.nextAlarmDate, nextAlarmDate > now else {
            return defaultRefreshDate
        }
        return min(defaultRefreshDate, nextAlarmDate.addingTimeInterval(60))
    }

    private static let previewSnapshot = NextAlarmWidgetSnapshot.scheduled(
        nextAlarmDate: Date().addingTimeInterval(75 * 60),
        eventTitle: "Design Review",
        context: Date().addingTimeInterval(2 * 60 * 60).formatted(date: .omitted, time: .shortened),
        detailText: nil,
        lastUpdatedAt: Date()
    )
}

struct NextAlarmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfiguration.nextAlarmWidgetKind, provider: NextAlarmWidgetProvider()) { entry in
            NextAlarmWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Alarm")
        .description("Keep your next wake-up alarm visible on Home, Lock Screen, and StandBy.")
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct NextAlarmWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextAlarmWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: smallView
            case .accessoryInline: inlineView
            case .accessoryCircular: circularView
            case .accessoryRectangular: rectangularView
            default: smallView
            }
        }
        .containerBackground(for: .widget) {
            containerBackgroundView
        }
    }

    private var smallView: some View {
        ZStack(alignment: .center) {
            Text("🦦")
                .font(.system(size: 64))
                .opacity(0.12)
                .rotationEffect(.degrees(15))
                .offset(x: 35, y: -10)
                
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: stateIconName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WidgetTheme.primaryOrange)
                    Text(entry.snapshot.state == .empty ? "EarlyOtter" : "Next Alarm")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(WidgetTheme.primaryText)
                }

                Spacer(minLength: 0)

                alarmValue(font: .system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if entry.snapshot.state != .empty {
                    if let title = entry.snapshot.eventTitle {
                        Text(title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(WidgetTheme.secondaryText)
                            .lineLimit(1)
                    } else if let footer = footerSummary {
                        Text(footer)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(WidgetTheme.secondaryText)
                            .lineLimit(1)
                    }
                } else if let footer = footerSummary {
                    Text(footer)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(WidgetTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var inlineView: some View {
        Group {
            if let alarmDate = entry.snapshot.nextAlarmDate, entry.snapshot.state != .empty {
                Text("\(Image(systemName: stateIconName)) \(formattedInlineAlarmTime(for: alarmDate))")
                    .font(.headline)
            } else {
                Text(inlineFallbackText)
            }
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let alarmDate = entry.snapshot.nextAlarmDate, entry.snapshot.state != .empty {
                VStack(spacing: 1) {
                    Image(systemName: stateIconName)
                        .font(.caption2.weight(.bold))
                        .widgetAccentable()
                    Text(formattedCircularAlarmTime(for: alarmDate))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                }
                .padding(4)
            } else {
                Image(systemName: "alarm.slash")
                    .font(.title3)
                    .widgetAccentable()
            }
        }
    }

    private var rectangularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: stateIconName)
                    .font(.body.weight(.semibold))
                    .widgetAccentable()

                VStack(alignment: .leading, spacing: 2) {
                    if let alarmDate = entry.snapshot.nextAlarmDate, entry.snapshot.state != .empty {
                        Text(formattedRectangularAlarmTime(for: alarmDate))
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .widgetAccentable()
                    } else {
                        Text(stateDescription)
                            .font(.subheadline)
                            .lineLimit(1)
                            .widgetAccentable()
                    }

                    Group {
                        if let title = entry.snapshot.eventTitle {
                            Text(title).font(.caption2.weight(.semibold)).lineLimit(1)
                        } else {
                            Text("Next Alarm").font(.caption2.weight(.semibold)).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var containerBackgroundView: some View {
        Group {
            switch family {
            case .systemSmall:
                ZStack {
                    LinearGradient(
                        colors: [WidgetTheme.bgGradientStart, WidgetTheme.bgGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle()
                        .fill(WidgetTheme.primaryOrange.opacity(0.14))
                        .frame(width: 150, height: 150)
                        .blur(radius: 30)
                        .offset(x: 40, y: -40)
                }
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var titleLabel: some View {
        if entry.snapshot.state == .empty {
            Text("EarlyOtter")
        } else if let title = entry.snapshot.eventTitle {
            Text(title).lineLimit(1)
        } else {
            Text("Next Alarm")
        }
    }

    @ViewBuilder
    private func alarmValue(font: Font) -> some View {
        if let alarmDate = entry.snapshot.nextAlarmDate, entry.snapshot.state != .empty {
            Text(formattedAlarmTime(for: alarmDate))
                .font(font)
                .minimumScaleFactor(0.7)
        } else {
            Text(stateDescription)
                .font(font)
                .minimumScaleFactor(0.7)
        }
    }

    private var stateIconName: String {
        switch entry.snapshot.state {
        case .scheduled: return "alarm.fill"
        case .empty: return "moon.zzz.fill"
        case .stale: return "exclamationmark.arrow.circlepath"
        }
    }

    private var stateDescription: String {
        switch entry.snapshot.state {
        case .scheduled: return "Scheduled"
        case .empty: return "No Alarms"
        case .stale: return "Stale"
        }
    }

    private var inlineFallbackText: String {
        switch entry.snapshot.state {
        case .empty: return "Open EarlyOtter"
        case .stale: return "Refresh App"
        default: return "No Alarm"
        }
    }

    private var footerSummary: String? {
        if entry.snapshot.state == .empty { return entry.snapshot.detailText }
        if let detail = entry.snapshot.detailText { return detail }
        if let context = entry.snapshot.context { return context }
        return nil
    }

    private func formattedAlarmTime(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func formattedInlineAlarmTime(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func formattedCircularAlarmTime(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func formattedRectangularAlarmTime(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

// Using literal copies of app theme to match NextAlarmWidgetExtension without explicit bundle file sharing
private enum WidgetTheme {
    static let primaryOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let bgGradientStart = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let bgGradientEnd = Color(red: 0.11, green: 0.11, blue: 0.11)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let primaryText = Color(red: 0.89, green: 0.89, blue: 0.89)
    static let secondaryText = Color(red: 0.85, green: 0.76, blue: 0.68)
}
