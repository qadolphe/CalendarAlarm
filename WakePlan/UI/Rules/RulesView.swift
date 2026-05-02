import SwiftUI

// MARK: - Rules list

struct RulesView: View {
    @Bindable var appState: AppState
    @State private var isAddingRule = false

    var body: some View {
        List {
            // MARK: Schedule config (global, lives above rules)
            Section {
                autoPilotCard
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))

                fallbackTimesCard
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
            }

            // MARK: Rules
            Section(header: sectionHeader("Rules")) {
                let allRules = [appState.preferences.defaultAlarmRule] + appState.preferences.customAlarmRules.sorted { $0.name.lowercased() < $1.name.lowercased() }
                
                ForEach(allRules) { rule in
                    ZStack(alignment: .leading) {
                        ruleCard(rule)
                        NavigationLink(destination: RuleEditorView(appState: appState, mode: .edit(rule))) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !rule.isDefault {
                            Button(role: .destructive) { deleteRule(rule) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear.withAppBackground())
        .navigationTitle("Rules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAddingRule = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(WPStyles.primaryOrange)
                }
            }
        }
        .sheet(isPresented: $isAddingRule) {
            NavigationStack {
                RuleEditorView(appState: appState, mode: .add)
            }
        }
    }

    // MARK: Schedule cards

    private var autoPilotCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(WPStyles.primaryOrange.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .foregroundStyle(WPStyles.primaryOrange)
                }

                Text("Auto-Pilot")
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)

                Spacer()

