import SwiftUI
import FirebaseFirestore

struct EditGroupView: View {
    let group: GiftGroup
    var onSaved: (GiftGroup) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var icon: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(group: GiftGroup, onSaved: @escaping (GiftGroup) -> Void) {
        self.group = group
        self.onSaved = onSaved
        _name = State(initialValue: group.name)
        _icon = State(initialValue: group.iconSymbol)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GSPalette.crema.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Editar grupo")
                            .font(GSFont.display(28))
                            .foregroundStyle(GSPalette.noche)

                        GSUnderlineField(icon: "person.3.fill") {
                            TextField("", text: $name, prompt: gsPlaceholder("Nombre del grupo"))
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
                            title: "Guardar cambios",
                            isLoading: isLoading,
                            isEnabled: !isLoading && !name.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            Task { await save() }
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

    private func save() async {
        guard let groupId = group.id else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await FirestoreService.shared.updateGroup(groupId, name: trimmedName, icon: icon)
            var updated = group
            updated.name = trimmedName
            updated.icon = icon
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EditGroupView(group: GiftGroup(name: "Familia", icon: "figure.2.and.child.holdinghands", ownerId: "x", memberIds: ["x"])) { _ in }
}
