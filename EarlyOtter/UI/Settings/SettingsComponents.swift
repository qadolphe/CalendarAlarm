import SwiftUI

// Shared building blocks so every Settings page has the same background,
// section cards, rows, and banners.

struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(Color.clear.withAppBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String?
    let footer: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(WPStyles.secondaryText)
                    .padding(.leading, 4)
            }

            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 {
                            Divider()
                                .overlay(WPStyles.surfaceOutline.opacity(0.5))
                                .padding(.leading, 72)
                        }
                        row
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(WPStyles.surface)
            )

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(WPStyles.secondaryText)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// Icon, title, optional subtitle, and trailing content (a value, toggle, or button).
struct SettingsRow<Trailing: View>: View {
    let icon: String
    var iconTint: Color = WPStyles.primaryText
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            IconTile(icon, tint: iconTint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(WPStyles.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, iconTint: Color = WPStyles.primaryText, title: String, subtitle: String? = nil) {
        self.init(icon: icon, iconTint: iconTint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// A row that pushes a destination, with an optional value before the chevron.
struct SettingsNavRow<Destination: View>: View {
    let icon: String
    let title: String
    var value: String?
    var valueTint: Color = WPStyles.secondaryText
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            SettingsRow(icon: icon, title: title) {
                if let value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(valueTint)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WPStyles.tertiaryText)
            }
        }
        .buttonStyle(.plain)
    }
}

/// A row that opens a URL outside the app.
struct SettingsLinkRow: View {
    let icon: String
    var iconTint: Color = WPStyles.primaryText
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            SettingsRow(icon: icon, iconTint: iconTint, title: title) {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WPStyles.tertiaryText)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(icon: icon, title: title, subtitle: subtitle) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(WPStyles.accent)
        }
    }
}

struct StatusBanner: View {
    enum Kind {
        case notice
        case error
    }

    let text: String
    let kind: Kind

    private var tint: Color {
        kind == .error ? .red : WPStyles.accent
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind == .error ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(WPStyles.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}
