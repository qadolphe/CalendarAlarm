import SwiftUI

// MARK: - Schedule (typealias kept for any lingering references)
typealias ScheduleView = SettingsView

// MARK: - Settings tab (app-level configuration only)

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    appSettingsLinks
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: App settings nav links

    private var appSettingsLinks: some View {
        VStack(spacing: 0) {
            navRow(title: "Event Filters", icon: "line.3.horizontal.decrease.circle") {
                EventFilterSettingsView(appState: appState)
            }
            Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)
            navRow(title: "Keywords", icon: "text.magnifyingglass") {
                KeywordRulesEditorView(appState: appState)
            }
            Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)
            navRow(title: "Permissions", icon: "lock.shield") {
                PermissionsView(appState: appState)
            }
            Divider().overlay(WPStyles.cardBorder).padding(.leading, 56)
            Button("Refresh App State") {
                Task { await appState.load() }
            }
            .foregroundStyle(WPStyles.primaryOrange)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(WPStyles.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(WPStyles.cardBorder, lineWidth: 1))
    }

    private func navRow<D: View>(title: String, icon: String, @ViewBuilder destination: () -> D) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(WPStyles.primaryOrange)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(WPStyles.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WPStyles.tertiaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

