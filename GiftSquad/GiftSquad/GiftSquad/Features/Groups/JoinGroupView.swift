import SwiftUI
import FirebaseFirestore

struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var joinedGroup: GiftGroup?

    var body: some View {
        NavigationStack {
            ZStack {
                GSPalette.crema.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Sumarme con código")
                            .font(GSFont.display(28))
                            .foregroundStyle(GSPalette.noche)

                        GSUnderlineField(icon: "qrcode") {
                            TextField("", text: $inviteCode, prompt: gsPlaceholder("Ej. AB3D5XYZ"))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }

                        if let errorMessage {
                            GSBanner(message: errorMessage, isError: true)
                        }
                        if let joinedGroup {
                            GSBanner(message: "Te sumaste a \(joinedGroup.name).", isError: false)
                        }

                        GSPrimaryButton(
                            title: "Unirme",
                            isLoading: isLoading,
                            isEnabled: !isLoading && !inviteCode.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            Task { await join() }
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(GSPalette.grafito)
                }
            }
        }
    }

    private func join() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let group = try await FirestoreService.shared.joinGroup(
                inviteCode: inviteCode.trimmingCharacters(in: .whitespaces).uppercased(),
                userId: uid
            )
            joinedGroup = group
            try await Task.sleep(nanoseconds: 700_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    JoinGroupView()
}
