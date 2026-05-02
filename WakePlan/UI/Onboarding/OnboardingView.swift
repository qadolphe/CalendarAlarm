import SwiftUI

struct OnboardingView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    var onFinish: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(WPStyles.surfaceRaised)
                            .frame(width: 132, height: 132)
                        Image(systemName: "alarm.waves.left.and.right.fill")
                            .font(.system(size: 62))
                            .foregroundStyle(WPStyles.primaryOrange)
                    }

                    VStack(spacing: 10) {
                        Text("Welcome to \(AppConfiguration.appName)")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(WPStyles.primaryText)
                        Text("Your alarm, perfectly synced with your morning schedule.")
                            .font(.body)
                            .foregroundStyle(WPStyles.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("How it works")
                        .font(.caption.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(WPStyles.secondaryText)

                    featureRow(icon: "calendar.badge.clock", color: WPStyles.primaryOrange, title: "Calendar Sync", desc: "We scan your first event of the day.")
                    featureRow(icon: "car.fill", color: WPStyles.secondaryBlue, title: "Smart Buffers", desc: "Automatically subtracts prep and commute time.")
                    featureRow(icon: "moon.zzz.fill", color: .indigo, title: "Sleep In", desc: "No morning meetings? The alarm defers to your preferred limit.")
                }
                .cardStyle()

                Spacer()

                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            await appState.requestCalendarAccess()
                            await appState.requestAlarmAccess()
                            finish()
                        }
                    }) {
                        Text("Grant Access & Start")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(WPStyles.primaryOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Text("Data never leaves your device.")
                        .font(.caption)
                        .foregroundStyle(WPStyles.tertiaryText)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(WPStyles.primaryText)
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(WPStyles.secondaryText)
                    .lineLimit(2)
            }
        }
    }

    private func finish() {
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}
