import SwiftUI
import FirebaseFirestore

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🎁"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let emojis = ["🎁", "🎉", "🎄", "🎂", "💝", "🦄", "🌟", "🍰"]
    private let emojiColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

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
                            Text("Emoji")
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
                emoji: emoji,
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