                Toggle("", isOn: enabledBinding)
                    .labelsHidden()
                    .tint(WPStyles.primaryOrange)
            }

            if appState.preferences.isEnabled {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                    spacing: 8
                ) {
                    ForEach(WakePlanUIConfiguration.sundayFirstWeekdays) { option in
                        weekdayCell(option)
                    }
                }
                .padding(.top, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.preferences.isEnabled)
        .cardStyle()
    }

    private var fallbackTimesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fallback Wake Times")
                .font(.headline)
                .foregroundStyle(WPStyles.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(WakePlanUIConfiguration.sundayFirstWeekdays) { option in
                        fallbackGridCell(for: option)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func fallbackGridCell(for option: WeekdayOption) -> some View {
        VStack(spacing: 8) {
            Text(option.shortLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(WPStyles.secondaryText)
                .textCase(.uppercase)

            DatePicker(
                "",
                selection: fallbackTimeBinding(for: option.weekday),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .colorScheme(.dark)
            .scaleEffect(0.9)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(WPStyles.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Rule cards

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(WPStyles.secondaryText)
            .textCase(.uppercase)
            .padding(.top, 8)
    }

    private func ruleCard(_ rule: AlarmRule) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(rule.isDefault ? WPStyles.primaryOrange.opacity(0.15) : WPStyles.surfaceRaised)
                    .frame(width: 42, height: 42)
                Image(systemName: rule.isDefault ? "star.fill" : "slider.horizontal.3")
                    .foregroundStyle(WPStyles.primaryOrange)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(rule.name)
                        .font(.headline)
                        .foregroundStyle(WPStyles.primaryText)

                    if rule.isDefault {
                        Text("DEFAULT")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WPStyles.primaryOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(WPStyles.primaryOrange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                if rule.conditions.isEmpty {
                    Text(rule.isDefault ? "Applies to all other events" : "Matches all events")
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.secondaryText)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(Array(rule.conditions.enumerated()), id: \.offset) { _, condition in
                            conditionChip(condition)
                        }
                    }
                }

                Label(calendarSummary(for: rule), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(WPStyles.tertiaryText)

                HStack(spacing: 12) {
                    timingBadge(icon: "cup.and.saucer.fill", value: rule.prepTime.rawValue, unit: "prep")
                    timingBadge(icon: "car.fill", value: rule.commuteTime.rawValue, unit: "commute")
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(WPStyles.tertiaryText)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(WPStyles.surface))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
    }

    private func conditionChip(_ condition: AlarmRuleCondition) -> some View {
        Text(condition.displayLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(WPStyles.secondaryBlue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(WPStyles.secondaryBlue.opacity(0.12))
            .clipShape(Capsule())
    }

    private func timingBadge(icon: String, value: Int, unit: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundStyle(WPStyles.tertiaryText)
            Text("\(value) min \(unit)").font(.caption.weight(.medium)).foregroundStyle(WPStyles.secondaryText)
        }
    }

    private func calendarSummary(for rule: AlarmRule) -> String {
        if rule.selectedCalendarIDs.isEmpty { return "All calendars" }
        let selected = appState.calendars.filter { rule.selectedCalendarIDs.contains($0.id) }
        if selected.count == 1 { return selected[0].title }
        if selected.count == 2 { return selected.map(\.title).joined(separator: ", ") }
        if !selected.isEmpty { return "\(selected.count) calendars" }
        return "\(rule.selectedCalendarIDs.count) calendars"
    }

    // MARK: Helpers

    private func weekdayCell(_ option: WeekdayOption) -> some View {
        let isSelected = appState.preferences.activeDays.contains(option.weekday)
        return Button { toggleActiveDay(option.weekday) } label: {
            VStack(spacing: 8) {
                Text(option.shortLabel).font(.system(size: 9, weight: .bold))
                Circle()
                    .fill(isSelected ? WPStyles.primaryOrange : WPStyles.surfaceRaised)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? WPStyles.surfaceRaised : WPStyles.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? WPStyles.primaryOrange.opacity(0.55) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? WPStyles.primaryText : WPStyles.secondaryText.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.isEnabled },
            set: { v in
                var copy = appState.preferences
                copy.isEnabled = v
                Task { await appState.updatePreferences(copy) }
            }
        )
    }

    private func toggleActiveDay(_ weekday: Int) {
        var copy = appState.preferences
        if copy.activeDays.contains(weekday) {
            guard copy.activeDays.count > 1 else { return }
            copy.activeDays.remove(weekday)
        } else {
            copy.activeDays.insert(weekday)
        }
        Task { await appState.updatePreferences(copy) }
    }

    private func fallbackTimeBinding(for weekday: Int) -> Binding<Date> {
        Binding(
            get: {
                let clockTime = appState.preferences.fallbackWakeTime(for: weekday)
                return clockTime.date(on: TargetDay(date: Date()))
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                guard let h = c.hour, let m = c.minute else { return }
                var copy = appState.preferences
                copy.schedule.fallbackWakeTimes[weekday] = ClockTime(hour: h, minute: m)
                Task { await appState.updatePreferences(copy) }
            }
        )
    }

    private func deleteRule(_ rule: AlarmRule) {
        var copy = appState.preferences
        copy.alarmRules.removeAll { $0.id == rule.id }
        Task { await appState.updatePreferences(copy) }
    }
}

// MARK: - Rule editor

enum RuleEditorMode {
    case add
    case edit(AlarmRule)

    var isAdd: Bool {
        if case .add = self { return true }
        return false
    }
}

struct RuleEditorView: View {
    @Bindable var appState: AppState
    let mode: RuleEditorMode
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var conditions: [AlarmRuleCondition]
    @State private var selectedCalendarIDs: Set<String>
    @State private var prepTime: Minutes
    @State private var commuteTime: Minutes
    @State private var newTitleKeyword = ""
    @State private var newLocationKeyword = ""

    @State private var showDuplicateAlert = false

    private var isDefaultRule: Bool {
        if case .edit(let rule) = mode { return rule.isDefault }
        return false
    }

    init(appState: AppState, mode: RuleEditorMode) {
        self.appState = appState
        self.mode = mode
        switch mode {
        case .add:
            let dr = appState.preferences.defaultAlarmRule
            _name = State(initialValue: "")
            _conditions = State(initialValue: [])
            _selectedCalendarIDs = State(initialValue: dr.selectedCalendarIDs)
            _prepTime = State(initialValue: dr.prepTime)
            _commuteTime = State(initialValue: dr.commuteTime)
        case .edit(let rule):
            _name = State(initialValue: rule.name)
            _conditions = State(initialValue: rule.conditions)
            _selectedCalendarIDs = State(initialValue: rule.selectedCalendarIDs)
            _prepTime = State(initialValue: rule.prepTime)
            _commuteTime = State(initialValue: rule.commuteTime)
        }
    }

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    if !isDefaultRule {
                        nameSection
                        conditionsSection
                    }
                    calendarsSection
                    timingSection
                }
                .padding(24)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { trySave() }
                    .fontWeight(.semibold)
                    .foregroundStyle(WPStyles.primaryOrange)
            }
            if mode.isAdd {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(WPStyles.secondaryText)
                }
            }
        }
        .alert("Duplicate Rule", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A rule with the same calendars and conditions already exists. Adjust the config so rules don't overlap 1-to-1.")
        }
    }

    private var calendarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("Calendars")
                Spacer()
                if !selectedCalendarIDs.isEmpty {
                    Button("Use All") {
                        selectedCalendarIDs = []
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WPStyles.secondaryBlue)
                }
            }

            if appState.permissions.calendar != .authorized {
                Button("Allow Calendar Access") {
                    Task { await appState.requestCalendarAccess() }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if appState.calendars.isEmpty {
                Text("All calendars")
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.calendars) { calendar in
                        let isSelected = selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains(calendar.id)

                        Button {
                            toggleCalendar(calendar.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? WPStyles.primaryOrange : WPStyles.tertiaryText)

                                Text(calendar.title)
                                    .foregroundStyle(WPStyles.primaryText)

                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)

                        if calendar.id != appState.calendars.last?.id {
                            Divider().overlay(WPStyles.cardBorder)
                        }
                    }
                }
                .background(WPStyles.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WPStyles.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    private var navTitle: String {
        if isDefaultRule { return "Default Rule" }
        if mode.isAdd { return "New Rule" }
        return name.isEmpty ? "Rule" : name
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Name")
            TextField("e.g. Doctor Appointments", text: $name)
                .font(.body)
                .foregroundStyle(WPStyles.primaryText)
                .padding(14)
                .background(WPStyles.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(WPStyles.cardBorder, lineWidth: 1)
                )
        }
    }

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Conditions")

            conditionGroup(
                icon: "text.magnifyingglass",
                label: "Title contains",
                values: conditions.compactMap {
                    if case .titleContains(let v) = $0 { return v } else { return nil }
                },
                newValue: $newTitleKeyword,
                placeholder: "keyword",
                onAdd: {
                    let v = newTitleKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !v.isEmpty else { return }
                    conditions.append(.titleContains(v))
                    newTitleKeyword = ""
                },
                onRemove: { keyword in conditions.removeAll { $0 == .titleContains(keyword) } }
            )

            conditionGroup(
                icon: "mappin.circle.fill",
                label: "Location contains",
                values: conditions.compactMap {
                    if case .locationContains(let v) = $0 { return v } else { return nil }
                },
                newValue: $newLocationKeyword,
                placeholder: "place or address",
                onAdd: {
                    let v = newLocationKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !v.isEmpty else { return }
                    conditions.append(.locationContains(v))
                    newLocationKeyword = ""
                },
                onRemove: { location in conditions.removeAll { $0 == .locationContains(location) } }
            )
        }
    }

    private func conditionGroup(
        icon: String,
        label: String,
        values: [String],
        newValue: Binding<String>,
        placeholder: String,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(WPStyles.primaryOrange)
                Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(WPStyles.primaryText)
            }

            if !values.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        HStack(spacing: 4) {
                            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(WPStyles.primaryText)
                            Button { onRemove(value) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(WPStyles.tertiaryText)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(WPStyles.surfaceRaised)
                        .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(placeholder, text: newValue)
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.primaryText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { onAdd() }
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(WPStyles.primaryOrange)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(WPStyles.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(WPStyles.cardBorder, lineWidth: 1)
            )
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Timing")

            VStack(spacing: 0) {
                stepperRow(label: "Prep time", value: $prepTime, range: 0...180)
                Divider().overlay(WPStyles.cardBorder).padding(.leading, 16)
                stepperRow(label: "Commute", value: $commuteTime, range: 0...180)
            }
            .background(WPStyles.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1)
            )
        }
    }

    private func stepperRow(label: String, value: Binding<Minutes>, range: ClosedRange<Int>) -> some View {
        Stepper(
            value: Binding(get: { value.wrappedValue.rawValue }, set: { value.wrappedValue = Minutes($0) }),
            in: range,
            step: 5
        ) {
            HStack {
                Text(label).font(.body).foregroundStyle(WPStyles.primaryText)
                Spacer()
                Text("\(value.wrappedValue.rawValue) min")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryOrange)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(WPStyles.secondaryText)
            .textCase(.uppercase)
    }

    private func trySave() {
        // Check for 1:1 duplicate (same calendars + same conditions) against other rules
        if case .add = mode {
            let sortedConditions = conditions.sorted {
                $0.displayLabel < $1.displayLabel
            }
            let isDuplicate = appState.preferences.alarmRules.contains { existing in
                let existingSorted = existing.conditions.sorted { $0.displayLabel < $1.displayLabel }
                return existing.selectedCalendarIDs == selectedCalendarIDs
                    && existingSorted == sortedConditions
            }
            if isDuplicate {
                showDuplicateAlert = true
                return
            }
        }
        save()
    }

    private func save() {
        var copy = appState.preferences
        switch mode {
        case .add:
            let newRule = AlarmRule(
                id: UUID(),
                name: name.isEmpty ? "New Rule" : name,
                isDefault: false,
                selectedCalendarIDs: selectedCalendarIDs,
                conditions: conditions,
                prepTime: prepTime,
                commuteTime: commuteTime
            )
            if let idx = copy.alarmRules.firstIndex(where: { $0.isDefault }) {
                copy.alarmRules.insert(newRule, at: idx)
            } else {
                copy.alarmRules.append(newRule)
            }
        case .edit(let rule):
            if let idx = copy.alarmRules.firstIndex(where: { $0.id == rule.id }) {
                copy.alarmRules[idx].name = isDefaultRule ? "Default" : (name.isEmpty ? "Rule" : name)
                copy.alarmRules[idx].selectedCalendarIDs = selectedCalendarIDs
                copy.alarmRules[idx].conditions = isDefaultRule ? [] : conditions
                copy.alarmRules[idx].prepTime = prepTime
                copy.alarmRules[idx].commuteTime = commuteTime
            }
        }
        Task { await appState.updatePreferences(copy) }
        dismiss()
    }

    private func toggleCalendar(_ id: String) {
        if selectedCalendarIDs.isEmpty {
            selectedCalendarIDs = [id]
            return
        }

        if selectedCalendarIDs.contains(id) {
            selectedCalendarIDs.remove(id)
            if selectedCalendarIDs.isEmpty {
                return
            }
            return
        }

        selectedCalendarIDs.insert(id)
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// MARK: - Event filter settings (used from Settings tab)

struct EventFilterSettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            List {
                Section {
                    filterToggle("All-Day Events", isOn: filterBinding(\.ignoreAllDayEvents))
                    filterToggle("Tentative Events", isOn: filterBinding(\.ignoreTentativeEvents))
                    filterToggle("Canceled Events", isOn: filterBinding(\.ignoreCanceledEvents))
                    filterToggle("Free Events", isOn: filterBinding(\.ignoreFreeEvents))
                } header: {
                    Text("Ignore")
                } footer: {
                    Text("Matching events will never trigger an alarm.")
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Event Filters")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filterToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .tint(WPStyles.primaryOrange)
            .foregroundStyle(WPStyles.primaryText)
    }

    private func filterBinding(_ keyPath: WritableKeyPath<AlarmPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.preferences[keyPath: keyPath] },
            set: { value in
                var copy = appState.preferences
                copy[keyPath: keyPath] = value
                Task { await appState.updatePreferences(copy) }
            }
        )
    }
}

