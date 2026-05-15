import SwiftUI
import WidgetKit

struct NextAlarmWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: NextAlarmWidgetSnapshot
}

struct NextAlarmWidgetProvider: TimelineProvider {
    private let snapshotStore = UserDefaultsNextAlarmWidgetSnapshotStore()

    func placeholder(in context: Context) -> NextAlarmWidgetEntry {
        makeEntry(
            snapshot: Self.previewSnapshot,
            now: Date()
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (NextAlarmWidgetEntry) -> Void
    ) {
        let now = Date()
        let snapshot = context.isPreview ? Self.previewSnapshot : loadSnapshot(now: now)

        completion(makeEntry(
            snapshot: snapshot,
            now: now
        ))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<NextAlarmWidgetEntry>) -> Void
    ) {
        let now = Date()
        let snapshot = loadSnapshot(now: now)
        let entry = makeEntry(
            snapshot: snapshot,
            now: now
        )

        completion(Timeline(
            entries: [entry],
            policy: .after(nextRefreshDate(for: snapshot, from: now))
        ))
    }

    private func makeEntry(
        snapshot: NextAlarmWidgetSnapshot,
        now: Date
    ) -> NextAlarmWidgetEntry {
        NextAlarmWidgetEntry(
            date: now,
            snapshot: snapshot
        )
    }

    private func loadSnapshot(now: Date) -> NextAlarmWidgetSnapshot {
        (try? snapshotStore.load())
            ?? .empty(detailText: "Open EarlyOtter to sync alarms.", lastUpdatedAt: now)
    }

    private func nextRefreshDate(
        for snapshot: NextAlarmWidgetSnapshot,
        from now: Date
    ) -> Date {
        let defaultRefreshDate = now.addingTimeInterval(30 * 60)

        guard let nextAlarmDate = snapshot.nextAlarmDate,
              nextAlarmDate > now else {
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
        StaticConfiguration(
            kind: AppConfiguration.nextAlarmWidgetKind,
            provider: NextAlarmWidgetProvider()
        ) { entry in
            NextAlarmWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Alarm")
        .description("Keep your next wake-up alarm visible on Home, Lock Screen, and StandBy.")
        .supportedFamilies([
            .systemSmall,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

private struct NextAlarmWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: NextAlarmWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .accessoryInline:
                inlineView
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            default:
                smallView
            }
        }
        .containerBackground(for: .widget) {
            containerBackgroundView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: stateIconName)
                    .font(.caption.weight(.semibold))
                    .widgetAccentable()
                titleLabel
            }

            Spacer(minLength: 0)

            alarmValue(font: .system(size: 28, weight: .bold, design: .rounded))

            footerText
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.primary)
    }

    private var inlineView: some View {
        Group {
            if let alarmDate = entry.snapshot.nextAlarmDate,
               entry.snapshot.state != .empty {
                Text("Alarm \(formattedInlineAlarmTime(for: alarmDate))")
            } else {
                Text(inlineFallbackText)
            }
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            if let alarmDate = entry.snapshot.nextAlarmDate,
               entry.snapshot.state != .empty {
                VStack(spacing: 2) {
                    Image(systemName: stateIconName)
                        .font(.caption)
                        .widgetAccentable()
                    Text(formattedCircularAlarmTime(for: alarmDate))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                }
                .padding(6)
            } else {
                Image(systemName: "alarm.slash")
                    .font(.title3)
                    .widgetAccentable()
            }
        }
    }

    private var rectangularView: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: stateIconName)
                .font(.headline)
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 2) {
                titleLabel

                if let alarmDate = entry.snapshot.nextAlarmDate,
                   entry.snapshot.state != .empty {
                    Text(formattedRectangularAlarmTime(for: alarmDate))
                        .font(.headline)
                        .monospacedDigit()
                        .lineLimit(1)
                } else {
                    Text("No upcoming alarm")
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(footerSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.primary)
    }

    private var titleLabel: some View {
        Text(titleText)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var footerText: some View {
        Text(footerSummary)
    }

    private func alarmValue(font: Font) -> some View {
        Group {
            if let alarmDate = entry.snapshot.nextAlarmDate,
               entry.snapshot.state != .empty {
                Text(formattedAlarmTime(for: alarmDate))
                    .font(font)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .widgetAccentable()
            } else {
                Text("No Alarm")
                    .font(font)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .widgetAccentable()
            }
        }
    }

    private var titleText: String {
        switch entry.snapshot.state {
        case .scheduled:
            return "Next Alarm"
        case .empty:
            return "Alarm Status"
        case .stale:
            return "Needs Refresh"
        }
    }

    private var footerSummary: String {
        if let eventTitle = entry.snapshot.eventTitle,
           !eventTitle.isEmpty {
            return eventTitle
        }

        if let context = entry.snapshot.context,
           !context.isEmpty {
            return context
        }

        if let detailText = entry.snapshot.detailText,
           !detailText.isEmpty {
            return detailText
        }

        return relativeRefreshText
    }

    private var inlineFallbackText: String {
        switch entry.snapshot.state {
        case .scheduled:
            return "Alarm set"
        case .empty:
            return "Open EarlyOtter"
        case .stale:
            return "Refresh EarlyOtter"
        }
    }

    private var relativeRefreshText: String {
        "Updated \(entry.snapshot.lastUpdatedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var stateIconName: String {
        switch entry.snapshot.state {
        case .scheduled:
            return "alarm.fill"
        case .empty:
            return "alarm.slash"
        case .stale:
            return "arrow.clockwise"
        }
    }

    private func formattedAlarmTime(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func formattedInlineAlarmTime(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func formattedCircularAlarmTime(for date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private func formattedRectangularAlarmTime(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    @ViewBuilder
    private var containerBackgroundView: some View {
        switch family {
        case .systemSmall:
            Color(uiColor: .secondarySystemBackground)
        default:
            EmptyView()
        }
    }
}