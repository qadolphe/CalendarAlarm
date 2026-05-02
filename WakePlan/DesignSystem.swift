import SwiftUI

public enum WPStyles {
    // MARK: - Colors
    public static let primaryOrange = Color.orange
    public static let bgGradientStart = Color(red: 0.98, green: 0.96, blue: 0.93)
    public static let bgGradientEnd = Color(red: 0.94, green: 0.97, blue: 0.99)
    public static let pillBackground = Color.orange.opacity(0.16)
    public static let pillText = Color(red: 0.76, green: 0.43, blue: 0.08)
    public static let warningBanner = Color(red: 0.82, green: 0.56, blue: 0.12)
    public static let cardBorder = Color.white.opacity(0.35)

    // MARK: - Shapes
    public static let cardCornerRadius: CGFloat = 28
    
    // MARK: - Typography
    public static let timeDisplayFont = Font.system(size: 58, weight: .bold, design: .rounded)
    public static let heroTitleFont = Font.system(size: 34, weight: .bold, design: .rounded)
}

struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [WPStyles.bgGradientStart, WPStyles.bgGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(WPStyles.primaryOrange.opacity(0.17))
                    .frame(width: 260, height: 260)
                    .blur(radius: 24)
                    .offset(x: 90, y: -40)
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
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: WPStyles.cardCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WPStyles.cardCornerRadius, style: .continuous)
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
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
