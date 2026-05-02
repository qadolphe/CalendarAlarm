import SwiftUI

public enum WPStyles {
    public static let primaryOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    public static let secondaryBlue = Color(red: 0.04, green: 0.52, blue: 1.0)
    public static let successGreen = Color(red: 0.19, green: 0.82, blue: 0.35)
    public static let background = Color(red: 0.07, green: 0.07, blue: 0.07)
    public static let bgGradientStart = Color(red: 0.04, green: 0.04, blue: 0.04)
    public static let bgGradientEnd = Color(red: 0.11, green: 0.11, blue: 0.11)
    public static let surface = Color(red: 0.12, green: 0.12, blue: 0.12)
    public static let surfaceRaised = Color(red: 0.16, green: 0.16, blue: 0.16)
    public static let surfaceOutline = Color(red: 0.32, green: 0.27, blue: 0.20)
    public static let primaryText = Color(red: 0.89, green: 0.89, blue: 0.89)
    public static let secondaryText = Color(red: 0.85, green: 0.76, blue: 0.68)
    public static let tertiaryText = Color.white.opacity(0.58)
    public static let pillBackground = primaryOrange.opacity(0.16)
    public static let pillText = Color(red: 1.0, green: 0.78, blue: 0.53)
    public static let warningBanner = primaryOrange
    public static let cardBorder = surfaceOutline.opacity(0.75)

    public static let cardCornerRadius: CGFloat = 28
    public static let timeDisplayFont = Font.system(size: 72, weight: .bold, design: .rounded)
    public static let heroTitleFont = Font.system(size: 34, weight: .bold, design: .rounded)
}

struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [WPStyles.bgGradientStart, WPStyles.bgGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(WPStyles.primaryOrange.opacity(0.14))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 120, y: -90)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(WPStyles.secondaryBlue.opacity(0.08))
                    .frame(width: 240, height: 240)
                    .blur(radius: 50)
                    .offset(x: -80, y: 80)
            }
            .ignoresSafeArea()

            content
        }
    }
}

public extension View {
    func withAppBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
    
    func cardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: WPStyles.cardCornerRadius, style: .continuous)
                    .fill(WPStyles.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WPStyles.cardCornerRadius, style: .continuous)
                    .stroke(WPStyles.cardBorder, lineWidth: 1)
            )
    }

    func insetSurfaceStyle(cornerRadius: CGFloat = 24) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(WPStyles.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(WPStyles.cardBorder, lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(WPStyles.primaryOrange)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
