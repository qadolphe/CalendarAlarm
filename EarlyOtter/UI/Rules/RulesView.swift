import SwiftUI

// MARK: - Rules list

struct RulesView: View {
    @Bindable var appState: AppState
    @State private var isAddingRule = false
    @State private var isShowingSettings = false

    var body: some View {
        List {
            // MARK: Global filters (live above rules)
            Section {
                NavigationLink(destination: GlobalEventFiltersView(appState: appState)) {
                    HStack(spacing: 14) {
                        IconTile("line.3.horizontal.decrease", tint: WPStyles.primaryText)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ignored Events")
                                .font(.headline)
                                .foregroundStyle(WPStyles.primaryText)
                            Text(filterSummary)
                                .font(.subheadline)
                                .foregroundStyle(WPStyles.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .cardStyle()
            }

            // MARK: Rules
            Section(header: sectionHeader("Rules")) {
                let sortedCustomRules = appState.preferences.customAlarmRules.sorted { lhs, rhs in
                    if lhs.isEnabled != rhs.isEnabled { return lhs.isEnabled && !rhs.isEnabled }
                    return lhs.name.lowercased() < rhs.name.lowercased()
                }
                let allRules = [appState.preferences.defaultAlarmRule] + sortedCustomRules
                
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
                            // Icon only; the explicit tint overrides the tab bar's white tint.
                            Button(role: .destructive) { deleteRule(rule) } label: {
                                Image(systemName: "trash")
                            }
                            .tint(.red)
                            .accessibilityLabel("Delete")
                        }
                    }
                }

                Button {
                    isAddingRule = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(WPStyles.accent)
                        Text("Add Rule")
                            .font(.headline)
                            .foregroundStyle(WPStyles.primaryText)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(WPStyles.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear.withAppBackground())
        .navigationTitle("Rules")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(WPStyles.primaryText)
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $isAddingRule) {
            NavigationStack {
                RuleEditorView(appState: appState, mode: .add)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView(appState: appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { isShowingSettings = false }
                                .fontWeight(.bold)
                                .foregroundStyle(WPStyles.accent)
                        }
                    }
            }
        }
    }

    // MARK: Rule cards

    private func sectionHeader(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(WPStyles.secondaryText)
            .textCase(.uppercase)
            .padding(.top, 8)
    }

    private func ruleCard(_ rule: AlarmRule) -> some View {
        HStack(spacing: 14) {
            if rule.isDefault {
                IconTile("star.fill", tint: WPStyles.accent, fill: WPStyles.accent.opacity(0.15))
            } else {
                IconTile(rule.symbol.systemImage, tint: WPStyles.primaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.displayName)
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
                Text("\(rule.prepTime.rawValue)m prep · \(rule.commuteTime.rawValue)m commute")
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(WPStyles.tertiaryText)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(WPStyles.surface))
        .opacity(rule.isDefault || rule.isEnabled ? 1 : 0.72)
    }

    private var filterSummary: String {
        let filters = appState.preferences.filters
        let statuses = [
            (filters.ignoreAllDayEvents, String(localized: "All-day")),
            (filters.ignoreTentativeEvents, String(localized: "Tentative")),
            (filters.ignoreCanceledEvents, String(localized: "Canceled")),
            (filters.ignoreFreeEvents, String(localized: "Free"))
        ].compactMap { $0.0 ? $0.1 : nil }
        let active = statuses + appState.preferences.titleBlocklist
        return active.isEmpty ? String(localized: "None") : active.joined(separator: ", ")
    }

    // MARK: Helpers

    private func deleteRule(_ rule: AlarmRule) {
        Task {
            await appState.mutatePreferences { $0.alarmRules.removeAll { $0.id == rule.id } }
        }
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
    @State private var isEnabled: Bool
    @State private var conditions: [AlarmRuleCondition]
    @State private var activeWeekdays: Set<Int>
    @State private var selectedCalendarIDs: Set<String>
    @State private var prepTime: Minutes
    @State private var commuteTime: Minutes
    @State private var sound: AlarmSoundOption
    @State private var snoozeEnabled: Bool
    @State private var snoozeDuration: Minutes
    @State private var symbol: RuleSymbol
    @State private var isChoosingSymbol = false

    @State private var showDuplicateAlert = false
    @State private var expandedAccountIDs: Set<CalendarAccountID> = []

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
            _isEnabled = State(initialValue: true)
            _conditions = State(initialValue: [])
            _activeWeekdays = State(initialValue: dr.activeWeekdays)
            _selectedCalendarIDs = State(initialValue: dr.selectedCalendarIDs)
            _prepTime = State(initialValue: dr.prepTime)
            _commuteTime = State(initialValue: dr.commuteTime)
            _sound = State(initialValue: dr.alarmSettings.sound)
            _snoozeEnabled = State(initialValue: dr.alarmSettings.snoozeEnabled)
            _snoozeDuration = State(initialValue: dr.alarmSettings.snoozeDuration)
            _symbol = State(initialValue: .general)
        case .edit(let rule):
            _name = State(initialValue: rule.name)
            _isEnabled = State(initialValue: rule.isEnabled)
            _conditions = State(initialValue: rule.conditions)
            _activeWeekdays = State(initialValue: rule.activeWeekdays)
            _selectedCalendarIDs = State(initialValue: rule.selectedCalendarIDs)
            _prepTime = State(initialValue: rule.prepTime)
            _commuteTime = State(initialValue: rule.commuteTime)
            _sound = State(initialValue: rule.alarmSettings.sound)
            _snoozeEnabled = State(initialValue: rule.alarmSettings.snoozeEnabled)
            _snoozeDuration = State(initialValue: rule.alarmSettings.snoozeDuration)
            _symbol = State(initialValue: rule.symbol)
        }
    }

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    if !isDefaultRule {
                        headerCard
                    }

                    VStack(alignment: .leading, spacing: 28) {
                        matchSection
                        timingSection
                        alarmSection
                    }
                    .disabled(!isDefaultRule && !isEnabled)
                    .opacity((!isDefaultRule && !isEnabled) ? 0.5 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) { trySave() }
                    .tint(WPStyles.accent)
            }
            if mode.isAdd {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .alert("Duplicate Rule", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A rule with the same calendars and conditions already exists. Adjust the config so rules don't overlap 1-to-1.")
        }
        .onChange(of: isEnabled) { _, newValue in
            guard case .edit(let rule) = mode, !rule.isDefault else { return }
            guard let current = appState.preferences.alarmRules.first(where: { $0.id == rule.id }),
                  current.isEnabled != newValue else { return }
            Task {
                await appState.mutatePreferences { copy in
                    if let idx = copy.alarmRules.firstIndex(where: { $0.id == rule.id }) {
                        copy.alarmRules[idx].isEnabled = newValue
                    }
                }
            }
        }
    }

