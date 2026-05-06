import SwiftUI

// MARK: - Rules list

struct RulesView: View {
    @Bindable var appState: AppState
    @State private var isAddingRule = false
    @State private var selectedWeekday: WeekdayOption?

    var body: some View {
        List {
            // MARK: Schedule config (global, lives above rules)
            Section {
                scheduleCard
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))

                NavigationLink(destination: GlobalEventFiltersView(appState: appState)) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(WPStyles.surfaceRaised)
                                .frame(width: 40, height: 40)
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .foregroundStyle(WPStyles.primaryOrange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ignored Events & Filters")
                                .font(.headline)
                                .foregroundStyle(WPStyles.primaryText)
                            Text("Configure which events are always skipped")
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

                Button {
                    isAddingRule = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(WPStyles.primaryOrange)
                        Text("Add Rule")
                            .font(.headline)
                            .foregroundStyle(WPStyles.primaryText)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(WPStyles.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
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
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingRule) {
            NavigationStack {
                RuleEditorView(appState: appState, mode: .add)
            }
        }
        .sheet(item: $selectedWeekday) { option in
            DaySettingsView(appState: appState, weekdayOption: option)
        }
    }

    // MARK: Schedule cards

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(WPStyles.primaryOrange.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "calendar.day.timeline.left")
                        .foregroundStyle(WPStyles.primaryOrange)
                }

                Text("Daily Schedule")
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)

