import SwiftUI

// A pushed picker, like the sound picker: how many extra alarms ring before the
// wake-up, and how far apart they are.
struct ExtraAlarmsPickerView: View {
    @Binding var selection: ExtraAlarms

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ExtraAlarmsDiagram(extras: selection)
                        .padding(.bottom, 14)

                    sectionLabel("Before wake-up")
                    list(Array(ExtraAlarms.counts), title: Self.countTitle, isSelected: { $0 == selection.count }) {
                        selection = ExtraAlarms(count: $0, spacing: selection.spacing)
                    }

                    if selection.count > 0 {
                        sectionLabel("Spacing").padding(.top, 18)
                        list(ExtraAlarms.spacings, title: { String(localized: "\($0.rawValue) minutes apart") }, isSelected: { $0 == selection.spacing }) {
                            selection = ExtraAlarms(count: selection.count, spacing: $0)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Extra Alarms")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The editor row's value, e.g. "2 · 5 min apart".
    static func rowValue(for extras: ExtraAlarms) -> String {
        extras.count == 0 ? String(localized: "None") : String(localized: "\(extras.count) · \(extras.spacing.rawValue) min apart")
    }

    private static func countTitle(_ count: Int) -> String {
        count == 0 ? String(localized: "None") : String(localized: "\(count) alarms")
    }

    private func sectionLabel(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(WPStyles.secondaryText)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }

    private func list<Value: Hashable>(
        _ values: [Value],
        title: @escaping (Value) -> String,
        isSelected: @escaping (Value) -> Bool,
        select: @escaping (Value) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.element) { index, value in
                Button {
                    select(value)
                } label: {
                    HStack(spacing: Layout.checkmarkSpacing) {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(WPStyles.accent)
                            .frame(width: Layout.checkmarkWidth, alignment: .leading)
                            .opacity(isSelected(value) ? 1 : 0)
                        Text(title(value))
                            .font(.body)
                            .foregroundStyle(WPStyles.primaryText)
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected(value) ? [.isButton, .isSelected] : .isButton)

                if index < values.count - 1 {
                    Divider().padding(.leading, Layout.separatorInset)
                }
            }
        }
        .background(WPStyles.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private enum Layout {
        static let checkmarkWidth: CGFloat = 20
        static let checkmarkSpacing: CGFloat = 12
        static let separatorInset: CGFloat = 16 + checkmarkWidth + checkmarkSpacing
    }
}

/// The alarms in order, evenly spaced, with the time between them: each extra
/// alarm, then the calculated wake-up.
private struct ExtraAlarmsDiagram: View {
    let extras: ExtraAlarms

    private var labels: [String] {
        extras.offsets.map { "\u{2212}\($0.rawValue) min" } + [String(localized: "Wake-up")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { proxy in
                let inset: CGFloat = 28
                let step = labels.count > 1 ? (proxy.size.width - inset * 2) / CGFloat(labels.count - 1) : 0
                let x = { (index: Int) in labels.count > 1 ? inset + step * CGFloat(index) : proxy.size.width / 2 }
                let lineY: CGFloat = 26

                ZStack(alignment: .topLeading) {
                    if labels.count > 1 {
                        Capsule()
                            .fill(WPStyles.accent.opacity(0.35))
                            .frame(width: step * CGFloat(labels.count - 1), height: 2)
                            .position(x: proxy.size.width / 2, y: lineY)

                        ForEach(0..<labels.count - 1, id: \.self) { gap in
                            Text("\(extras.spacing.rawValue) min")
                                .font(.caption2)
                                .foregroundStyle(WPStyles.tertiaryText)
                                .fixedSize()
                                .position(x: x(gap) + step / 2, y: lineY - 14)
                        }
                    }

                    ForEach(labels.indices, id: \.self) { index in
                        let isWakeUp = index == labels.count - 1
                        Circle()
                            .fill(isWakeUp ? WPStyles.accent : WPStyles.accent.opacity(0.6))
                            .frame(width: isWakeUp ? 18 : 12, height: isWakeUp ? 18 : 12)
                            .position(x: x(index), y: lineY)
                        Text(labels[index])
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(isWakeUp ? WPStyles.accent : WPStyles.secondaryText)
                            .fixedSize()
                            .position(x: x(index), y: lineY + 22)
                    }
                }
            }
            .frame(height: 56)
            .animation(.snappy, value: extras)

            Text(extras.count == 0
                 ? "One alarm, at your wake-up time."
                 : "Extra alarms ring before your wake-up time, and each rings on its own: stopping one doesn't stop the rest. The last alarm is always your wake-up.")
                .font(.footnote)
                .foregroundStyle(WPStyles.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(WPStyles.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
