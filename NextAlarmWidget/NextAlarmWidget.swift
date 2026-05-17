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

            HStack(alignment: .top, spacing: SmallWidgetLayout.contentSpacing) {
                markerColumn

                VStack(alignment: .leading, spacing: SmallWidgetLayout.markerRowSpacing) {
                    Text(formattedAlarmTime(for: alarmDate))
                        .font(.system(size: 35, weight: .heavy, design: .rounded))
                        .fontWidth(.compressed)
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .allowsTightening(true)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, minHeight: SmallWidgetLayout.alarmRowHeight, alignment: .leading)

                    if let eventTitle = eventTitleText {
                        HStack(alignment: .center, spacing: 8) {
                            Text(eventTitle)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .fontWidth(.compressed)
                                .foregroundStyle(WidgetTheme.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Spacer(minLength: 0)

                            if let eventContext = entry.snapshot.context {
                                Text(eventContext)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .fontWidth(.compressed)
                                    .foregroundStyle(WidgetTheme.secondaryText)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: SmallWidgetLayout.eventRowHeight, alignment: .leading)
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
        SmallWidgetMarkerColumn(
            showsEvent: eventTitleText != nil,
            showsConnectedMarkers: hasConnectedMarkers
        )
        .offset(x: SmallWidgetLayout.markerColumnOffsetX)
    }

    private var inlineView: some View {
        Group {
            if let alarmDate = entry.snapshot.nextAlarmDate, entry.snapshot.state != .empty {
                Text("\(Image(systemName: stateIconName)) \(formattedAlarmTime(for: alarmDate))")
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
                    Text(formattedAlarmTime(for: alarmDate))
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
                        Text(formattedAlarmTime(for: alarmDate))
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

                    SmallWidgetAtmosphere()
                }
            default:
                EmptyView()
            }
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

    private var eventTitleText: String? {
        guard let eventTitle = entry.snapshot.eventTitle,
              !eventTitle.isEmpty else {
            return nil
        }

        return eventTitle
    }

    private var hasConnectedMarkers: Bool {
        eventTitleText != nil && entry.snapshot.showsConnectedMarkers == true
    }

    private var smallFooterText: String? {
        if entry.snapshot.state == .stale, let detailText = entry.snapshot.detailText {
            return detailText
        }

        if eventTitleText == nil, entry.snapshot.nextAlarmDate != nil {
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

    private func formattedAlarmTime(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

private enum SmallWidgetLayout {
    static let contentSpacing: CGFloat = 8
    static let markerColumnOffsetX: CGFloat = -2
    static let markerColumnWidth: CGFloat = 12
    static let markerRowSpacing: CGFloat = 10
    static let alarmRowHeight: CGFloat = 40
    static let eventRowHeight: CGFloat = 18
    static let primaryMarkerOuterSize: CGFloat = 16
    static let secondaryMarkerOuterSize: CGFloat = 15
    static let connectorWidth: CGFloat = 3

    static func markerColumnHeight(hasEvent: Bool) -> CGFloat {
        alarmRowHeight + (hasEvent ? markerRowSpacing + eventRowHeight : 0)
    }

    static var alarmMarkerOffset: CGFloat {
        (alarmRowHeight - primaryMarkerOuterSize) / 2
    }

    static var eventMarkerOffset: CGFloat {
        alarmRowHeight + markerRowSpacing + ((eventRowHeight - secondaryMarkerOuterSize) / 2)
    }

    static var connectorTopOffset: CGFloat {
        alarmMarkerOffset + (primaryMarkerOuterSize / 2)
    }

    static var connectorHeight: CGFloat {
        max((eventMarkerOffset + (secondaryMarkerOuterSize / 2)) - connectorTopOffset, 0)
    }
}

private struct SmallWidgetAtmosphere: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(WidgetTheme.primaryOrange.opacity(0.10))
                .frame(width: 128, height: 128)
                .blur(radius: 34)
                .offset(x: 58, y: 4)

            Circle()
                .fill(WidgetTheme.secondaryBlue.opacity(0.14))
                .frame(width: 210, height: 210)
                .blur(radius: 58)
                .offset(x: 88, y: 92)
        }
        .compositingGroup()
    }
}

private struct SmallWidgetMarkerColumn: View {
    let showsEvent: Bool
    let showsConnectedMarkers: Bool

    var body: some View {
        ZStack(alignment: .top) {
            if showsConnectedMarkers {
                SmallWidgetConnector()
                    .frame(width: SmallWidgetLayout.connectorWidth, height: SmallWidgetLayout.connectorHeight)
                    .offset(y: SmallWidgetLayout.connectorTopOffset)
            }

            SmallWidgetMarker(
                color: WidgetTheme.primaryOrange,
                outerSize: SmallWidgetLayout.primaryMarkerOuterSize,
                inset: 2.5,
                shadowOpacity: 0.32,
                shadowRadius: 4
            )
            .offset(y: SmallWidgetLayout.alarmMarkerOffset)

            if showsEvent {
                SmallWidgetMarker(
                    color: WidgetTheme.secondaryBlue,
                    outerSize: SmallWidgetLayout.secondaryMarkerOuterSize,
                    inset: 2,
                    shadowOpacity: 0.24,
                    shadowRadius: 2.5
                )
                .offset(y: SmallWidgetLayout.eventMarkerOffset)
            }
        }
        .frame(
            width: SmallWidgetLayout.markerColumnWidth,
            height: SmallWidgetLayout.markerColumnHeight(hasEvent: showsEvent),
            alignment: .top
        )
    }
}

private struct SmallWidgetMarker: View {
    let color: Color
    let outerSize: CGFloat
    let inset: CGFloat
    let shadowOpacity: Double
    let shadowRadius: CGFloat

    var body: some View {
        Circle()
            .fill(WidgetTheme.background)
            .frame(width: outerSize, height: outerSize)
            .overlay {
                Circle()
                    .fill(color)
                    .padding(inset)
            }
            .shadow(color: color.opacity(shadowOpacity), radius: shadowRadius)
    }
}

private struct SmallWidgetConnector: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let x = geometry.size.width / 2
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
            }
            .stroke(
                WidgetTheme.primaryOrange.opacity(0.85),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5])
            )
        }
    }
}

// Using literal copies of app theme to match NextAlarmWidgetExtension without explicit bundle file sharing
private enum WidgetTheme {
    static let primaryOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let secondaryBlue = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let background = Color(red: 0.07, green: 0.07, blue: 0.07)
    static let bgGradientStart = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let bgGradientEnd = Color(red: 0.11, green: 0.11, blue: 0.11)
    static let primaryText = Color(red: 0.89, green: 0.89, blue: 0.89)
    static let secondaryText = Color(red: 0.85, green: 0.76, blue: 0.68)
}