                Spacer()
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
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(WPStyles.surface))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
    }

    private func timingBadge(icon: String, value: Int, unit: String) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(WPStyles.tertiaryText)
            Text("\(value)m \(unit)")
                .font(.caption.weight(.medium))
                .foregroundStyle(WPStyles.secondaryText)
        }
    }

    // MARK: Helpers

    private func weekdayCell(_ option: WeekdayOption) -> some View {
        let isAutoPilot = appState.preferences.activeDays.contains(option.weekday)
        let isFallback = appState.preferences.fallbackEnabledDays.contains(option.weekday)

        return Button { selectedWeekday = option } label: {
            VStack(spacing: 8) {
                Text(option.shortLabel).font(.system(size: 9, weight: .bold))
                Circle()
                    .fill(isFallback ? WPStyles.primaryOrange : WPStyles.surfaceRaised)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isAutoPilot || isFallback ? WPStyles.surfaceRaised : WPStyles.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isAutoPilot ? WPStyles.primaryOrange.opacity(0.8) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .foregroundStyle(isAutoPilot || isFallback ? WPStyles.primaryText : WPStyles.secondaryText.opacity(0.7))
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
    private enum ConditionField: Hashable {
        case title
        case location
    }

    @Bindable var appState: AppState
    let mode: RuleEditorMode
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var conditions: [AlarmRuleCondition]
    @State private var activeWeekdays: Set<Int>
    @State private var selectedCalendarIDs: Set<String>
    @State private var prepTime: Minutes
    @State private var commuteTime: Minutes
    @State private var sound: AlarmSoundOption
    @State private var snoozeEnabled: Bool
    @State private var snoozeDuration: Minutes
    @State private var newTitleKeyword = ""
    @State private var newLocationKeyword = ""

    @State private var showDuplicateAlert = false
    @State private var expandedAccountIDs: Set<CalendarAccountID> = []
    @FocusState private var focusedConditionField: ConditionField?

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
            _activeWeekdays = State(initialValue: dr.activeWeekdays)
            _selectedCalendarIDs = State(initialValue: dr.selectedCalendarIDs)
            _prepTime = State(initialValue: dr.prepTime)
            _commuteTime = State(initialValue: dr.commuteTime)
            _sound = State(initialValue: dr.alarmSettings.sound)
            _snoozeEnabled = State(initialValue: dr.alarmSettings.snoozeEnabled)
            _snoozeDuration = State(initialValue: dr.alarmSettings.snoozeDuration)
        case .edit(let rule):
            _name = State(initialValue: rule.name)
            _conditions = State(initialValue: rule.conditions)
            _activeWeekdays = State(initialValue: rule.activeWeekdays)
            _selectedCalendarIDs = State(initialValue: rule.selectedCalendarIDs)
            _prepTime = State(initialValue: rule.prepTime)
            _commuteTime = State(initialValue: rule.commuteTime)
            _sound = State(initialValue: rule.alarmSettings.sound)
            _snoozeEnabled = State(initialValue: rule.alarmSettings.snoozeEnabled)
            _snoozeDuration = State(initialValue: rule.alarmSettings.snoozeDuration)
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
                    if !isDefaultRule {
                        weekdaysSection
                    }
                    calendarsSection
                    timingSection
                    alarmSection
                }
                .padding(24)
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedConditionField = nil
            }
        )
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
        .onChange(of: focusedConditionField) { previousField, currentField in
            if previousField == .title, currentField != .title {
                commitPendingTitleKeyword()
            }

            if previousField == .location, currentField != .location {
                commitPendingLocationKeyword()
            }
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
                                        .foregroundStyle(isSelected ? WPStyles.primaryOrange : WPStyles.tertiaryText)

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
                                Divider().overlay(WPStyles.cardBorder).padding(.leading, 40)
                            }
                        }
                    }
                    .background(WPStyles.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private func providerIcon(for provider: CalendarProvider) -> some View {
        if provider == .apple {
            Image(systemName: "apple.logo")
                .foregroundStyle(WPStyles.primaryOrange)
                .frame(width: 16)
        } else {
            Text("G")
                .font(.headline.weight(.black))
                .foregroundStyle(WPStyles.primaryOrange)
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
                            .foregroundStyle((allSelected || someSelected) ? WPStyles.primaryOrange : WPStyles.tertiaryText)
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
                    Divider().overlay(WPStyles.cardBorder)
                    
                    ForEach(accountCalendars) { calendar in
                        let isSelected = selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains(calendar.id)

                        Button {
                            toggleCalendar(calendar.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? WPStyles.primaryOrange : WPStyles.tertiaryText)

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
                            Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)
                        }
                    }
                }
            }
            .background(WPStyles.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
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
                focus: $focusedConditionField,
                focusField: .title,
                placeholder: "keyword",
                onAdd: commitPendingTitleKeyword,
                onRemove: { keyword in conditions.removeAll { $0 == .titleContains(keyword) } }
            )

            conditionGroup(
                icon: "mappin.circle.fill",
                label: "Location contains",
                values: conditions.compactMap {
                    if case .locationContains(let v) = $0 { return v } else { return nil }
                },
                newValue: $newLocationKeyword,
                focus: $focusedConditionField,
                focusField: .location,
                placeholder: "place or address",
                onAdd: commitPendingLocationKeyword,
                onRemove: { location in conditions.removeAll { $0 == .locationContains(location) } }
            )
        }
    }

    private func conditionGroup(
        icon: String,
        label: String,
        values: [String],
        newValue: Binding<String>,
        focus: FocusState<ConditionField?>.Binding,
        focusField: ConditionField,
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
                    .focused(focus, equals: focusField)
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

    private var weekdaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("Applies On")
                Spacer()
                if activeWeekdays != Set(1...7) {
                    Button("Every day") {
                        activeWeekdays = Set(1...7)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WPStyles.secondaryBlue)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                spacing: 8
            ) {
                ForEach(WakePlanUIConfiguration.sundayFirstWeekdays) { option in
                    weekdayToggleCell(option)
                }
            }
        }
    }

    private var alarmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Alarm")

            VStack(spacing: 0) {
                HStack {
                    Text("Sound")
                        .font(.body)
                        .foregroundStyle(WPStyles.primaryText)
                    Spacer()
                    Picker("Sound", selection: $sound) {
                        ForEach(AlarmSoundOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(WPStyles.primaryOrange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().overlay(WPStyles.cardBorder).padding(.leading, 16)

                Toggle(isOn: $snoozeEnabled) {
                    Text("Enable Snooze")
                        .font(.body)
                        .foregroundStyle(WPStyles.primaryText)
                }
                .tint(WPStyles.primaryOrange)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if snoozeEnabled {
                    Divider().overlay(WPStyles.cardBorder).padding(.leading, 16)
                    stepperRow(label: "Snooze duration", value: $snoozeDuration, range: 1...60)
                }
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

    private func weekdayToggleCell(_ option: WeekdayOption) -> some View {
        let isSelected = activeWeekdays.contains(option.weekday)

        return Button {
            if isSelected {
                guard activeWeekdays.count > 1 else { return }
                activeWeekdays.remove(option.weekday)
            } else {
                activeWeekdays.insert(option.weekday)
            }
        } label: {
            Text(option.shortLabel)
                .font(.system(size: 10, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? WPStyles.surfaceRaised : WPStyles.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? WPStyles.primaryOrange.opacity(0.8) : Color.white.opacity(0.06), lineWidth: 1)
                )
                .foregroundStyle(isSelected ? WPStyles.primaryText : WPStyles.secondaryText.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(WPStyles.secondaryText)
            .textCase(.uppercase)
    }

    private func trySave() {
        commitPendingConditions()

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

    private func commitPendingConditions() {
        commitPendingTitleKeyword()
        commitPendingLocationKeyword()
    }

    private func commitPendingTitleKeyword() {
        commitPendingCondition(
            text: &newTitleKeyword,
            makeCondition: AlarmRuleCondition.titleContains
        )
    }

    private func commitPendingLocationKeyword() {
        commitPendingCondition(
            text: &newLocationKeyword,
            makeCondition: AlarmRuleCondition.locationContains
        )
    }

    private func commitPendingCondition(
        text: inout String,
        makeCondition: (String) -> AlarmRuleCondition
    ) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else {
            text = ""
            return
        }

        let condition = makeCondition(value)
        guard !conditions.contains(condition) else {
            text = ""
            return
        }

        conditions.append(condition)
        text = ""
    }

    private func save() {
        var copy = appState.preferences
        switch mode {
        case .add:
            let newRule = AlarmRule(
                id: UUID(),
                name: name.isEmpty ? "New Rule" : name,
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
                )
            )
            if let idx = copy.alarmRules.firstIndex(where: { $0.isDefault }) {
                copy.alarmRules.insert(newRule, at: idx)
            } else {
                copy.alarmRules.append(newRule)
            }
        case .edit(let rule):
            if let idx = copy.alarmRules.firstIndex(where: { $0.id == rule.id }) {
                copy.alarmRules[idx].name = isDefaultRule ? "Default" : (name.isEmpty ? "Rule" : name)
                copy.alarmRules[idx].activeWeekdays = isDefaultRule ? Set(1...7) : activeWeekdays
                copy.alarmRules[idx].selectedCalendarIDs = selectedCalendarIDs
                copy.alarmRules[idx].conditions = isDefaultRule ? [] : conditions
                copy.alarmRules[idx].prepTime = prepTime
                copy.alarmRules[idx].commuteTime = commuteTime
                copy.alarmRules[idx].alarmSettings = RuleAlarmSettings(
                    sound: sound,
                    snoozeEnabled: snoozeEnabled,
                    snoozeDuration: snoozeDuration
                )
            }
        }
        Task { await appState.updatePreferences(copy) }
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
