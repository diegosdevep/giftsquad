import SwiftUI
import FirebaseFirestore

struct EditGroupView: View {
    let group: GiftGroup
    var onSaved: (GiftGroup) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let emojis = ["🎁", "🎉", "🎄", "🎂", "💝", "🦄", "🌟", "🍰", "👨‍👩‍👧‍👦", "🏠", "❤️", "✨"]
    private let emojiColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    init(group: GiftGroup, onSaved: @escaping (GiftGroup) -> Void) {
        self.group = group
        self.onSaved = onSaved
        _name = State(initialValue: group.name)
        _emoji = State(initialValue: group.emoji ?? "🎁")
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
                            Text("Foto del grupo")
                                .font(GSFont.caption())
                                .foregroundStyle(GSPalette.grafito)

                            LazyVGrid(columns: emojiColumns, spacing: 10) {
                                ForEach(emojis, id: \.self) { option in
                                    Button {
                                        emoji = option
                                    } label: {
                                        Text(option)
                                            .font(.system(size: 26))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(emoji == option ? GSPalette.oceano.opacity(0.14) : Color.white)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .strokeBorder(
                                                        emoji == option ? GSPalette.oceano : GSPalette.grafito.opacity(0.15),
                                                        lineWidth: emoji == option ? 2 : 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if let errorMessage {
                            GSBanner(message: errorMessage, isError: true)
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
            try await FirestoreService.shared.updateGroup(groupId, name: trimmedName, emoji: emoji)
            var updated = group
            updated.name = trimmedName
            updated.emoji = emoji
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EditGroupView(group: GiftGroup(name: "Familia", emoji: "👨‍👩‍👧‍👦", ownerId: "x", memberIds: ["x"])) { _ in }
}
