import SwiftUI

struct GroupOnboardingView: View {
    private struct GroupChip: Identifiable, Equatable {
        let id: String
        var name: String
        var emoji: String
        var isCustom: Bool
    }

    private struct FlowLayout: Layout {
        var spacing: CGFloat = 10

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let maxWidth = proposal.width ?? .infinity
            var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            return CGSize(width: maxWidth, height: y + rowHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > bounds.minX + bounds.width, x > bounds.minX {
                    x = bounds.minX
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
    }

    @State private var auth = AuthService.shared
    @State private var selectedIds: Set<String> = []
    @State private var customChips: [GroupChip] = []
    @State private var isAddingCustom = false
    @State private var newGroupName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var newGroupFieldFocused: Bool

    private let selectedColor = GSPalette.oceano

    private var recommendedChips: [GroupChip] {
        AuthService.recommendedGroups.map { GroupChip(id: $0.name, name: $0.name, emoji: $0.emoji, isCustom: false) }
    }

    private var allChips: [GroupChip] { recommendedChips + customChips }

    var body: some View {
        ZStack(alignment: .bottom) {
            GSPalette.crema.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    FlowLayout(spacing: 10) {
                        ForEach(allChips) { chip in
                            chipView(chip)
                        }
                        addChip
                    }

                    if let errorMessage {
                        GSBanner(message: errorMessage, isError: true)
                    }

                    Spacer(minLength: 140)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            footer
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Elegí tus grupos")
                .font(GSFont.display(30))
                .foregroundStyle(GSPalette.noche)
            Text("Tocá los que te sirvan o creá los tuyos. Podés cambiarlo cuando quieras.")
                .font(GSFont.body(14))
                .foregroundStyle(GSPalette.grafito)
        }
    }

    private func chipView(_ chip: GroupChip) -> some View {
        let isSelected = selectedIds.contains(chip.id)
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                if isSelected {
                    selectedIds.remove(chip.id)
                } else {
                    selectedIds.insert(chip.id)
                }
            }
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black))
                } else {
                    Text(chip.emoji).font(.system(size: 15))
                }
                Text(chip.name)
                    .font(GSFont.body(15, weight: .semibold))
                if chip.isCustom {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                            customChips.removeAll { $0.id == chip.id }
                            selectedIds.remove(chip.id)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .black))
                            .opacity(0.55)
                    }
                    .padding(.leading, 2)
                }
            }
            .foregroundStyle(isSelected ? .white : GSPalette.noche)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule().fill(isSelected ? selectedColor : Color.white)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? .clear : GSPalette.grafito.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    @ViewBuilder
    private var addChip: some View {
        if isAddingCustom {
            HStack(spacing: 6) {
                TextField("", text: $newGroupName, prompt: gsPlaceholder("Nombre del grupo"))
                    .font(GSFont.body(15, weight: .semibold))
                    .foregroundStyle(GSPalette.noche)
                    .textInputAutocapitalization(.words)
                    .focused($newGroupFieldFocused)
                    .submitLabel(.done)
                    .onSubmit(commitCustomGroup)
                    .fixedSize()
                Button(action: commitCustomGroup) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            newGroupName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? GSPalette.grafito.opacity(0.3)
                                : GSPalette.menta
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().strokeBorder(GSPalette.mandarina, lineWidth: 1.5))
        } else {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    isAddingCustom = true
                }
                newGroupFieldFocused = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .black))
                    Text("Nuevo grupo")
                        .font(GSFont.body(15, weight: .semibold))
                }
                .foregroundStyle(GSPalette.mandarina)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule().strokeBorder(GSPalette.mandarina.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            GSPrimaryButton(
                title: "Continuar",
                isLoading: isSaving,
                isEnabled: !isSaving
            ) {
                Task { await finish() }
            }
            GSSwitchLink(title: "Saltear por ahora") {
                Task { await finish(skip: true) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [GSPalette.crema.opacity(0), GSPalette.crema, GSPalette.crema],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func commitCustomGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let chip = GroupChip(id: UUID().uuidString, name: trimmed, emoji: "🎁", isCustom: true)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            customChips.append(chip)
            selectedIds.insert(chip.id)
            newGroupName = ""
            isAddingCustom = false
        }
    }

    private func finish(skip: Bool = false) async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let selected: [(name: String, emoji: String)] = skip ? [] : allChips
            .filter { selectedIds.contains($0.id) }
            .map { (name: $0.name, emoji: $0.emoji) }

        await auth.completeGroupOnboarding(selected: selected)
    }
}

#Preview {
    GroupOnboardingView()
}
