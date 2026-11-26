import SwiftUI
import FirebaseFirestore

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = GroupIcon.fallback
    @State private var isLoading = false
    @State private var errorMessage: String?


    var body: some View {
        NavigationStack {
            ZStack {
                GSPalette.crema.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Nuevo grupo")
                            .font(GSFont.display(28))
                            .foregroundStyle(GSPalette.noche)

                        GSUnderlineField(icon: "person.3.fill") {
                            TextField("", text: $name, prompt: gsPlaceholder("Nombre (ej. Familia Maidana)"))
                                .textInputAutocapitalization(.words)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Ícono")
                                .font(GSFont.caption())
                                .foregroundStyle(GSPalette.grafito)

                            GroupIconPicker(selection: $icon)
                        }

                        if let errorMessage {
                            GSBanner(message: LocalizedStringKey(stringLiteral: errorMessage), isError: true)
                        }

                        GSPrimaryButton(
                            title: "Crear grupo",
                            isLoading: isLoading,
                            isEnabled: !isLoading && !name.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            Task { await create() }
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

    private func create() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let group = GiftGroup(
                name: name.trimmingCharacters(in: .whitespaces),
                icon: icon,
                ownerId: uid,
                memberIds: [uid]
            )
            _ = try await FirestoreService.shared.createGroup(group)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CreateGroupView()
}
