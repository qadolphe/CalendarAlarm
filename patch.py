import re

with open("EarlyOtter/UI/Rules/RulesView.swift", "r") as f:
    content = f.read()

# Replace from @State private var showDuplicateAlert to the end of var body and navTitle, nameSection, enabledSection
start_str = """    @State private var showDuplicateAlert = false"""
end_str = """
    private var conditionsSection: some View {"""

new_str = """    @State private var showDuplicateAlert = false
    @State private var expandedAccountIDs: Set<CalendarAccountID> = []
    @FocusState private var focusedConditionField: ConditionField?

    @State private var selectedTab = 0 // 0 = Trigger Criteria, 1 = Alarm Actions

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
        }
    }

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            VStack(spacing: 0) {
                if !isDefaultRule {
                    enabledAndNameSection
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                }

                Picker("Editor Mode", selection: $selectedTab) {
                    Text("Trigger Criteria").tag(0)
                    Text("Alarm Actions").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .disabled(!isDefaultRule && !isEnabled)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        if selectedTab == 0 {
                            if !isDefaultRule {
                                weekdaysSection
                                conditionsSection
                            }
                            calendarsSection
                        } else {
                            timingSection
                            alarmSection
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .disabled(!isDefaultRule && !isEnabled)
                    .opacity((!isDefaultRule && !isEnabled) ? 0.5 : 1.0)
                }
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

    private var navTitle: String {
        if isDefaultRule { return "Default Rule" }
        if mode.isAdd { return "New Rule" }
        return name.isEmpty ? "Rule" : name
    }

    private var enabledAndNameSection: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isEnabled) {
                Text("Enable Rule")
                    .font(.body.weight(.medium))
                    .foregroundStyle(WPStyles.primaryText)
            }
            .tint(WPStyles.primaryOrange)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().overlay(WPStyles.cardBorder).padding(.leading, 16)

            HStack {
                Text("Name")
                    .font(.body)
                    .foregroundStyle(WPStyles.primaryText)
                Spacer()
                TextField("e.g. Doctor Appointments", text: $name)
                    .font(.body)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(WPStyles.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(WPStyles.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1)
        )
    }

    private var conditionsSection: some View {"""

pattern = re.compile(re.escape(start_str) + r".*?" + re.escape(end_str), re.DOTALL)
if not pattern.search(content):
    print("Could not find pattern in RulesView.swift")
else:
    new_content = pattern.sub(new_str, content)
    with open("EarlyOtter/UI/Rules/RulesView.swift", "w") as f:
        f.write(new_content)
    print("Patched EarlyOtter/UI/Rules/RulesView.swift")
