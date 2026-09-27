import SwiftUI

public enum WPStyles {
    // "Night Swim": the onboarding otter's starry water. Wake-ups are starlight gold,
    // events are bioluminescent aqua.
    public static let accent = Color(red: 0.957, green: 0.776, blue: 0.416)
    public static let accentMuted = Color(red: 0.72, green: 0.58, blue: 0.30)
    public static let eventTint = Color(red: 0.431, green: 0.827, blue: 0.878)
    public static let successGreen = Color(red: 0.19, green: 0.82, blue: 0.35)
    public static let background = Color(red: 0.039, green: 0.063, blue: 0.125)
    public static let bgGradientStart = Color(red: 0.027, green: 0.047, blue: 0.102)
    public static let bgGradientEnd = Color(red: 0.055, green: 0.09, blue: 0.169)
    public static let surface = Color(red: 0.078, green: 0.122, blue: 0.212)
    public static let surfaceRaised = Color(red: 0.114, green: 0.165, blue: 0.271)
    public static let surfaceOutline = Color(red: 0.22, green: 0.28, blue: 0.40)
    public static let primaryText = Color(red: 0.933, green: 0.941, blue: 0.957)
    public static let secondaryText = Color(red: 0.651, green: 0.698, blue: 0.784)
    public static let tertiaryText = Color.white.opacity(0.58)
    /// Text and icons drawn on an accent fill; white is too faint on the pastel.
    public static let onAccent = background
    public static let cardBorder = surfaceOutline.opacity(0.75)
    public static let tabSelection = Color.white

    public static let cardCornerRadius: CGFloat = 28
    public static let timeDisplayFont = Font.system(size: 72, weight: .bold, design: .rounded)
}

struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [WPStyles.bgGradientStart, WPStyles.bgGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            // Starlight along the top, a faint glow off the water below.
            .overlay(alignment: .top) {
                Ellipse()
                    .fill(WPStyles.accent.opacity(0.10))
                    .frame(width: 520, height: 240)
                    .blur(radius: 90)
                    .offset(y: -140)
            }
            .overlay(alignment: .bottomLeading) {
                Ellipse()
                    .fill(WPStyles.eventTint.opacity(0.07))
                    .frame(width: 320, height: 220)
                    .blur(radius: 80)
                    .offset(x: -80, y: 60)
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
    }
}

/// A rounded square holding an SF Symbol, used as the leading icon of list rows.
struct IconTile: View {
    let systemImage: String
    let tint: Color
    let fill: Color

    init(_ systemImage: String, tint: Color = WPStyles.primaryText, fill: Color = WPStyles.surfaceRaised) {
        self.systemImage = systemImage
        self.tint = tint
        self.fill = fill
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(WPStyles.accent)
            .foregroundStyle(WPStyles.onAccent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CapsuleButtonLabel(configuration: configuration, foreground: WPStyles.onAccent, fill: WPStyles.accent)
    }
}

/// The quieter sibling of `PrimaryCapsuleButtonStyle`, for secondary actions.
struct SecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CapsuleButtonLabel(configuration: configuration, foreground: WPStyles.primaryText, fill: WPStyles.surfaceRaised)
    }
}

private struct CapsuleButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let foreground: Color
    let fill: Color

    var body: some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}
