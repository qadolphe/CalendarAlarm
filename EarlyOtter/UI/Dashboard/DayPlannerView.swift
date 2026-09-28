import SwiftUI

/// Where a day's alarm and events sit on the planner's hour grid.
struct DayTimeline {
    enum Kind {
        /// `setsAlarm` marks the event a rule timed the alarm for.
        case event(ParsedEvent, startsBeforeAlarm: Bool, setsAlarm: Bool)
        case prep(Minutes)
        case commute(Minutes)
    }

    struct Block: Identifiable {
        let id: String
        let kind: Kind
        let start: Date
        let end: Date
        /// Overlapping events share the width side by side, like a calendar's day view.
        var column = 0
        var columns = 1
    }

    static let hourHeight: CGFloat = 58

    let dayStart: Date
    let firstHour: Int
    let lastHour: Int
    let alarm: Date?
    let blocks: [Block]
    let allDayEvents: [ParsedEvent]
    /// The rule that timed the alarm, when a calendar event set it.
    let ruleName: String?
    let ruleSymbol: RuleSymbol
    /// From the first thing on the day to the end of the last.
    let items: ClosedRange<Date>?

    /// `minimumHours` lets a short day still fill the screen.
    init(plan: WakeUpPlan, alarm: Date?, minimumHours: Int = 6, calendar: Calendar = .current) {
        let dayStart = plan.targetDay.date
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        var blocks: [Block] = []
        if let alarm, plan.reason == .event, let event = plan.targetEvent {
            let prepEnd = alarm.addingTimeInterval(TimeInterval(plan.prepTime.rawValue * 60))
            if plan.prepTime.rawValue > 0 {
                blocks.append(Block(id: "prep", kind: .prep(plan.prepTime), start: alarm, end: prepEnd))
            }
            if plan.commuteTime.rawValue > 0 {
                blocks.append(Block(id: "commute", kind: .commute(plan.commuteTime), start: prepEnd, end: event.startDate))
            }
        }

        let events = plan.dayEvents.filter { !$0.isAllDay }.map { event in
            Block(
                id: event.id,
                kind: .event(
                    event,
                    startsBeforeAlarm: alarm.map { event.startDate < $0 } ?? false,
                    setsAlarm: plan.reason == .event && event.id == plan.targetEvent?.id
                ),
                start: event.startDate,
                end: min(max(event.endDate, event.startDate.addingTimeInterval(15 * 60)), dayEnd)
            )
        }
        blocks += Self.columned(events)

        let starts = blocks.map(\.start) + [alarm].compactMap { $0 }
        let ends = blocks.map(\.end) + [alarm?.addingTimeInterval(30 * 60)].compactMap { $0 }
        let hour = { (date: Date) in date.timeIntervalSince(dayStart) / 3600 }

        self.dayStart = dayStart
        self.alarm = alarm
        self.blocks = blocks
        self.allDayEvents = plan.dayEvents.filter(\.isAllDay)
        self.ruleName = plan.reason == .event ? plan.appliedRuleName : nil
        self.ruleSymbol = plan.appliedRuleSymbol ?? .general
        self.items = starts.min().flatMap { first in ends.max().map { first...max(first, $0) } }
        // A morning by default, stretched to fit whatever the day holds.
        self.firstHour = max(0, min(6, Int((starts.map(hour).min().map { $0 - 0.5 } ?? 6).rounded(.down))))
        self.lastHour = min(24, max(firstHour + minimumHours, Int((ends.map(hour).max().map { $0 + 0.5 } ?? 12).rounded(.up))))
    }

    var height: CGFloat {
        CGFloat(lastHour - firstHour) * Self.hourHeight
    }

    var hourMarks: [Date] {
        (firstHour...lastHour).map { dayStart.addingTimeInterval(TimeInterval($0) * 3600) }
    }

    /// Scrolled so the day's first item sits just below the top.
    var initialOffset: CGFloat {
        items.map { max(0, y($0.lowerBound) - 24) } ?? 0
    }

    func y(_ date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSince(dayStart) / 3600 - Double(firstHour)) * Self.hourHeight
    }

    private static func columned(_ events: [Block]) -> [Block] {
        var result: [Block] = []
        var cluster: [Block] = []
        var clusterEnd = Date.distantPast

        func closeCluster() {
            let columns = (cluster.map(\.column).max() ?? 0) + 1
            result += cluster.map { block in
                var block = block
                block.columns = columns
                return block
            }
            cluster = []
        }

        for var block in events.sorted(by: { $0.start < $1.start }) {
            if block.start >= clusterEnd { closeCluster() }
            let taken = Set(cluster.filter { $0.end > block.start }.map(\.column))
            while taken.contains(block.column) { block.column += 1 }
            cluster.append(block)
            clusterEnd = max(clusterEnd, block.end)
        }
        closeCluster()
        return result
    }
}

