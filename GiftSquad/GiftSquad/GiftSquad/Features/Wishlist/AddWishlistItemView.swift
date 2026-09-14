import SwiftUI
import FirebaseFirestore
import PhotosUI

enum GSCurrency: String, CaseIterable, Identifiable {
    case ars = "ARS"
    case usd = "USD"
    case eur = "EUR"
    case dkk = "DKK"

    var id: String { rawValue }

    var flag: String {
        switch self {
        case .ars: return "🇦🇷"
        case .usd: return "🇺🇸"
        case .eur: return "🇪🇺"
        case .dkk: return "🇩🇰"
        }
    }

    var label: String {
        switch self {
        case .ars: return "Pesos"
        case .usd: return "Dólares"
        case .eur: return "Euros"
        case .dkk: return "Coronas"
        }
    }

    var color: Color {
        switch self {
        case .ars: return GSPalette.oceano
        case .usd: return GSPalette.menta
        case .eur: return GSPalette.durazno
        case .dkk: return GSPalette.alerta
        }
    }
}

struct AddWishlistItemView: View {
    @Environment(\.dismiss) private var dismiss

    private let existingItem: WishlistItem?
    private var onSaved: ((WishlistItem) -> Void)?

    @State private var link = ""
    @State private var extraLinks: [String] = []
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var name = ""
    @State private var descriptionText = ""
    @State private var price = ""
    @State private var originalPrice = ""
    @State private var currency = "ARS"
    @State private var category = ""
    @State private var priority: ItemPriority = .medium
    @State private var privateNotes = ""
    @State private var imageURL: URL?
    @State private var groupIds: [String] = []
    @State private var availableGroups: [GiftGroup] = []
    @State private var groupOwnerNames: [String: String] = [:]
    @State private var isFetchingPreview = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { existingItem != nil }

    private var discountPercent: Int? {
        guard let p = Double(price.replacingOccurrences(of: ",", with: ".")),
              let original = Double(originalPrice.replacingOccurrences(of: ",", with: ".")),
              original > p else { return nil }
        return Int(((original - p) / original * 100).rounded())
    }

