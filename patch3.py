import re

with open("EarlyOtter/UI/Rules/RulesView.swift", "r") as f:
    content = f.read()

start_str = """    private func statusBadge(_ text: String) -> some View {"""
end_str = """    // MARK: Helpers"""

new_str = """    private func statusBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(WPStyles.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(WPStyles.surfaceRaised)
            )
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

    // MARK: Helpers"""

pattern = re.compile(re.escape(start_str) + r".*?" + re.escape(end_str), re.DOTALL)
if not pattern.search(content):
    print("Could not find pattern in RulesView.swift")
else:
    new_content = pattern.sub(new_str, content)
    with open("EarlyOtter/UI/Rules/RulesView.swift", "w") as f:
        f.write(new_content)
    print("Patched EarlyOtter/UI/Rules/RulesView.swift")
