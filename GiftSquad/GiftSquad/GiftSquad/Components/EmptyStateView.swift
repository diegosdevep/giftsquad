import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let primaryActionTitle: String?
    let primaryAction: (() -> Void)?
    var secondaryActionTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [GSPalette.menta, GSPalette.oceano],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(0.14)
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GSPalette.menta, GSPalette.oceano],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(GSFont.display(20))
                    .foregroundStyle(GSPalette.noche)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(GSFont.body(14))
                    .foregroundStyle(GSPalette.grafito)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                if let primaryActionTitle, let primaryAction {
                    GSPrimaryButton(
                        title: primaryActionTitle,
                        isLoading: false,
                        isEnabled: true,
                        action: primaryAction
                    )
                }
                if let secondaryActionTitle, let secondaryAction {
                    GSSwitchLink(title: secondaryActionTitle, action: secondaryAction)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "gift",
        title: "Sin ítems",
        message: "Agregá productos a tu lista.",
        primaryActionTitle: "Agregar",
        primaryAction: {}
    )
}
