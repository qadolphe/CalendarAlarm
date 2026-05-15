import AppIntents
import SwiftUI
import WidgetKit

enum NextAlarmWidgetDisplayMode: String, AppEnum {
    case nextAlarmTime
    case timeRemaining

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")

    static var caseDisplayRepresentations: [NextAlarmWidgetDisplayMode: DisplayRepresentation] = [
        .nextAlarmTime: DisplayRepresentation(title: "Next alarm time"),
        .timeRemaining: DisplayRepresentation(title: "Time remaining")
    ]
}

struct NextAlarmWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Next Alarm"
    static var description = IntentDescription(
        "Show the time of your next wake-up alarm or how long remains until it rings."
    )

    @Parameter(title: "Display")
    var displayMode: NextAlarmWidgetDisplayMode?

    init() {
        displayMode = .nextAlarmTime
    }
}

struct NextAlarmWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: NextAlarmWidgetConfigurationIntent
    let snapshot: NextAlarmWidgetSnapshot
}

struct NextAlarmWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = NextAlarmWidgetEntry
    typealias Intent = NextAlarmWidgetConfigurationIntent

    private let snapshotStore = UserDefaultsNextAlarmWidgetSnapshotStore()

    func placeholder(in context: Context) -> Entry {
        makeEntry(
            configuration: NextAlarmWidgetConfigurationIntent(),
            snapshot: Self.previewSnapshot,
            now: Date()
        )
    }

    func snapshot(
        for configuration: NextAlarmWidgetConfigurationIntent,
        in context: Context
    ) async -> NextAlarmWidgetEntry {
        let now = Date()
        let snapshot = context.isPreview ? Self.previewSnapshot : loadSnapshot(now: now)

        return makeEntry(
            configuration: configuration,
            snapshot: snapshot,
            now: now
        )
    }

    func timeline(
        for configuration: NextAlarmWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<NextAlarmWidgetEntry> {
        let now = Date()
        let snapshot = loadSnapshot(now: now)
        let entry = makeEntry(
            configuration: configuration,
            snapshot: snapshot,
            now: now
        )

        return Timeline(
            entries: [entry],
            policy: .after(nextRefreshDate(for: snapshot, from: now))
        )
    }

    private func makeEntry(
        configuration: NextAlarmWidgetConfigurationIntent,
        snapshot: NextAlarmWidgetSnapshot,
        now: Date
    ) -> NextAlarmWidgetEntry {
        NextAlarmWidgetEntry(
            date: now,
            configuration: configuration,
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
        AppIntentConfiguration(
            kind: AppConfiguration.nextAlarmWidgetKind,
            intent: NextAlarmWidgetConfigurationIntent.self,
            provider: NextAlarmWidgetProvider()
        ) { entry in
            NextAlarmWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Alarm")
        .description("Keep your next wake-up alarm visible on Home, Lock Screen, and StandBy.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
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
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
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

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleLabel
            alarmValue(font: .system(size: 26, weight: .bold, design: .rounded))
            footerText
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                titleLabel
                alarmValue(font: .system(size: 28, weight: .bold, design: .rounded))
                footerText
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                if let eventTitle = entry.snapshot.eventTitle, !eventTitle.isEmpty {
                    Text(eventTitle)
                        .font(.headline)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }

                Text(relativeRefreshText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var inlineView: some View {
        Group {
            if let alarmDate = entry.snapshot.nextAlarmDate,
               entry.snapshot.state != .empty {
                if entry.configuration.displayMode == .timeRemaining {
                    Text("Alarm in \(alarmDate, style: .timer)")
                } else {
                    Text("Alarm \(alarmDate, style: .time)")
                }
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
                    Image(systemName: entry.snapshot.state == .stale ? "exclamationmark.triangle.fill" : "alarm.fill")
                        .font(.caption)
                    Text(alarmDate, style: displayStyle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                }
                .padding(6)
            } else {
                Image(systemName: "alarm.slash")
                    .font(.title3)
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleLabel

            if let alarmDate = entry.snapshot.nextAlarmDate,
               entry.snapshot.state != .empty {
                Text(alarmDate, style: displayStyle)
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
                .lineLimit(2)
        }
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
                Text(alarmDate, style: displayStyle)
                    .font(font)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } else {
                Text("No Alarm")
                    .font(font)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
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
        if let detailText = entry.snapshot.detailText,
           !detailText.isEmpty {
            return detailText
        }

        if let eventTitle = entry.snapshot.eventTitle,
           !eventTitle.isEmpty {
            return eventTitle
        }

        if let context = entry.snapshot.context,
           !context.isEmpty {
            return context
        }

        return relativeRefreshText
    }

    private var inlineFallbackText: String {
        switch entry.snapshot.state {
        case .scheduled:
            return "Alarm set"
        case .empty:
            return "No alarm"
        case .stale:
            return "Needs refresh"
        }
    }

    private var relativeRefreshText: String {
        "Updated \(entry.snapshot.lastUpdatedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var displayStyle: Text.DateStyle {
		entry.configuration.displayMode == .timeRemaining ? .timer : .time
    }
}