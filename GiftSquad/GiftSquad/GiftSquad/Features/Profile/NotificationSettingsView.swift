import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @State private var enabled = MessagingService.shared.isPushEnabled
    @State private var blockedBySystem = false
    @State private var isWorking = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                GSSectionLabel(title: "Notificaciones push")
                GSCard {
                    Toggle(isOn: Binding(
                        get: { enabled },
                        set: { nuevo in Task { await cambiar(nuevo) } }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recibir notificaciones")
                                .font(GSFont.body(15, weight: .semibold))
                                .foregroundStyle(GSPalette.noche)
                            Text("En este iPhone")
                                .font(GSFont.caption(12))
                                .foregroundStyle(GSPalette.grafito)
                        }
                    }
                    .tint(GSPalette.mandarina)
                    .disabled(isWorking)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }

                Text("Te avisamos cuando alguien agrega un ítem en tus grupos, cuando te suman a un Amigo Invisible y cuando se hace el sorteo. Aunque las desactives, los avisos siguen apareciendo en la campana del inicio.")
                    .font(GSFont.caption(12))
                    .foregroundStyle(GSPalette.grafito)
                    .padding(.horizontal, 4)

                if blockedBySystem {
                    GSCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Las notificaciones están bloqueadas en la configuración del iPhone.")
                                .font(GSFont.body(14, weight: .semibold))
                                .foregroundStyle(GSPalette.noche)
                            Text("Para recibirlas, activalas en Configuración > GiftSquad > Notificaciones.")
                                .font(GSFont.caption(12))
                                .foregroundStyle(GSPalette.grafito)
                            Button("Abrir Configuración") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(GSFont.body(14, weight: .semibold))
                            .foregroundStyle(GSPalette.mandarina)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                    .padding(.top, 12)
                }
            }
            .padding(16)
        }
        .background(GSPalette.crema.ignoresSafeArea())
        .navigationTitle("Preferencias de notificaciones")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refrescar() }
        .onChange(of: scenePhase) { _, fase in
            // Al volver de Configuración, actualiza el estado.
            if fase == .active { Task { await refrescar() } }
        }
    }

    private func refrescar() async {
        blockedBySystem = await MessagingService.shared.isBlockedBySystem()
        enabled = MessagingService.shared.isPushEnabled && !blockedBySystem
    }

    private func cambiar(_ nuevo: Bool) async {
        isWorking = true
        enabled = nuevo
        enabled = await MessagingService.shared.setPushEnabled(nuevo)
        blockedBySystem = await MessagingService.shared.isBlockedBySystem()
        isWorking = false
    }
}
