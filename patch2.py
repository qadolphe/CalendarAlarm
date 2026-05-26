import re

with open("EarlyOtter/UI/Rules/RulesView.swift", "r") as f:
    content = f.read()

start_str = """    private var navTitle: String {"""
end_str = """    private var conditionsSection: some View {"""

new_str = """    private var navTitle: String {
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
