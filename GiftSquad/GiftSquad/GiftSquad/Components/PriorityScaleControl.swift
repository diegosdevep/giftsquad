import SwiftUI

struct PriorityScaleControl: View {
    @Binding var priority: ItemPriority

    private let steps = ItemPriority.allCases
    private let trackHeight: CGFloat = 6
    private let thumbSize: CGFloat = 20
    private let fillFractions: [CGFloat] = [0.25, 0.5, 0.75, 1.0]

    private var selectedIndex: Int { steps.firstIndex(of: priority) ?? 0 }
    private var fraction: CGFloat { fillFractions[selectedIndex] }

    private var gradientColors: [Color] {
        let colors = steps.prefix(selectedIndex + 1).map(\.color)
        return colors.count > 1 ? Array(colors) : [colors[0], colors[0]]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Prioridad")
                    .font(GSFont.caption())
                    .foregroundStyle(GSPalette.grafito)
                Spacer()
                Text(priority.label)
                    .font(GSFont.caption(12))
                    .foregroundStyle(priority.color)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let inset = thumbSize / 2
                let usableWidth = max(width - inset * 2, 1)
                let thumbX = inset + usableWidth * fraction

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(GSPalette.grafito.opacity(0.15))
                        .frame(height: trackHeight)

                    LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                        .frame(width: max(usableWidth * fraction, trackHeight), height: trackHeight)
                        .clipShape(Capsule())

                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay(Circle().strokeBorder(priority.color, lineWidth: 3))
                        .shadow(color: GSPalette.noche.opacity(0.18), radius: 3, y: 1)
                        .position(x: thumbX, y: thumbSize / 2)
                }
                .frame(height: thumbSize)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in
                    select(atX: location.x, inset: inset, usableWidth: usableWidth)
                }
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in select(atX: value.location.x, inset: inset, usableWidth: usableWidth) }
                )
            }
            .frame(height: thumbSize)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: fraction)
        }
        .sensoryFeedback(.selection, trigger: priority)
    }

    private func select(atX x: CGFloat, inset: CGFloat, usableWidth: CGFloat) {
        let rawFraction = min(max(x - inset, 0), usableWidth) / usableWidth
        let index = fillFractions.enumerated()
            .min(by: { abs($0.element - rawFraction) < abs($1.element - rawFraction) })?
            .offset ?? 0
        guard steps[index] != priority else { return }
        priority = steps[index]
    }
}

#Preview {
    struct Wrapper: View {
        @State var p: ItemPriority = .medium
        var body: some View {
            VStack(spacing: 24) {
                PriorityScaleControl(priority: $p)
            }
            .padding(24)
        }
    }
    return Wrapper()
}