    private var calendarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                if !selectedCalendarIDs.isEmpty {
                    Button("Use All") {
                        selectedCalendarIDs = []
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WPStyles.eventTint)
                }
            }

            if appState.shouldShowCalendarAccessPrompt {
                Button("Allow Calendar Access") {
                    Task { await appState.requestCalendarAccess() }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if appState.calendars.isEmpty {
                Text("All calendars")
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)
            } else {
                let enabledAccounts = appState.accounts.filter(\.isEnabled)
                
                if enabledAccounts.count > 1 {
                    VStack(spacing: 16) {
                        ForEach(enabledAccounts) { account in
                            accountCalendarGroup(for: account)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(appState.calendars) { calendar in
                            let isSelected = selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains(calendar.id)

                            Button {
                                toggleCalendar(calendar.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected ? WPStyles.accent : WPStyles.tertiaryText)

                                    if let account = enabledAccounts.first {
                                        providerIcon(for: account.provider)
                                    }

                                    Text(calendar.title)
                                        .foregroundStyle(WPStyles.primaryText)

                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                            }
                            .buttonStyle(.plain)

                            if calendar.id != appState.calendars.last?.id {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                    .background(WPStyles.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func providerIcon(for provider: CalendarProvider) -> some View {
        if provider == .apple {
            Image(systemName: "apple.logo")
                .foregroundStyle(WPStyles.primaryText)
                .frame(width: 16)
        } else {
            Text("G")
                .font(.headline.weight(.black))
                .foregroundStyle(WPStyles.primaryText)
                .frame(width: 16)
        }
    }

    @ViewBuilder
    private func accountCalendarGroup(for account: ConnectedCalendarAccount) -> some View {
        let accountCalendars = appState.calendars.filter { $0.accountID == account.id }
        if !accountCalendars.isEmpty {
            let isExpanded = expandedAccountIDs.contains(account.id)
            let allSelected = accountCalendars.allSatisfy { selectedCalendarIDs.contains($0.id) } || selectedCalendarIDs.isEmpty
            let someSelected = accountCalendars.contains { selectedCalendarIDs.contains($0.id) } && !allSelected

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Button {
                        if allSelected {
                            if selectedCalendarIDs.isEmpty {
                                let otherCalendars = appState.calendars.filter { $0.accountID != account.id }
                                selectedCalendarIDs = Set(otherCalendars.map(\.id))
                                if selectedCalendarIDs.isEmpty {
                                    selectedCalendarIDs.insert("NONE")
                                }
                            } else {
                                accountCalendars.forEach { selectedCalendarIDs.remove($0.id) }
                                if selectedCalendarIDs.isEmpty {
                                    selectedCalendarIDs.insert("NONE")
                                }
                            }
                        } else {
                            selectedCalendarIDs.remove("NONE")
                            accountCalendars.forEach { selectedCalendarIDs.insert($0.id) }
                            if selectedCalendarIDs.count == appState.calendars.count {
                                selectedCalendarIDs = []
                            }
                        }
                    } label: {
                        Image(systemName: allSelected ? "checkmark.circle.fill" : (someSelected ? "minus.circle.fill" : "circle"))
                            .foregroundStyle((allSelected || someSelected) ? WPStyles.accent : WPStyles.tertiaryText)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedAccountIDs.remove(account.id)
                            } else {
                                expandedAccountIDs.insert(account.id)
                            }
                        }
                    } label: {
                        HStack {
                            providerIcon(for: account.provider)
                            Text(account.displayName)
                                .foregroundStyle(WPStyles.primaryText)
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .foregroundStyle(WPStyles.tertiaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                if isExpanded {
                    Divider()
                    
                    ForEach(accountCalendars) { calendar in
                        let isSelected = selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains(calendar.id)

                        Button {
                            toggleCalendar(calendar.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? WPStyles.accent : WPStyles.tertiaryText)

                                Text(calendar.title)
                                    .foregroundStyle(WPStyles.primaryText)
                                    .font(.subheadline)

                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .padding(.leading, 24)
                        }
                        .buttonStyle(.plain)

                        if calendar.id != accountCalendars.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
            .background(WPStyles.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var navTitle: String {
        if isDefaultRule { return String(localized: "Default Rule") }
        if mode.isAdd { return String(localized: "New Rule") }
        return name.isEmpty ? String(localized: "Rule") : name
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Button {
                isChoosingSymbol = true
            } label: {
                Image(systemName: symbol.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WPStyles.primaryText)
                    .frame(width: 36, height: 36)
                    .background(WPStyles.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rule icon")
            .popover(isPresented: $isChoosingSymbol) {
                symbolPicker
                    .padding(12)
                    .presentationCompactAdaptation(.popover)
            }

            TextField("Rule name", text: $name)
                .font(.headline)
                .foregroundStyle(WPStyles.primaryText)

            Toggle("Enabled", isOn: $isEnabled)
                .labelsHidden()
                .tint(WPStyles.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(WPStyles.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Match")

            VStack(spacing: 0) {
                if !isDefaultRule {
                    navRow("Title contains", value: keywordSummary(titleKeywords.wrappedValue)) {
                        KeywordListEditor(
                            title: "Title Contains",
                            placeholder: "Add a word",
                            footer: "Events whose title contains all of these words use this rule.",
                            keywords: titleKeywords
                        )
                    }
                    Divider().padding(.leading, 16)
                    navRow("Location contains", value: keywordSummary(locationKeywords.wrappedValue)) {
                        KeywordListEditor(
                            title: "Location Contains",
                            placeholder: "Add a place or address",
                            footer: "Events whose location contains all of these use this rule.",
                            keywords: locationKeywords
                        )
                    }
                    Divider().padding(.leading, 16)
                    navRow("Days", value: daysSummary) {
                        WeekdayPicker(weekdays: $activeWeekdays)
                    }
                    Divider().padding(.leading, 16)
                }
                navRow("Calendars", value: calendarsSummary) {
                    ScrollView {
                        calendarsSection.padding(20)
                    }
                    .background(Color.clear.withAppBackground())
                    .navigationTitle("Calendars")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .background(WPStyles.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func navRow<Destination: View>(
        _ title: LocalizedStringResource,
        value: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 8) {
                Text(title)
                    .foregroundStyle(WPStyles.primaryText)
                Spacer(minLength: 12)
                Text(value)
                    .foregroundStyle(WPStyles.secondaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WPStyles.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var titleKeywords: Binding<[String]> {
        keywords(\.titleKeyword, make: AlarmRuleCondition.titleContains)
    }

    private var locationKeywords: Binding<[String]> {
        keywords(\.locationKeyword, make: AlarmRuleCondition.locationContains)
    }

    private func keywords(
        _ extract: @escaping (AlarmRuleCondition) -> String?,
        make: @escaping (String) -> AlarmRuleCondition
    ) -> Binding<[String]> {
        Binding(
            get: { conditions.compactMap(extract) },
            set: { conditions = conditions.filter { extract($0) == nil } + $0.map(make) }
        )
    }

    private func keywordSummary(_ keywords: [String]) -> String {
        keywords.isEmpty ? String(localized: "Any") : keywords.joined(separator: ", ")
    }

    private var daysSummary: String {
        switch activeWeekdays {
        case Set(1...7): return String(localized: "Every day")
        case Set(2...6): return String(localized: "Weekdays")
        case [1, 7]: return String(localized: "Weekends")
        default:
            let symbols = Calendar.current.shortWeekdaySymbols
            return activeWeekdays.sorted().map { symbols[$0 - 1] }.joined(separator: ", ")
        }
    }

    private var calendarsSummary: String {
        if selectedCalendarIDs.isEmpty { return String(localized: "All") }
        let titles = appState.calendars.filter { selectedCalendarIDs.contains($0.id) }.map(\.title)
        switch titles.count {
        case 0: return String(localized: "None")
        case 1: return titles[0]
        default: return String(localized: "\(titles.count) calendars")
        }
    }

    private var symbolPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 6), count: 6), spacing: 6) {
            ForEach(RuleSymbol.allCases, id: \.self) { option in
                let isSelected = option == symbol
                Button {
                    symbol = option
                    isChoosingSymbol = false
                } label: {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? WPStyles.primaryText : WPStyles.tertiaryText)
                        .frame(width: 40, height: 40)
                        .background(isSelected ? WPStyles.surfaceRaised : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(isSelected ? WPStyles.accent : .clear, lineWidth: 1.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue.capitalized)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Timing")

            VStack(spacing: 0) {
                stepperRow(label: "Prep time", value: $prepTime, range: 0...180)
                Divider().padding(.leading, 16)
                stepperRow(label: "Commute", value: $commuteTime, range: 0...180)
            }
            .background(WPStyles.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var alarmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Alarm")

            VStack(spacing: 0) {
                NavigationLink {
                    AlarmSoundPickerView(selection: $sound)
                } label: {
                    HStack(spacing: 8) {
                        Text("Sound")
                            .font(.body)
                            .foregroundStyle(WPStyles.primaryText)
                        Spacer(minLength: 8)
                        Text(sound.displayName)
                            .font(.body)
                            .foregroundStyle(WPStyles.secondaryText)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(WPStyles.tertiaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 16)

                Toggle(isOn: $snoozeEnabled) {
                    Text("Snooze")
                        .font(.body)
                        .foregroundStyle(WPStyles.primaryText)
                }
                .tint(WPStyles.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if snoozeEnabled {
                    Divider().padding(.leading, 16)
                    stepperRow(label: "Duration", value: $snoozeDuration, range: 1...60)
                }
            }
            .background(WPStyles.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func stepperRow(label: LocalizedStringResource, value: Binding<Minutes>, range: ClosedRange<Int>) -> some View {
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
                    .foregroundStyle(WPStyles.primaryText)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sectionLabel(_ text: LocalizedStringResource) -> some View {
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
                return existing.activeWeekdays == activeWeekdays
                    && existing.selectedCalendarIDs == selectedCalendarIDs
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
        Task {
            await appState.mutatePreferences { copy in
                switch mode {
                case .add:
                    let newRule = AlarmRule(
                        id: UUID(),
                        name: name.isEmpty ? String(localized: "New Rule") : name,
                        isDefault: false,
                        activeWeekdays: activeWeekdays,
                        selectedCalendarIDs: selectedCalendarIDs,
                        conditions: conditions,
                        prepTime: prepTime,
                        commuteTime: commuteTime,
                        alarmSettings: RuleAlarmSettings(
                            sound: sound,
                            snoozeEnabled: snoozeEnabled,
                            snoozeDuration: snoozeDuration
                        ),
                        symbol: symbol
                    )
                    if let idx = copy.alarmRules.firstIndex(where: { $0.isDefault }) {
                        copy.alarmRules.insert(newRule, at: idx)
                    } else {
                        copy.alarmRules.append(newRule)
                    }
                case .edit(let rule):
                    if let idx = copy.alarmRules.firstIndex(where: { $0.id == rule.id }) {
                        copy.alarmRules[idx].name = isDefaultRule ? "Default" : (name.isEmpty ? String(localized: "Rule") : name)
                        copy.alarmRules[idx].isEnabled = isDefaultRule ? true : isEnabled
                        copy.alarmRules[idx].activeWeekdays = isDefaultRule ? Set(1...7) : activeWeekdays
                        copy.alarmRules[idx].selectedCalendarIDs = selectedCalendarIDs
                        copy.alarmRules[idx].conditions = isDefaultRule ? [] : conditions
                        copy.alarmRules[idx].symbol = symbol
                        copy.alarmRules[idx].prepTime = prepTime
                        copy.alarmRules[idx].commuteTime = commuteTime
                        copy.alarmRules[idx].alarmSettings = RuleAlarmSettings(
                            sound: sound,
                            snoozeEnabled: snoozeEnabled,
                            snoozeDuration: snoozeDuration
                        )
                    }
                }
            }
        }
        dismiss()
    }

    private func toggleCalendar(_ id: String) {
        if selectedCalendarIDs.isEmpty {
            let allIDs = Set(appState.calendars.map(\.id))
            var newSelection = allIDs
            newSelection.remove(id)
            selectedCalendarIDs = newSelection
            if selectedCalendarIDs.isEmpty {
                selectedCalendarIDs.insert("NONE")
            }
        } else if selectedCalendarIDs.contains(id) {
            selectedCalendarIDs.remove(id)
            if selectedCalendarIDs.isEmpty {
                selectedCalendarIDs.insert("NONE")
            }
        } else {
            selectedCalendarIDs.remove("NONE")
            selectedCalendarIDs.insert(id)
            if selectedCalendarIDs.count == appState.calendars.count {
                selectedCalendarIDs = []
            }
        }
    }
}

// MARK: - Rule editor pages

/// A plain list of keywords: swipe to delete, type and return to add.
private struct KeywordListEditor: View {
    let title: LocalizedStringResource
    let placeholder: LocalizedStringResource
    let footer: LocalizedStringResource
    @Binding var keywords: [String]

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        List {
            Section {
                ForEach(keywords, id: \.self) { keyword in
                    Text(keyword)
                        .foregroundStyle(WPStyles.primaryText)
                }
                .onDelete { keywords.remove(atOffsets: $0) }

                TextField(text: $draft) { Text(placeholder) }
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit(commit)
            } footer: {
                Text(footer)
            }
            .listRowBackground(WPStyles.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear.withAppBackground())
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = keywords.isEmpty }
        .onDisappear(perform: commit)
    }

    private func commit() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        draft = ""
        guard !value.isEmpty, !keywords.contains(value) else { return }
        keywords.append(value)
    }
}

/// Clock-style day list; at least one day stays selected.
private struct WeekdayPicker: View {
    @Binding var weekdays: Set<Int>

    var body: some View {
        List {
            ForEach(EarlyOtterUIConfiguration.sundayFirstWeekdays) { option in
                Button {
                    if weekdays.contains(option.weekday) {
                        guard weekdays.count > 1 else { return }
                        weekdays.remove(option.weekday)
                    } else {
                        weekdays.insert(option.weekday)
                    }
                } label: {
                    HStack {
                        Text("Every \(option.fullLabel)")
                            .foregroundStyle(WPStyles.primaryText)
                        Spacer()
                        if weekdays.contains(option.weekday) {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(WPStyles.accent)
                        }
                    }
                }
            }
            .listRowBackground(WPStyles.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear.withAppBackground())
        .navigationTitle("Days")
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Global Event Filters (used from Rules tab)

struct GlobalEventFiltersView: View {
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
                Section {
                    filterToggle("All-Day Events", isOn: filterBinding(\.ignoreAllDayEvents))
                    filterToggle("Tentative Events", isOn: filterBinding(\.ignoreTentativeEvents))
                    filterToggle("Canceled Events", isOn: filterBinding(\.ignoreCanceledEvents))
                    filterToggle("Free Events", isOn: filterBinding(\.ignoreFreeEvents))
                } header: {
                    Text("Ignore Calendar Status")
                } footer: {
                    Text("Matching events will never trigger an alarm.")
                }

                keywordSection(
                    title: "Blocked Keywords",
                    footer: "Events whose title contains any of these words are ignored.",
                    keywords: $blockedKeywords,
                    newKeyword: $newBlockedKeyword
                )

                keywordSection(
                    title: "Allowed Only Keywords",
                    footer: "When non-empty, only events matching these words are considered.",
                    keywords: $allowedKeywords,
                    newKeyword: $newAllowedKeyword
                )
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Ignored Events & Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    addKeyword($newBlockedKeyword, to: $blockedKeywords)
                    addKeyword($newAllowedKeyword, to: $allowedKeywords)
                    let normalize: ([String]) -> [String] = { keywords in
                        keywords
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                            .filter { !$0.isEmpty }
                    }
                    let blocked = normalize(blockedKeywords)
                    let allowed = normalize(allowedKeywords)
                    Task {
                        await appState.mutatePreferences { copy in
                            copy.titleBlocklist = blocked
                            copy.titleAllowlist = allowed
                        }
                        dismiss()
                    }
                }
                .buttonStyle(PrimaryCapsuleButtonStyle())
            }
        }
    }

    private func filterToggle(_ label: LocalizedStringResource, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { Text(label) }
            .tint(WPStyles.accent)
            .foregroundStyle(WPStyles.primaryText)
    }

    private func filterBinding(_ keyPath: WritableKeyPath<AlarmPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.preferences[keyPath: keyPath] },
            set: { value in
                Task { await appState.mutatePreferences { $0[keyPath: keyPath] = value } }
            }
        )
    }

    private func keywordSection(
        title: LocalizedStringResource,
        footer: LocalizedStringResource,
        keywords: Binding<[String]>,
        newKeyword: Binding<String>
    ) -> some View {
        Section {
            if !keywords.wrappedValue.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(keywords.wrappedValue, id: \.self) { value in
                        HStack(spacing: 4) {
                            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(WPStyles.primaryText)
                            Button { keywords.wrappedValue.removeAll(where: { $0 == value }) } label: {
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
                .padding(.vertical, 4)
            }

            HStack {
                TextField("Add keyword", text: newKeyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { addKeyword(newKeyword, to: keywords) }
                Button { addKeyword(newKeyword, to: keywords) } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(WPStyles.accent)
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
        if !list.wrappedValue.contains(v) {
            list.wrappedValue.append(v)
        }
        binding.wrappedValue = ""
    }
}

extension RuleSymbol {
    var systemImage: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .school: "graduationcap.fill"
        case .work: "briefcase.fill"
        case .flight: "airplane"
        case .gym: "dumbbell.fill"
        case .run: "figure.run"
        case .medical: "stethoscope"
        case .meeting: "person.2.fill"
        case .drive: "car.fill"
        case .study: "book.fill"
        case .music: "music.note"
        case .sun: "sun.max.fill"
        }
    }
}
