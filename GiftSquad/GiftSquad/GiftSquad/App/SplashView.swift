import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.82
    @State private var logoOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var tituloReveal: CGFloat = 0
    @State private var taglineOpacity: Double = 0
    @State private var respirando = false

    var body: some View {
        ZStack {
            GSPalette.crema.ignoresSafeArea()

            GSTopWave()
                .fill(
                    LinearGradient(
                        colors: [GSPalette.mandarina, GSPalette.durazno],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 230)
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)
                .opacity(logoOpacity)

            GSBottomWave()
                .fill(
                    LinearGradient(
                        colors: [GSPalette.menta, GSPalette.oceano],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 165)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .opacity(logoOpacity)

            VStack(spacing: 26) {
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(GSPalette.mandarina)
                        .frame(width: 132, height: 132)
                        .blur(radius: 26)
                        .opacity(glowOpacity * 0.3)
                        .scaleEffect(1.12)

                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 132, height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                }
                .scaleEffect(logoScale * (respirando ? 1.03 : 1.0))
                .opacity(logoOpacity)

                VStack(spacing: 8) {
                    Text("GIFTSQUAD")
                        .font(GSFont.display(26))
                        .tracking(3)
                        .foregroundStyle(GSPalette.noche)
                        .mask {
                            Rectangle().scale(x: tituloReveal, anchor: .leading)
                        }

                    Text("Sin spoilers")
                        .font(GSFont.body(14))
                        .foregroundStyle(GSPalette.grafito)
                        .opacity(taglineOpacity)
                }
            }
        }
        .onAppear { secuencia() }
    }

    private func secuencia() {
        withAnimation(.spring(response: 0.62, dampingFraction: 0.72)) {
            logoScale = 1.0
            logoOpacity = 1
        }
        withAnimation(.easeIn(duration: 0.45).delay(0.28)) {
            glowOpacity = 1
        }
        withAnimation(.interpolatingSpring(mass: 1, stiffness: 130, damping: 14).delay(0.5)) {
            tituloReveal = 1
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.85)) {
            taglineOpacity = 1
        }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.1)) {
            respirando = true
        }
    }
}

#Preview {
    SplashView()
}
