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
        showsConnectedMarkers: true,
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
        Group {
            if let alarmDate = entry.snapshot.nextAlarmDate, entry.snapshot.state != .empty {
                scheduledSmallView(alarmDate: alarmDate)
            } else {
                emptySmallView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func scheduledSmallView(alarmDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Next Alarm")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WidgetTheme.primaryText)

            Text("in \(Text(alarmDate, style: .relative))")
                .font(.caption.weight(.medium))
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 12)

            HStack(alignment: .top, spacing: 8) {
                markerColumn

                VStack(alignment: .leading, spacing: markerRowSpacing) {
                    Text(formattedAlarmTime(for: alarmDate))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .allowsTightening(true)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, minHeight: alarmRowHeight, alignment: .leading)

                    if hasEventRow {
                        HStack(alignment: .center, spacing: 8) {
                            Text(entry.snapshot.eventTitle ?? "")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WidgetTheme.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Spacer(minLength: 0)

                            if let eventContext = eventContextText {
                                Text(eventContext)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(WidgetTheme.secondaryText)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: eventRowHeight, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            if let footer = smallFooterText {
                Text(footer)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WidgetTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptySmallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)

            Text("No alarms")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(WidgetTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(emptyStateSubtitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(WidgetTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private var markerColumn: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(WidgetTheme.primaryOrange)
                .frame(width: markerSize, height: markerSize)
                .frame(height: alarmRowHeight, alignment: .center)

            if hasEventRow {
                if entry.snapshot.showsConnectedMarkers == true {
                    DottedConnector()
                        .frame(width: markerConnectorWidth, height: markerRowSpacing)
                } else {
                    Color.clear
                        .frame(width: markerConnectorWidth, height: markerRowSpacing)
                }

                Circle()
                    .fill(WidgetTheme.secondaryBlue)
                    .frame(width: markerSize, height: markerSize)
                    .frame(height: eventRowHeight, alignment: .center)
            }
        }
        .frame(width: markerColumnWidth)
        .offset(x: -2)
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
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

    private var hasEventRow: Bool {
        if let eventTitle = entry.snapshot.eventTitle {
            return !eventTitle.isEmpty
        }
        return false
    }

    private var eventContextText: String? {
        guard hasEventRow else {
            return nil
        }
        return entry.snapshot.context
    }

    private var smallFooterText: String? {
        if entry.snapshot.state == .stale, let detailText = entry.snapshot.detailText {
            return detailText
        }

        if !hasEventRow, entry.snapshot.nextAlarmDate != nil {
            return "No early events"
        }

        return nil
    }

    private var emptyStateSubtitle: String {
        if let detailText = entry.snapshot.detailText,
           detailText != "No upcoming alarms." {
            return detailText
        }

        return "Enjoy sleeping in"
    }

    private var markerSize: CGFloat { 11 }

    private var markerConnectorWidth: CGFloat { 3 }

    private var markerColumnWidth: CGFloat { 12 }

    private var markerRowSpacing: CGFloat { 10 }

    private var alarmRowHeight: CGFloat { 40 }

    private var eventRowHeight: CGFloat { 18 }

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

private struct DottedConnector: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let x = geometry.size.width / 2
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
            }
            .stroke(
                WidgetTheme.primaryOrange.opacity(0.85),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 3])
            )
        }
    }
}

// Using literal copies of app theme to match NextAlarmWidgetExtension without explicit bundle file sharing
private enum WidgetTheme {
    static let primaryOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let secondaryBlue = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let bgGradientStart = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let bgGradientEnd = Color(red: 0.11, green: 0.11, blue: 0.11)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let primaryText = Color(red: 0.89, green: 0.89, blue: 0.89)
    static let secondaryText = Color(red: 0.85, green: 0.76, blue: 0.68)
}
