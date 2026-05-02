import SwiftUI

// MARK: - Rules list

struct RulesView: View {
    @Bindable var appState: AppState
    @State private var isAddingRule = false
    @State private var ruleToDelete: AlarmRule?

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            if appState.preferences.alarmRules.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(appState.preferences.customAlarmRules) { rule in
                            NavigationLink(destination: RuleEditorView(appState: appState, mode: .edit(rule))) {
                                ruleCard(rule)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    ruleToDelete = rule
                                } label: {
                                    Label("Delete Rule", systemImage: "trash")
                                }
                            }
                        }

                        NavigationLink(
                            destination: RuleEditorView(
                                appState: appState,
                                mode: .edit(appState.preferences.defaultAlarmRule)
                            )
                        ) {
                            ruleCard(appState.preferences.defaultAlarmRule)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
        }
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
        .confirmationDialog(
            "Delete \"\(ruleToDelete?.name ?? "Rule")\"?",
            isPresented: Binding(
                get: { ruleToDelete != nil },
                set: { if !$0 { ruleToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let rule = ruleToDelete { deleteRule(rule) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 44))
                .foregroundStyle(WPStyles.primaryOrange)
            Text("No rules yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(WPStyles.primaryText)
            Text("Tap + to create your first alarm rule.")
                .font(.subheadline)
                .foregroundStyle(WPStyles.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(WPStyles.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
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

    private func deleteRule(_ rule: AlarmRule) {
        var copy = appState.preferences
        copy.alarmRules.removeAll { $0.id == rule.id }
        Task { await appState.updatePreferences(copy) }
        ruleToDelete = nil
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
    @State private var prepTime: Minutes
    @State private var commuteTime: Minutes
    @State private var newTitleKeyword = ""
    @State private var newLocationKeyword = ""

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
            _prepTime = State(initialValue: dr.prepTime)
            _commuteTime = State(initialValue: dr.commuteTime)
        case .edit(let rule):
            _name = State(initialValue: rule.name)
            _conditions = State(initialValue: rule.conditions)
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
                    timingSection
                }
                .padding(24)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
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

    private func save() {
        var copy = appState.preferences
        switch mode {
        case .add:
            let newRule = AlarmRule(
                id: UUID(),
                name: name.isEmpty ? "New Rule" : name,
                isDefault: false,
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
                copy.alarmRules[idx].conditions = isDefaultRule ? [] : conditions
                copy.alarmRules[idx].prepTime = prepTime
                copy.alarmRules[idx].commuteTime = commuteTime
            }
        }
        Task { await appState.updatePreferences(copy) }
        dismiss()
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
    @Environment(\.dismiss) private var dismiss
    @State private var draft: AlarmPreferences

    init(appState: AppState) {
        self.appState = appState
        self._draft = State(initialValue: appState.preferences)
    }

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            List {
                Section {
                    filterToggle("All-Day Events", isOn: $draft.ignoreAllDayEvents)
                    filterToggle("Tentative Events", isOn: $draft.ignoreTentativeEvents)
                    filterToggle("Canceled Events", isOn: $draft.ignoreCanceledEvents)
                    filterToggle("Free Events", isOn: $draft.ignoreFreeEvents)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { await appState.updatePreferences(draft); dismiss() }
                }
                .fontWeight(.semibold)
                .foregroundStyle(WPStyles.primaryOrange)
            }
        }
    }

    private func filterToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .tint(WPStyles.primaryOrange)
            .foregroundStyle(WPStyles.primaryText)
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
