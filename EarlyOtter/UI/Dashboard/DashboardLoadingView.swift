import SwiftUI

struct DashboardLoadingView: View {
    @State private var stars: [Star] = Star.makeField(count: 54)

    var body: some View {
        ZStack {
            RadialGradient(
                stops: [
                    .init(color: Color(red: 0.06, green: 0.20, blue: 0.40), location: 0.00),
                    .init(color: Color(red: 0.02, green: 0.07, blue: 0.16), location: 0.42),
                    .init(color: .black, location: 0.85)
                ],
                center: .center,
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()

            starsLayer
                .ignoresSafeArea()

            otterLayer

            VStack {
                Spacer()
                Text(AppConfiguration.appName)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(WPStyles.primaryOrange)
                    .opacity(0.92)
                    .padding(.bottom, 56)
            }
        }
    }

    private var starsLayer: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for star in stars {
                    let twinkle = 0.5 + 0.5 * sin(t * star.speed + star.phase)
                    let alpha = star.baseOpacity * (0.3 + 0.7 * twinkle)
                    let rect = CGRect(
                        x: star.x * size.width - star.size / 2,
                        y: star.y * size.height - star.size / 2,
                        width: star.size,
                        height: star.size
                    )
                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.white.opacity(alpha))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var otterLayer: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let bob = CGFloat(sin(t * 1.0) * 5)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                WPStyles.primaryOrange.opacity(0.20),
                                WPStyles.primaryOrange.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 440)
                    .blur(radius: 18)

                Image("OtterSwim")
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.25)
                    .blur(radius: 38)
                    .mask {
                        Ellipse()
                            .fill(Color.black)
                            .blur(radius: 90)
                    }
                    .opacity(0.85)

                Image("OtterSwim")
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.10)
                    .mask {
                        Ellipse()
                            .fill(Color.black)
                            .padding(.horizontal, 70)
                            .padding(.vertical, 48)
                            .blur(radius: 45)
                    }
            }
            .offset(y: bob)
        }
    }
}

private struct Star {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let baseOpacity: Double
    let phase: Double
    let speed: Double

    static func makeField(count: Int) -> [Star] {
        var result: [Star] = []
        var attempts = 0
        while result.count < count && attempts < count * 8 {
            attempts += 1
            let x = CGFloat.random(in: 0.03...0.97)
            let y = CGFloat.random(in: 0.03...0.97)
            let dx = x - 0.5
            let dy = y - 0.5
            if hypot(dx, dy) < 0.14 { continue }
            result.append(
                Star(
                    x: x,
                    y: y,
                    size: .random(in: 1.2...3.4),
                    baseOpacity: .random(in: 0.45...1.0),
                    phase: .random(in: 0...(.pi * 2)),
                    speed: .random(in: 0.8...2.2)
                )
            )
        }
        return result
    }
}

#Preview {
    DashboardLoadingView()
}