/// A day as a planner: the alarm pinned among the day's events. Dragging the
/// header down hands the drag to the dashboard, which folds the week card open.
struct DayPlannerView: View {
    let entry: DashboardViewModel.WeekEntry
    let onEditAlarm: () -> Void
    /// A long-press drag on the alarm pill moved it to this time.
    let onMoveAlarm: (Date) -> Void
    /// How far the planner has been pulled down, for the dashboard to follow.
    let onPull: (CGFloat) -> Void
    /// The pull ended; `true` when it went far enough to close.
    let onRelease: (Bool) -> Void

    @State private var scrollPosition = ScrollPosition(y: 0)
    @State private var scroll = ScrollMetrics()
    @State private var isMovingAlarm = false

    private struct ScrollMetrics: Equatable {
        var offset: CGFloat = 0
        var viewport: CGFloat = 0
    }

    private static let headerCloseDistance: CGFloat = 130
    private static let gridInset: CGFloat = 14

    private var plan: WakeUpPlan { entry.plan }

    private var timeline: DayTimeline {
        // Enough hours to fill the screen, so a light day doesn't end in blank space.
        let visibleHours = Int(((scroll.viewport - Self.gridInset * 2) / DayTimeline.hourHeight).rounded(.down))
        return DayTimeline(plan: plan, alarm: entry.alarmDate, minimumHours: max(6, visibleHours))
    }

