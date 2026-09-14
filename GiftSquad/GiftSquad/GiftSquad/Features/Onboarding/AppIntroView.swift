import SwiftUI

struct AppIntroView: View {
    var onFinish: () -> Void
    @State private var page = 0

    private var lastPage: Int { Self.points.count - 1 }

    var body: some View {
        ZStack(alignment: .top) {
            GSPalette.crema.ignoresSafeArea()

            GSTopWave()
                .fill(
                    LinearGradient(
                        colors: [GSPalette.menta, GSPalette.oceano],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 150)
                .frame(maxWidth: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 74)

                TabView(selection: $page) {
                    ForEach(Array(Self.points.enumerated()), id: \.offset) { index, point in
                        pageContent(point)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: page)

                pageIndicator
                    .padding(.top, 6)
                    .padding(.bottom, 16)

                VStack(spacing: 10) {
                    GSPrimaryButton(
                        title: page == lastPage ? "Empezar" : "Siguiente",
                        isLoading: false,
                        isEnabled: true
                    ) {
                        if page == lastPage {
                            onFinish()
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                        }
                    }

                    if page == lastPage {
                        Text("Podés volver a ver esto cuando quieras desde el ícono ⓘ del home.")
                            .font(GSFont.caption(11))
                            .foregroundStyle(GSPalette.grafito)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<Self.points.count, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Self.points[page].tint : GSPalette.grafito.opacity(0.22))
                    .frame(width: index == page ? 22 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: page)
            }
        }
    }

    private func pageContent(_ point: Point) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(point.tint.opacity(0.14)).frame(width: 96, height: 96)
                    Image(systemName: point.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(point.tint)
                }
                .padding(.top, 4)

                VStack(spacing: 6) {
                    Text(point.title)
                        .font(GSFont.display(22))
                        .foregroundStyle(GSPalette.noche)

                    Text(point.tagline)
                        .font(GSFont.body(14))
                        .foregroundStyle(GSPalette.grafito)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(point.steps, id: \.self) { step in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(point.tint)
                                .padding(.top, 1)
                            Text(step)
                                .font(GSFont.body(13.5))
                                .foregroundStyle(GSPalette.noche)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(point.tint.opacity(0.07))
                )
                .padding(.horizontal, 22)
            }
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private struct Point: Identifiable {
        let id: String
        let icon: String
        let tint: Color
        let title: String
        let tagline: String
        let steps: [String]
    }

    private static let points: [Point] = [
        Point(
            id: "grupos",
            icon: "person.3.fill",
            tint: GSPalette.oceano,
            title: "Grupos",
            tagline: "Cada grupo es un espacio compartido con tu familia, amigos o pareja.",
            steps: [
                "Creá un grupo nuevo o sumate a uno con el código de invitación que te compartan.",
                "Adentro vas a ver la lista de regalos de cada miembro del grupo.",
                "Podés estar en todos los grupos que quieras a la vez: familia, amigos, pareja…",
            ]
        ),
        Point(
            id: "lista",
            icon: "gift.fill",
            tint: GSPalette.menta,
            title: "Tu lista",
            tagline: "Armá tu lista de deseos para que la vea todo tu grupo.",
            steps: [
                "Pegá el link del producto y armamos la ficha por vos: foto, precio y variantes.",
                "Marcá la prioridad de cada ítem para que sepan qué te interesa más.",
                "La podés editar o sacar ítems cuando quieras, sin depender de nadie.",
            ]
        ),
        Point(
            id: "reservas",
            icon: "hand.raised.fill",
            tint: GSPalette.mandarina,
            title: "Reservas",
            tagline: "Reservá el regalo de alguien de tu grupo sin que se entere.",
            steps: [
                "Elegí un ítem de la lista de otro miembro y tocá \"Reservar este regalo\".",
                "Mientras esté reservado, nadie más de ningún grupo lo puede tomar.",
                "El dueño de la lista nunca sabe quién lo reservó ni cuándo.",
                "Cuando se lo entregues, marcalo como entregado y pasa al historial del grupo.",
            ]
        ),
        Point(
            id: "amigoInvisible",
            icon: "theatermasks.fill",
            tint: GSPalette.durazno,
            title: "Amigo invisible",
            tagline: "Sorteá quién le regala a quién dentro de un grupo.",
            steps: [
                "Armá el evento con los participantes y las exclusiones que necesites (ej. una pareja).",
                "Corré el sorteo: cada uno va a ver solo a quién le toca regalarle, nadie más.",
                "Podés mostrarle tu lista a quien te regale a vos para darle ideas.",
            ]
        ),
    ]
}

#Preview {
    AppIntroView(onFinish: {})
}