    init(existingItem: WishlistItem? = nil, onSaved: ((WishlistItem) -> Void)? = nil) {
        self.existingItem = existingItem
        self.onSaved = onSaved
        _link = State(initialValue: existingItem?.link?.absoluteString ?? "")
        _extraLinks = State(initialValue: (existingItem?.additionalLinks ?? []).map(\.absoluteString))
        _name = State(initialValue: existingItem?.name ?? "")
        _descriptionText = State(initialValue: existingItem?.descriptionText ?? "")
        _price = State(initialValue: existingItem?.price.map { String($0) } ?? "")
        _originalPrice = State(initialValue: existingItem?.originalPrice.map { String($0) } ?? "")
        _currency = State(initialValue: existingItem?.currency ?? "ARS")
        _category = State(initialValue: existingItem?.category ?? "")
        _priority = State(initialValue: existingItem?.priority ?? .medium)
        _imageURL = State(initialValue: existingItem?.imageURL)
        _groupIds = State(initialValue: existingItem?.groupIds ?? [])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GSPalette.crema.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [GSPalette.menta, GSPalette.oceano],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .opacity(0.16)
                                    .frame(width: 72, height: 72)
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [GSPalette.menta, GSPalette.oceano],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            VStack(spacing: 4) {
                                Text(isEditing ? "Editar ítem" : "Nuevo ítem")
                                    .font(GSFont.display(24))
                                    .foregroundStyle(GSPalette.noche)
                                Text(
                                    isEditing
                                        ? "Cambiá lo que necesites, incluido en qué grupos se ve"
                                        : "Pegá el link de la tienda y completamos lo que podamos por vos"
                                )
                                    .font(GSFont.body(13))
                                    .foregroundStyle(GSPalette.grafito)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 8) {
                            GSSectionLabel(title: "Link del producto")
                            GSCard {
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        GSUnderlineField(icon: "link", iconColor: GSPalette.oceano) {
                                            TextField("", text: $link, prompt: gsPlaceholder("Pegá el link acá"))
                                                .keyboardType(.URL)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled()
                                        }
                                        if isFetchingPreview {
                                            ProgressView().tint(GSPalette.oceano)
                                        } else if imageURL != nil {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(GSPalette.menta)
                                        }
                                    }
                                    .padding(16)
                                    .onChange(of: link) { _, newValue in
                                        Task { await fetchPreview(from: newValue) }
                                    }

                                    ForEach(extraLinks.indices, id: \.self) { index in
                                        GSDivider()
                                        HStack(spacing: 12) {
                                            GSUnderlineField(icon: "link", iconColor: GSPalette.grafito) {
                                                TextField(
                                                    "",
                                                    text: Binding(
                                                        get: { extraLinks[index] },
                                                        set: { extraLinks[index] = $0 }
                                                    ),
                                                    prompt: gsPlaceholder("Otro link (opcional)")
                                                )
                                                .keyboardType(.URL)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled()
                                            }
                                            Button {
                                                extraLinks.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(GSPalette.grafito.opacity(0.5))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(16)
                                    }

                                    GSDivider()
                                    Button {
                                        extraLinks.append("")
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Agregar otro link")
                                        }
                                        .font(GSFont.body(14, weight: .semibold))
                                        .foregroundStyle(GSPalette.oceano)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            GSSectionLabel(title: "Detalle")
                            GSCard {
                                VStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(GSPalette.grafito.opacity(0.08))

                                        if let imageURL {
                                            AsyncImage(url: imageURL) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image.resizable().scaledToFit()
                                                        .padding(10)
                                                default:
                                                    Color.clear
                                                }
                                            }
                                        } else {
                                            VStack(spacing: 6) {
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.system(size: 26))
                                                Text("Sin foto todavía")
                                                    .font(GSFont.caption(11))
                                            }
                                            .foregroundStyle(GSPalette.grafito)
                                        }

                                        if isUploadingPhoto {
                                            Color.black.opacity(0.25)
                                            ProgressView().tint(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                            Text(imageURL == nil ? "Subir una foto" : "Cambiar la foto")
                                        }
                                        .font(GSFont.body(14, weight: .bold))
                                        .foregroundStyle(GSPalette.oceano)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(GSPalette.oceano.opacity(0.4), lineWidth: 1.5)
                                        )
                                    }
                                    .disabled(isUploadingPhoto)
                                    .onChange(of: pickedPhoto) { _, newValue in
                                        Task { await uploadPickedPhoto(newValue) }
                                    }

                                    GSUnderlineField(icon: "textformat", iconColor: GSPalette.mandarina) {
                                        TextField("", text: $name, prompt: gsPlaceholder("Nombre"))
                                    }
                                    GSUnderlineField(icon: "text.alignleft", iconColor: GSPalette.grafito) {
                                        TextField("", text: $descriptionText, prompt: gsPlaceholder("Descripción"), axis: .vertical)
                                            .lineLimit(1...3)
                                    }
                                    VStack(alignment: .leading, spacing: 14) {
                                        if let percent = discountPercent {
                                            HStack(spacing: 6) {
                                                Image(systemName: "tag.fill")
                                                Text("¡Está de oferta! -\(percent)%")
                                            }
                                            .font(GSFont.body(12, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(GSPalette.alerta))
                                        }
                                        VStack(alignment: .leading, spacing: 8) {
                                            GSFieldLabel(icon: "dollarsign.circle.fill", iconColor: GSPalette.menta, title: "Precio de oferta")
                                            GSPillField(icon: "dollarsign.circle", iconColor: GSPalette.menta) {
                                                TextField("", text: $price, prompt: gsPlaceholder("Opcional"))
                                                    .keyboardType(.decimalPad)
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 8) {
                                            GSFieldLabel(icon: "tag.slash.fill", iconColor: GSPalette.grafito, title: "Precio original")
                                            GSPillField(icon: "tag.slash", iconColor: GSPalette.grafito) {
                                                TextField("", text: $originalPrice, prompt: gsPlaceholder("Si estaba en oferta"))
                                                    .keyboardType(.decimalPad)
                                            }
                                        }
                                        GSFieldLabel(icon: "banknote.fill", iconColor: GSPalette.durazno, title: "Moneda")
                                        HStack(spacing: 8) {
                                            ForEach(GSCurrency.allCases) { c in
                                                Button {
                                                    currency = c.rawValue
                                                } label: {
                                                    VStack(spacing: 2) {
                                                        Text(c.flag)
                                                            .font(.system(size: 16))
                                                        Text(c.rawValue)
                                                            .font(GSFont.body(11, weight: .bold))
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(
                                                            currency == c.rawValue ? c.color.opacity(0.14) : Color.clear
                                                        )
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(
                                                            currency == c.rawValue ? c.color : GSPalette.grafito.opacity(0.25),
                                                            lineWidth: currency == c.rawValue ? 2 : 1
                                                        )
                                                    )
                                                    .foregroundStyle(currency == c.rawValue ? c.color : GSPalette.grafito)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 8) {
                                        GSFieldLabel(icon: "tag.fill", iconColor: GSPalette.oceano, title: "Categoría")
                                        GSPillField(icon: "tag", iconColor: GSPalette.oceano) {
                                            TextField("", text: $category, prompt: gsPlaceholder("Ej. Tecnología, Ropa…"))
                                        }
                                    }
                                    PriorityScaleControl(priority: $priority)
                                }
                                .padding(16)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            GSSectionLabel(title: "Notas privadas")
                            GSCard {
                                GSUnderlineField(icon: "lock", iconColor: GSPalette.durazno) {
                                    TextField("", text: $privateNotes, prompt: gsPlaceholder("Visible solo para vos"), axis: .vertical)
                                        .lineLimit(1...3)
                                }
                                .padding(16)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            GSSectionLabel(title: "Visible en")
                            if !availableGroups.isEmpty {
                                Text("Tocá uno o varios grupos para elegir dónde se va a ver")
                                    .font(GSFont.body(12))
                                    .foregroundStyle(GSPalette.grafito)
                            }
                            if availableGroups.isEmpty {
                                GSCard {
                                    Text("Todavía no estás en ningún grupo")
                                        .font(GSFont.body(14))
                                        .foregroundStyle(GSPalette.grafito)
                                        .padding(16)
                                }
                            } else {
                                LazyVGrid(columns: Self.groupGridColumns, spacing: 16) {
                                    ForEach(Array(availableGroups.enumerated()), id: \.offset) { index, group in
                                        groupToggleTile(group, tint: Self.groupTint(for: index))
                                    }
                                }
                            }
                            Text("No hace falta marcar ninguno: si no elegís un grupo, el ítem queda solo en tu \"Mi lista\" personal. Podés marcar uno o varios para que ese grupo lo pueda ver y reservar.")
                                .font(GSFont.caption(12))
                                .foregroundStyle(GSPalette.grafito)
                                .padding(.horizontal, 4)
                        }

                        if let errorMessage {
                            GSBanner(message: errorMessage, isError: true)
                        }

                        GSPrimaryButton(
                            title: isEditing ? "Guardar cambios" : "Guardar",
                            isLoading: isSaving,
                            isEnabled: !isSaving && !name.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            Task { await save() }
                        }
                    }
                    .padding(20)
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
            .task {
                await loadGroups()
                await loadPrivateNotes()
            }
            .gsDisableInteractivePop()
        }
    }

    private func loadPrivateNotes() async {
        guard let itemId = existingItem?.id else { return }
        privateNotes = (try? await FirestoreService.shared.fetchPrivateNotes(forItem: itemId)) ?? ""
    }

    private func loadGroups() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        do {
            let snap = try await FirestoreService.shared.groups()
                .whereField("memberIds", arrayContains: uid)
                .getDocuments()
            self.availableGroups = snap.documents.compactMap { try? $0.data(as: GiftGroup.self) }

            let ownerIds = Set(availableGroups.filter { $0.ownerId != uid }.map(\.ownerId))
            for ownerId in ownerIds {
                guard let doc = try? await FirestoreService.shared.user(ownerId).getDocument(),
                      let owner = try? doc.data(as: AppUser.self) else { continue }
                groupOwnerNames[ownerId] = owner.displayName
            }
        } catch {
            Logger.shared.error("loadGroups: \(error)")
        }
    }

    private static let groupTints: [Color] = [
        GSPalette.mandarina, GSPalette.oceano, GSPalette.menta, GSPalette.durazno, GSPalette.alerta
    ]
    private static func groupTint(for index: Int) -> Color {
        groupTints[index % groupTints.count]
    }

    private static let groupGridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private func groupDisplayTitle(for group: GiftGroup) -> String {
        guard group.ownerId != AuthService.shared.currentUserId else { return group.name }
        let hasCollision = availableGroups.contains { $0.id != group.id && $0.name == group.name }
        guard hasCollision else { return group.name }
        let firstName = groupOwnerNames[group.ownerId]?.split(separator: " ").first.map(String.init)
        return firstName.map { "\($0) · \(group.name)" } ?? group.name
    }

    private func groupToggleTile(_ group: GiftGroup, tint: Color) -> some View {
        let id = group.id ?? ""
        let isSelected = groupIds.contains(id)
        let isOwner = group.ownerId == AuthService.shared.currentUserId
        let displayTitle = groupDisplayTitle(for: group)
        let roleText: String = {
            if isOwner { return "Anfitrión" }
            let first = groupOwnerNames[group.ownerId]?.split(separator: " ").first.map(String.init)
            return first.map { "de \($0)" } ?? "Miembro"
        }()
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    groupIds.removeAll { $0 == id }
                } else {
                    groupIds.append(id)
                }
            }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(isSelected ? 0.22 : 0.14))
                            .frame(width: 60, height: 60)
                        Text(group.emoji ?? "🎁")
                            .font(.system(size: 26))
                    }
                    .overlay(
                        Circle().strokeBorder(isSelected ? tint : GSPalette.grafito.opacity(0.3), style: StrokeStyle(lineWidth: isSelected ? 2.5 : 1.5, dash: isSelected ? [] : [4, 3]))
                    )

                    if isSelected {
                        ZStack {
                            Circle().fill(tint).frame(width: 20, height: 20)
                            Circle().strokeBorder(GSPalette.crema, lineWidth: 2).frame(width: 20, height: 20)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 4, y: -4)
                    }
                }

                VStack(spacing: 1) {
                    Text(displayTitle)
                        .font(GSFont.body(12, weight: .bold))
                        .foregroundStyle(isSelected ? GSPalette.noche : GSPalette.grafito)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(roleText)
                        .font(GSFont.caption(9))
                        .foregroundStyle(GSPalette.grafito.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }

    private func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private func fetchPreview(from raw: String) async {
        guard let url = normalizedURL(from: raw) else { return }
        isFetchingPreview = true
        defer { isFetchingPreview = false }
        do {
            let preview = try await LinkPreviewService.shared.fetch(url)
            if name.isEmpty, let t = preview.title { name = t }
            if descriptionText.isEmpty, let d = preview.description { descriptionText = d }
            if let img = preview.imageURL { imageURL = img }
            if price.isEmpty, let p = preview.price { price = String(p) }
            if originalPrice.isEmpty, let o = preview.originalPrice { originalPrice = String(o) }
            if let c = preview.currency { currency = c }
            if category.isEmpty, let cat = preview.category { category = cat }
        } catch {
            Logger.shared.info("preview falló: \(error.localizedDescription)")
        }
    }

    private func uploadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let uid = AuthService.shared.currentUserId else { return }
        isUploadingPhoto = true
        errorMessage = nil
        defer { isUploadingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            imageURL = try await StorageService.shared.uploadItemImage(data, ownerId: uid)
        } catch {
            errorMessage = "No se pudo subir la foto: \(error.localizedDescription)"
        }
    }

    private func save() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let links = extraLinks.compactMap { normalizedURL(from: $0) }
        var item = WishlistItem(
            id: existingItem?.id,
            ownerId: uid,
            groupIds: groupIds,
            name: name.trimmingCharacters(in: .whitespaces),
            descriptionText: descriptionText.isEmpty ? nil : descriptionText,
            imageURL: imageURL,
            price: Double(price.replacingOccurrences(of: ",", with: ".")),
            originalPrice: Double(originalPrice.replacingOccurrences(of: ",", with: ".")),
            currency: currency,
            link: normalizedURL(from: link),
            additionalLinks: links.isEmpty ? nil : links,
            category: category.isEmpty ? nil : category,
            priority: priority,
            variants: existingItem?.variants ?? [],
            alternatives: existingItem?.alternatives ?? [],
            isArchived: existingItem?.isArchived ?? false,
            createdAt: existingItem?.createdAt ?? Date()
        )
        do {
            let savedId = try await FirestoreService.shared.upsertItem(item)
            item.id = savedId
            try await FirestoreService.shared.setPrivateNotes(privateNotes, forItem: savedId)
            onSaved?(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddWishlistItemView()
}