// MARK: - Keyword rules editor (used from Settings tab)

struct KeywordRulesEditorView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var blockedKeywords: [String]
    @State private var allowedKeywords: [String]
    @State private var newBlockedKeyword = ""
    @State private var newAllowedKeyword = ""

    init(appState: AppState) {
        self.appState = appState
        self._blockedKeywords = State(initialValue: appState.preferences.titleBlocklist)
        self._allowedKeywords = State(initialValue: appState.preferences.titleAllowlist)
    }

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            List {
                keywordSection(
                    title: "Blocked",
                    footer: "Events whose title contains any of these words are ignored.",
                    keywords: $blockedKeywords,
                    newKeyword: $newBlockedKeyword
                )

                keywordSection(
                    title: "Allowed Only",
                    footer: "When non-empty, only events matching these words are considered.",
                    keywords: $allowedKeywords,
                    newKeyword: $newAllowedKeyword
                )
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Keywords")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    var copy = appState.preferences
                    copy.titleBlocklist = blockedKeywords
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                        .filter { !$0.isEmpty }
                    copy.titleAllowlist = allowedKeywords
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                        .filter { !$0.isEmpty }
                    Task { await appState.updatePreferences(copy); dismiss() }
                }
                .fontWeight(.semibold)
                .foregroundStyle(WPStyles.primaryOrange)
            }
        }
    }

    private func keywordSection(
        title: String,
        footer: String,
        keywords: Binding<[String]>,
        newKeyword: Binding<String>
    ) -> some View {
        Section {
            ForEach(Array(keywords.wrappedValue.indices), id: \.self) { idx in
                TextField("Keyword", text: Binding(
                    get: { keywords.wrappedValue[idx] },
                    set: { keywords.wrappedValue[idx] = $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(WPStyles.primaryText)
            }
            .onDelete { keywords.wrappedValue.remove(atOffsets: $0) }

            HStack {
                TextField("Add keyword", text: newKeyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { addKeyword(newKeyword, to: keywords) }
                Button { addKeyword(newKeyword, to: keywords) } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(WPStyles.primaryOrange)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
    }

    private func addKeyword(_ binding: Binding<String>, to list: Binding<[String]>) {
        let v = binding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !v.isEmpty else { return }
        list.wrappedValue.append(v)
        binding.wrappedValue = ""
    }
}
