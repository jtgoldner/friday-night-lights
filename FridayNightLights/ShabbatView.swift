import SwiftUI

struct ShabbatView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("BackgroundTop"), Color("BackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ForEach(stars, id: \.0) { star in
                    Circle()
                        .fill(Color.white.opacity(star.2))
                        .frame(width: star.3, height: star.3)
                        .position(x: geo.size.width * star.0, y: geo.size.height * star.1)
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                Text("🕯️ 🕯️")
                    .font(.system(size: 64))
                    .padding(.bottom, 40)

                Text("שַׁבָּת שָׁלוֹם")
                    .font(.custom("Georgia", size: 38))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 120, height: 0.5)
                    .padding(.bottom, 16)

                Text("Shabbat Shalom")
                    .font(.custom("Georgia", size: 28))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 32)

                if let candleTime = appState.candleLightingFormattedTime {
                    Text("Candle lighting was at \(candleTime)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 8)
                }

                if let havdalahTime = appState.havdalahFormattedTime {
                    Text("Havdalah Saturday night at \(havdalahTime)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }

    private let stars: [(CGFloat, CGFloat, Double, CGFloat)] = [
        (0.15, 0.12, 0.3, 2),
        (0.82, 0.18, 0.2, 1.5),
        (0.47, 0.08, 0.25, 1.5),
        (0.88, 0.35, 0.2, 1),
        (0.08, 0.42, 0.15, 2),
        (0.93, 0.58, 0.2, 1.5),
        (0.22, 0.75, 0.15, 1),
        (0.75, 0.82, 0.2, 2),
        (0.38, 0.92, 0.15, 1.5),
    ]
}