    /// Only today and future days are editable, and never while fully disabled.
    private var isEditable: Bool {
        plan.reason != .systemDisabled && plan.targetDay.date >= Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                DayTimelineView(
                    timeline: timeline,
                    alarmTitle: plan.wakeTitle,
                    isEditable: isEditable,
                    isMovingAlarm: $isMovingAlarm,
                    onEditAlarm: onEditAlarm,
                    onMoveAlarm: onMoveAlarm
                )
                .padding(.horizontal, 16)
                .padding(.vertical, Self.gridInset)
            }
            .scrollPosition($scrollPosition)
            .scrollDisabled(isMovingAlarm)
            .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
                ScrollMetrics(
                    offset: geometry.contentOffset.y + geometry.contentInsets.top,
                    viewport: geometry.containerSize.height
                )
            } action: { _, metrics in
                scroll = metrics
            }
            .overlay(alignment: .top) {
                scrollButton("chevron.up", isVisible: hasItems(above: scroll.offset)) {
                    scrollPosition.scrollTo(y: max(0, scroll.offset - scroll.viewport * 0.8))
                }
            }
            .overlay(alignment: .bottom) {
                scrollButton("chevron.down", isVisible: hasItems(below: scroll.offset + scroll.viewport)) {
                    scrollPosition.scrollTo(y: scroll.offset + scroll.viewport * 0.8)
                }
            }

            if entry.alarmDate == nil && isEditable {
                addAlarmButton
            }
        }
        .onAppear { scrollPosition.scrollTo(y: timeline.initialOffset) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule()
                .fill(WPStyles.surfaceOutline)
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)

            Text(plan.targetDay.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(WPStyles.primaryText)

            if let note {
                Text(note.text)
                    .font(.subheadline)
                    .foregroundStyle(note.tint)
            }

            if !timeline.allDayEvents.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(timeline.allDayEvents) { event in
                            Text(event.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WPStyles.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(WPStyles.eventTint.opacity(0.18), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { onPull(max(0, $0.translation.height)) }
                .onEnded { value in
                    onRelease(max(value.translation.height, value.predictedEndTranslation.height) > Self.headerCloseDistance)
                }
        )
        .accessibilityAction(named: "Close day") { onRelease(true) }
    }

    /// Why the day has no alarm, or why its alarm may not ring.
    private var note: (text: String, tint: Color)? {
        switch entry.alarmStatus {
        case .failed(let message): return ("Couldn't schedule alarm: \(message)", .red)
        case .needsPermission: return ("Alarm access is off, so this won't ring", WPStyles.accent)
        case .scheduled, .disabled, .notScheduled, nil: break
        }

        let quiet = WPStyles.secondaryText
        switch plan.reason {
        case .manualSkip: return ("Alarm turned off for this day", quiet)
        case .inactiveDay: return ("Auto Alarms are paused for this day", quiet)
        case .disabled: return ("Automatic alarms are turned off", quiet)
        case .systemDisabled: return ("EarlyOtter is disabled", quiet)
        case .noSchedule, .event, .alarm, .authorizationMissing, .manualOverride: return nil
        }
    }

    private var addAlarmButton: some View {
        Button(action: onEditAlarm) {
            Label(plan.reason == .manualSkip ? "Turn alarm on" : "Add alarm", systemImage: plan.reason == .manualSkip ? "bell" : "plus")
                .font(.headline)
                .foregroundStyle(WPStyles.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.accent, lineWidth: 1.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func hasItems(above edge: CGFloat) -> Bool {
        timeline.items.map { timeline.y($0.lowerBound) + Self.gridInset < edge } ?? false
    }

    private func hasItems(below edge: CGFloat) -> Bool {
        timeline.items.map { timeline.y($0.upperBound) + Self.gridInset > edge } ?? false
    }

    /// Shows only while events are scrolled out of view, so a day never looks emptier than it is.
    private func scrollButton(_ systemImage: String, isVisible: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.smooth) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(WPStyles.eventTint)
                .frame(width: 32, height: 32)
                .background(WPStyles.surfaceRaised, in: Circle())
                .overlay(Circle().stroke(WPStyles.eventTint.opacity(0.6), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(8)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .accessibilityLabel(systemImage == "chevron.up" ? "Earlier events" : "Later events")
    }
}

/// The hour grid itself: hour lines, event and prep/commute blocks, and the alarm line.
private struct DayTimelineView: View {
    let timeline: DayTimeline
    let alarmTitle: String
    let isEditable: Bool
    @Binding var isMovingAlarm: Bool
    let onEditAlarm: () -> Void
    let onMoveAlarm: (Date) -> Void

    /// Where a long-press drag has taken the alarm, held until the new plan arrives.
    @State private var movedAlarm: Date?

    private let labelWidth: CGFloat = 48

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - labelWidth

            ZStack(alignment: .topLeading) {
                ForEach(timeline.hourMarks, id: \.self) { mark in
                    HStack(spacing: 0) {
                        Text(mark.formatted(.dateTime.hour()))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(WPStyles.tertiaryText)
                            .frame(width: labelWidth, alignment: .leading)
                        Rectangle()
                            .fill(WPStyles.surfaceOutline.opacity(0.5))
                            .frame(height: 0.5)
                    }
                    .frame(height: 14)
                    .offset(y: timeline.y(mark) - 7)
                }

                ForEach(timeline.blocks) { block in
                    let columnWidth = width / CGFloat(block.columns)
                    let height = blockHeight(block)

                    blockView(block, width: columnWidth - 4, height: height)
                        .frame(width: columnWidth - 4, height: height)
                        .offset(x: labelWidth + 4 + columnWidth * CGFloat(block.column), y: timeline.y(block.start) + 1)
                }

                if let alarm = movedAlarm ?? timeline.alarm {
                    alarmLine(alarm)
                        .frame(width: width + 6)
                        .offset(x: labelWidth - 6, y: timeline.y(alarm) - 14)
                }
            }
        }
        .frame(height: timeline.height)
        .onChange(of: timeline.alarm) { movedAlarm = nil }
        .sensoryFeedback(.selection, trigger: movedAlarm) { _, _ in isMovingAlarm }
        .sensoryFeedback(.impact, trigger: isMovingAlarm) { _, isMoving in isMoving }
    }

    /// Events keep a readable minimum; prep and commute stay exact so they meet the event they lead to.
    private func blockHeight(_ block: DayTimeline.Block) -> CGFloat {
        let height = timeline.y(block.end) - timeline.y(block.start) - 2
        guard case .event = block.kind else { return max(0, height) }
        return max(24, height)
    }

    /// Hold the pill, then drag: the alarm follows in 5-minute steps and saves on release.
    private func moveGesture(from alarm: Date) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                isMovingAlarm = true
                movedAlarm = snapped(alarm, movedBy: drag?.translation.height ?? 0)
            }
            .onEnded { value in
                isMovingAlarm = false
                guard case .second(true, let drag) = value, let drag else { return }
                let moved = snapped(alarm, movedBy: drag.translation.height)
                if moved == alarm {
                    movedAlarm = nil
                } else {
                    movedAlarm = moved
                    onMoveAlarm(moved)
                }
            }
    }

    private func snapped(_ alarm: Date, movedBy offset: CGFloat) -> Date {
        let step: TimeInterval = 5 * 60
        let seconds = alarm.timeIntervalSince(timeline.dayStart) + TimeInterval(offset / DayTimeline.hourHeight) * 3600
        let clamped = min(max(seconds, 0), 24 * 3600 - step)
        return timeline.dayStart.addingTimeInterval((clamped / step).rounded() * step)
    }

    @ViewBuilder
    private func blockView(_ block: DayTimeline.Block, width: CGFloat, height: CGFloat) -> some View {
        switch block.kind {
        case .event(let event, let startsBeforeAlarm, let setsAlarm):
            VStack(alignment: .leading, spacing: 2) {
                TitleTagRow(tagShare: 0.4, spacing: 12) {
                    Text(event.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WPStyles.primaryText)

                    if setsAlarm {
                        // Side-by-side events are too narrow for a readable name.
                        ruleTag(showsName: width >= 220)
                    }
                }

                if height > 40 {
                    if startsBeforeAlarm {
                        Label("Starts before your alarm", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(WPStyles.accent)
                    } else {
                        let times = (event.startDate..<event.endDate).formatted(.interval.hour().minute())
                        Text([times, event.location].compactMap { $0 }.joined(separator: " · "))
                            .foregroundStyle(WPStyles.eventTint)
                    }
                }
            }
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(WPStyles.eventTint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(WPStyles.eventTint.opacity(0.7), lineWidth: 0.5))
        case .prep(let minutes):
            stepBlock("Prep · \(minutes.rawValue)m", systemImage: "cup.and.saucer.fill", height: height)
        case .commute(let minutes):
            stepBlock("Commute · \(minutes.rawValue)m", systemImage: "car.fill", height: height)
        }
    }

    /// Which rule timed the alarm, on the event it was timed for. The title gives way
    /// first; on narrow columns only the rule's icon is left.
    private func ruleTag(showsName: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: timeline.ruleSymbol.systemImage)
            if let name = timeline.ruleName, showsName {
                Text(name)
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(WPStyles.accent)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(WPStyles.accent.opacity(0.15), in: Capsule())
        .accessibilityLabel(timeline.ruleName.map { "Alarm set by \($0)" } ?? "Alarm set by this event")
    }

    private func stepBlock(_ title: String, systemImage: String, height: CGFloat) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .opacity(height >= 14 ? 1 : 0)
            .foregroundStyle(WPStyles.secondaryText)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(WPStyles.surfaceRaised.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(WPStyles.surfaceOutline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
    }

    private func alarmLine(_ alarm: Date) -> some View {
        HStack(spacing: 0) {
            Circle()
                .fill(WPStyles.accent)
                .frame(width: 12, height: 12)
            Rectangle()
                .fill(WPStyles.accent)
                .frame(height: 2)
            HStack(spacing: 3) {
                Text("\(alarm.formatted(date: .omitted, time: .shortened)) · \(alarmTitle)")
                    .lineLimit(1)
                    .contentTransition(.numericText())
                if isEditable {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(WPStyles.onAccent)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(WPStyles.accent, in: Capsule())
            .scaleEffect(isMovingAlarm ? 1.08 : 1)
            .shadow(color: .black.opacity(isMovingAlarm ? 0.35 : 0), radius: 8, y: 4)
            .animation(.snappy(duration: 0.2), value: isMovingAlarm)
            .contentShape(Capsule())
            .onTapGesture { if isEditable { onEditAlarm() } }
            .gesture(moveGesture(from: timeline.alarm ?? alarm), isEnabled: isEditable)
            .accessibilityAddTraits(isEditable ? .isButton : [])
            .accessibilityHint(isEditable ? "Edits this day's alarm. Hold and drag to move it." : "")
        }
        .frame(height: 28)
    }
}

/// An event title and its rule tag on one line. The tag keeps its natural width up
/// to a share of the row; the title truncates in what's left, a fixed gap before it.
private struct TitleTagRow: Layout {
    let tagShare: CGFloat
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        return CGSize(
            width: proposal.width ?? ideal.map(\.width).reduce(spacing, +),
            height: ideal.map(\.height).max() ?? 0
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let title = subviews.first else { return }
        var titleWidth = bounds.width

        if let tag = subviews.dropFirst().first {
            let tagWidth = min(tag.sizeThatFits(.unspecified).width, bounds.width * tagShare)
            tag.place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: ProposedViewSize(width: tagWidth, height: nil))
            titleWidth -= tagWidth + spacing
        }

        title.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: max(0, titleWidth), height: nil))
    }
}
