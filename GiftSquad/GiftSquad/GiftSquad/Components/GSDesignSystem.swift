import SwiftUI

enum GSPalette {
    static let crema = Color(gsHex: 0xFFFBF5)
    static let noche = Color(gsHex: 0x211733)
    static let grafito = Color(gsHex: 0x9C93AC)
    static let mandarina = Color(gsHex: 0xFF6A1A)
    static let durazno = Color(gsHex: 0xFFA23E)
    static let menta = Color(gsHex: 0x00C896)
    static let oceano = Color(gsHex: 0x2952E3)
    static let alerta = Color(gsHex: 0xEB4034)
}

enum GSFont {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

extension Color {
    init(gsHex hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct GSToolbarIcon: View {
    let systemName: String
    var background: Color = GSPalette.mandarina
    var foreground: Color = .white
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle().fill(background).frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.41, weight: .semibold))
                .foregroundStyle(foreground)
        }
    }
}

struct GSTopWave: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.30))
        p.addCurve(
            to: CGPoint(x: w * 0.52, y: h * 0.60),
            control1: CGPoint(x: w * 0.86, y: h * 0.52),
            control2: CGPoint(x: w * 0.68, y: h * 0.32)
        )
        p.addCurve(
            to: CGPoint(x: 0, y: h * 0.40),
            control1: CGPoint(x: w * 0.34, y: h * 0.86),
            control2: CGPoint(x: w * 0.14, y: h * 0.60)
        )
        p.closeSubpath()
        return p
    }
}

struct GSBottomWave: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.62))
        p.addCurve(
            to: CGPoint(x: w * 0.48, y: h * 0.32),
            control1: CGPoint(x: w * 0.18, y: h * 0.40),
            control2: CGPoint(x: w * 0.32, y: h * 0.62)
        )
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.52),
            control1: CGPoint(x: w * 0.66, y: h * 0.06),
            control2: CGPoint(x: w * 0.84, y: h * 0.28)
        )
        p.closeSubpath()
        return p
    }
}

struct GSBanner: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            Text(message)
                .font(GSFont.body(14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(isError ? GSPalette.alerta : GSPalette.oceano)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill((isError ? GSPalette.alerta : GSPalette.oceano).opacity(0.12))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct GSSwitchLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GSFont.body(13, weight: .bold))
                .foregroundStyle(GSPalette.mandarina)
        }
        .buttonStyle(.plain)
    }
}

struct GSPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(GSFont.body(16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [GSPalette.menta, GSPalette.oceano],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
            .shadow(color: GSPalette.oceano.opacity(0.35), radius: 12, y: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct GSUnderlineField<Content: View>: View {
    let icon: String
    var iconColor: Color = GSPalette.grafito
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(iconColor.opacity(0.12)).frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                content
                    .font(GSFont.body(16))
                    .foregroundStyle(GSPalette.noche)
                    .tint(GSPalette.mandarina)
            }
            Rectangle()
                .fill(GSPalette.grafito.opacity(0.2))
                .frame(height: 1)
        }
    }
}

func gsPlaceholder(_ text: String) -> Text {
    Text(text).foregroundStyle(GSPalette.grafito.opacity(0.6))
}

struct GSFieldLabel: View {
    let icon: String
    var iconColor: Color = GSPalette.grafito
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(iconColor)
            Text(title.uppercased())
                .font(GSFont.caption(11))
                .tracking(1)
        }
        .foregroundStyle(GSPalette.grafito)
    }
}

struct GSPillField<Content: View>: View {
    var icon: String? = nil
    var iconColor: Color = GSPalette.grafito
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            content
        }
        .font(GSFont.body(15))
        .foregroundStyle(GSPalette.noche)
        .tint(GSPalette.mandarina)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GSPalette.grafito.opacity(0.06))
        )
    }
}

struct GSSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(GSFont.caption(12))
            .tracking(1.2)
            .foregroundStyle(GSPalette.grafito)
    }
}

struct GSCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(GSPalette.grafito.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: GSPalette.noche.opacity(0.03), radius: 10, y: 4)
    }
}

extension View {
    func gsCardStyle(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(GSPalette.grafito.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: GSPalette.noche.opacity(0.03), radius: 10, y: 4)
    }
}

struct GSRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    var photoURL: URL? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(iconColor.opacity(0.12)).frame(width: 40, height: 40)
                if let photoURL {
                    AsyncImage(url: photoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(iconColor)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(GSFont.body(15, weight: .semibold))
                    .foregroundStyle(GSPalette.noche)
                if let subtitle {
                    Text(subtitle)
                        .font(GSFont.caption(12))
                        .foregroundStyle(GSPalette.grafito)
                }
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GSPalette.grafito.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct GSDivider: View {
    var body: some View {
        Rectangle()
            .fill(GSPalette.grafito.opacity(0.12))
            .frame(height: 1)
            .padding(.leading, 68)
    }
}

private final class GSPopGestureDisablingViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
}

private struct GSDisableInteractivePop: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        GSPopGestureDisablingViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
}

extension View {
    func gsDisableInteractivePop() -> some View {
        background(GSDisableInteractivePop())
    }
}

struct GSSkeleton: View {
    var cornerRadius: CGFloat = 8
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(GSPalette.grafito.opacity(0.12))
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, GSPalette.grafito.opacity(0.20), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: max(geo.size.width * 0.5, 40))
                    .offset(x: phase * geo.size.width * 1.6)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct GSSkeletonRow: View {
    var showSubtitle: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            GSSkeleton(cornerRadius: 20).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                GSSkeleton().frame(width: 140, height: 13)
                if showSubtitle {
                    GSSkeleton().frame(width: 80, height: 10)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct GSSkeletonCard: View {
    var body: some View {
        HStack(spacing: 14) {
            GSSkeleton(cornerRadius: 14).frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 8) {
                GSSkeleton().frame(width: 150, height: 14)
                GSSkeleton().frame(width: 90, height: 11)
            }
            Spacer()
            GSSkeleton().frame(width: 50, height: 14)
        }
        .padding(12)
        .gsCardStyle()
    }
}
