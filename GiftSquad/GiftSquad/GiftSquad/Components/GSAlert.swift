import SwiftUI

extension View {
    @ViewBuilder
    func gsAlert<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(GSAlertModifier(isPresented: isPresented, alertContent: content))
    }
}

private struct GSAlertModifier<AlertContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder var alertContent: AlertContent
    @State private var showFullScreenCover = false
    @State private var animatedValue = false
    @State private var allowsInteraction = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showFullScreenCover) {
                ZStack {
                    if animatedValue {
                        alertContent
                            .allowsHitTesting(allowsInteraction)
                    }
                }
                .presentationBackground {
                    GSPalette.noche.opacity(0.45)
                        .allowsHitTesting(allowsInteraction)
                        .opacity(animatedValue ? 1 : 0)
                }
                .task {
                    try? await Task.sleep(for: .seconds(0.05))
                    withAnimation(.easeInOut(duration: 0.3)) { animatedValue = true }

                    try? await Task.sleep(for: .seconds(0.3))
                    allowsInteraction = true
                }
            }
            .onChange(of: isPresented) { _, newValue in
                var transaction = Transaction()
                transaction.disablesAnimations = true

                if newValue {
                    withTransaction(transaction) { showFullScreenCover = true }
                } else {
                    allowsInteraction = false
                    withAnimation(.easeInOut(duration: 0.3), completionCriteria: .removed) {
                        animatedValue = false
                    } completion: {
                        withTransaction(transaction) { showFullScreenCover = false }
                    }
                }
            }
    }
}

struct GSAlertDialog: View {
    var icon: String
    var iconTint: Color = GSPalette.oceano
    var title: String
    var message: String? = nil
    var confirmTitle: String
    var confirmIsDestructive: Bool = false
    var confirmAction: () -> Void
    var cancelTitle: String? = "Cancelar"
    var cancelAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(iconTint.gradient, in: .circle)

            VStack(spacing: 6) {
                Text(title)
                    .font(GSFont.body(17, weight: .bold))
                    .foregroundStyle(GSPalette.noche)
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message)
                        .font(GSFont.body(13))
                        .foregroundStyle(GSPalette.grafito)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }

            VStack(spacing: 10) {
                Button(action: confirmAction) {
                    Text(confirmTitle)
                        .font(GSFont.body(15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            Capsule().fill(
                                confirmIsDestructive
                                    ? AnyShapeStyle(GSPalette.alerta.gradient)
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [GSPalette.menta, GSPalette.oceano],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        )
                }
                .buttonStyle(.plain)

                if let cancelTitle, let cancelAction {
                    Button(action: cancelAction) {
                        Text(cancelTitle)
                            .font(GSFont.body(15, weight: .semibold))
                            .foregroundStyle(GSPalette.grafito)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(GSPalette.crema)
        )
        .frame(maxWidth: 320)
        .compositingGroup()
        .shadow(color: GSPalette.noche.opacity(0.2), radius: 30, y: 12)
    }
}

extension View {
    func gsConfirmDialog(
        isPresented: Binding<Bool>,
        icon: String,
        iconTint: Color = GSPalette.alerta,
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String = "Cancelar",
        isDestructive: Bool = true,
        onConfirm: @escaping () -> Void
    ) -> some View {
        gsAlert(isPresented: isPresented) {
            GSAlertDialog(
                icon: icon,
                iconTint: iconTint,
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                confirmIsDestructive: isDestructive,
                confirmAction: {
                    isPresented.wrappedValue = false
                    onConfirm()
                },
                cancelTitle: cancelTitle,
                cancelAction: { isPresented.wrappedValue = false }
            )
            .transition(.blurReplace.combined(with: .scale(0.85)))
        }
    }

    func gsErrorAlert(message: Binding<String?>) -> some View {
        gsAlert(isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            GSAlertDialog(
                icon: "exclamationmark.triangle.fill",
                iconTint: GSPalette.alerta,
                title: "Algo salió mal",
                message: message.wrappedValue ?? "",
                confirmTitle: "Entendido",
                confirmIsDestructive: false,
                confirmAction: { message.wrappedValue = nil },
                cancelTitle: nil,
                cancelAction: nil
            )
            .transition(.blurReplace.combined(with: .scale(0.85)))
        }
    }
}
