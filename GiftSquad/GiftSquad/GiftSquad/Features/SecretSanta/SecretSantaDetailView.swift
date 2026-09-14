import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SecretSantaDetailView: View {
    @State private var event: SecretSantaEvent
    @State private var assignment: SecretSantaAssignment?
    @State private var recipient: AppUser?
    @State private var isDrawing = false
    @State private var showDrawConfirm = false
    @State private var isLoadingAssignment = false
    @State private var errorMessage: String?
    @State private var showAssignment = false
    @State private var recipientSharedItems: [SharedGiftItem] = []
    @State private var isLoadingItems = false
    @State private var myItemsCount = 0
    @State private var mySharedItemIds: Set<String> = []
    @State private var showSharePicker = false

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showEditBudget = false
    @State private var editBudgetText = ""
    @State private var isSavingBudget = false

    @Environment(\.dismiss) private var dismiss

    init(event: SecretSantaEvent) {
        _event = State(initialValue: event)
    }

    @State private var participants: [AppUser] = []
    @State private var exclusions: [ExclusionRule] = []
    @State private var excludeFromId: String?
    @State private var excludeToId: String?
    @State private var isSavingExclusions = false

    private var currentUid: String? { AuthService.shared.currentUserId }
    private var isOrganizer: Bool { currentUid == event.createdBy }

    var body: some View {
        ZStack {
            GSPalette.crema.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        GSSectionLabel(title: "Evento")
                        GSCard {
                            infoRow(label: "Nombre", value: event.name)
                            if let budget = event.budget {
                                GSDivider()
                                infoRow(label: "Tope", value: budget.formatted(.currency(code: event.currency)))
                            }
                            if let date = event.exchangeDate {
                                GSDivider()
                                infoRow(label: "Entrega", value: date.formatted(date: .long, time: .omitted))
                            }
                            GSDivider()
                            infoRow(label: "Participantes", value: "\(event.participantIds.count)")
                        }
                    }

                    participantsSection

                    switch event.status {
                    case .draft:
                        if isOrganizer {
                            exclusionsSection
                        } else {
                            GSCard {
                                Text("Esperando que el organizador ejecute el sorteo.")
                                    .font(GSFont.body(14))
                                    .foregroundStyle(GSPalette.grafito)
                                    .padding(16)
                            }
                        }

                    case .drawn, .completed:
                        VStack(alignment: .leading, spacing: 8) {
                            GSSectionLabel(title: "Tu asignación")
                            GSCard {
                                Button {
                                    Task { await loadAssignment() }
                                } label: {
                                    if showAssignment, let recipient {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Tenés que regalarle a:")
                                                .font(GSFont.caption(12))
                                                .foregroundStyle(GSPalette.grafito)
                                            Text(recipient.displayName)
                                                .font(GSFont.display(22))
                                                .foregroundStyle(GSPalette.noche)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(18)
                                    } else {
                                        HStack {
                                            Image(systemName: "eye.fill")
                                                .foregroundStyle(GSPalette.oceano)
                                            Text(isLoadingAssignment ? "Cargando…" : "Toca para revelar")
                                                .font(GSFont.body(15, weight: .bold))
                                                .foregroundStyle(GSPalette.oceano)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 16)
                                        .contentShape(Rectangle())
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isLoadingAssignment)
                            }
                        }

                        if showAssignment {
                            giftIdeasSection
                        }

                    case .cancelled:
                        GSCard {
                            Text("Evento cancelado.")
                                .font(GSFont.body(14))
                                .foregroundStyle(GSPalette.grafito)
                                .padding(16)
                        }
                    }

                    if event.participantIds.contains(currentUid ?? "") {
                        myPreferenceSection
                    }

                    if let errorMessage {
                        GSBanner(message: errorMessage, isError: true)
                    }

                    if isOrganizer, event.status == .draft {
                        VStack(spacing: 8) {
                            GSPrimaryButton(
                                title: "Ejecutar sorteo",
                                isLoading: isDrawing,
                                isEnabled: !isDrawing
                            ) {
                                showDrawConfirm = true
                            }
                            Text("El sorteo respeta las exclusiones y nadie va a ver el resultado de los demás.")
                                .font(GSFont.caption(12))
                                .foregroundStyle(GSPalette.grafito)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOrganizer {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Editar tope de gasto", systemImage: "dollarsign.circle") {
                            editBudgetText = event.budget.map { String($0) } ?? ""
                            showEditBudget = true
                        }
                        Button("Eliminar evento", systemImage: "trash", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(GSPalette.mandarina)
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .task {
            await loadMySharingState()
            await loadParticipants()
        }
        .sheet(isPresented: $showSharePicker) {
            ShareGiftListPicker(eventId: event.id ?? "", initialSelection: mySharedItemIds) { newIds in
                mySharedItemIds = newIds
            }
        }
        .gsConfirmDialog(
            isPresented: $showDrawConfirm,
            icon: "shuffle",
            iconTint: GSPalette.mandarina,
            title: "¿Ejecutar el sorteo?",
            message: "Se arman las parejas ahora mismo y no se puede deshacer. Revisá que estén todos los participantes y las exclusiones que necesites antes de confirmar.",
            confirmTitle: "Sortear",
            onConfirm: { Task { await draw() } }
        )
        .gsConfirmDialog(
            isPresented: $showDeleteConfirm,
            icon: "trash.fill",
            title: "¿Eliminar \(event.name)?",
            message: "Se borra para todos los participantes, junto con el sorteo si ya se hizo. No se puede deshacer.",
            confirmTitle: "Eliminar",
            onConfirm: { Task { await deleteEvent() } }
        )
        .sheet(isPresented: $showEditBudget) {
            editBudgetSheet
        }
    }

    private var editBudgetSheet: some View {
        NavigationStack {
            ZStack {
                GSPalette.crema.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("Tope de gasto")
                        .font(GSFont.display(22))
                        .foregroundStyle(GSPalette.noche)

                    GSCard {
                        GSUnderlineField(icon: "dollarsign.circle") {
                            TextField("", text: $editBudgetText, prompt: gsPlaceholder("Monto (vacío = sin tope)"))
                                .keyboardType(.decimalPad)
                        }
                        .padding(16)
                    }

                    if let errorMessage {
                        GSBanner(message: errorMessage, isError: true)
                    }

                    GSPrimaryButton(
                        title: "Guardar",
                        isLoading: isSavingBudget,
                        isEnabled: !isSavingBudget
                    ) {
                        Task { await saveBudget() }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showEditBudget = false }
                        .foregroundStyle(GSPalette.grafito)
                }
            }
        }
    }

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GSSectionLabel(title: "Participantes")
            if participants.isEmpty {
                GSCard {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(20)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(participants, id: \.id) { person in
                            participantTile(person)
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
        }
    }

    private func participantTile(_ person: AppUser) -> some View {
        let isHost = person.id == event.createdBy
        let isMe = person.id == currentUid
        return VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle().fill(GSPalette.grafito.opacity(0.12)).frame(width: 60, height: 60)
                    if let url = person.photoURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Image(systemName: "person.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(GSPalette.grafito)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(GSPalette.grafito)
                    }
                }
                .overlay(
                    Circle().strokeBorder(isMe ? GSPalette.oceano : Color.clear, lineWidth: 2.5)
                )
                if isHost {
                    ZStack {
                        Circle().fill(GSPalette.mandarina).frame(width: 20, height: 20)
                        Circle().strokeBorder(GSPalette.crema, lineWidth: 2).frame(width: 20, height: 20)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 3, y: 3)
                }
            }
            Text(isMe ? "Vos" : (person.displayName.split(separator: " ").first.map(String.init) ?? person.displayName))
                .font(GSFont.body(12, weight: .bold))
                .foregroundStyle(GSPalette.noche)
                .lineLimit(1)
        }
        .frame(width: 68)
    }

    private var exclusionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GSSectionLabel(title: "Exclusiones")
            GSCard {
                VStack(spacing: 0) {
                    if exclusions.isEmpty {
                        Text("Sin exclusiones cargadas — cualquiera le puede tocar a cualquiera.")
                            .font(GSFont.body(13))
                            .foregroundStyle(GSPalette.grafito)
                            .padding(16)
                    } else {
                        ForEach(Array(exclusions.enumerated()), id: \.element.id) { index, rule in
                            HStack(spacing: 8) {
                                Text("\(name(for: rule.fromUserId)) no le puede tocar a \(name(for: rule.toUserId))")
                                    .font(GSFont.body(13, weight: .semibold))
                                    .foregroundStyle(GSPalette.noche)
                                Spacer()
                                Button {
                                    Task { await removeExclusion(rule) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(GSPalette.grafito.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                .disabled(isSavingExclusions)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            if index < exclusions.count - 1 { GSDivider() }
                        }
                    }

                    GSDivider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            personPicker(title: "No le puede tocar a…", selection: $excludeFromId)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(GSPalette.grafito)
                            personPicker(title: "…esta persona", selection: $excludeToId)
                        }
                        GSSwitchLink(title: isSavingExclusions ? "Agregando…" : "+ Agregar exclusión") {
                            Task { await addExclusion() }
                        }
                        .disabled(isSavingExclusions || excludeFromId == nil || excludeToId == nil || excludeFromId == excludeToId)
                    }
                    .padding(14)
                }
            }
            Text("Útil para parejas: cada uno puede quedar excluido de tocarle al otro.")
                .font(GSFont.caption(12))
                .foregroundStyle(GSPalette.grafito)
                .padding(.horizontal, 4)
        }
    }

    private func personPicker(title: String, selection: Binding<String?>) -> some View {
        Menu {
            ForEach(participants, id: \.id) { person in
                Button(person.displayName) { selection.wrappedValue = person.id }
            }
        } label: {
            HStack(spacing: 4) {
                Text(participants.first(where: { $0.id == selection.wrappedValue })?.displayName ?? title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(GSFont.body(13, weight: .semibold))
            .foregroundStyle(selection.wrappedValue == nil ? GSPalette.grafito : GSPalette.noche)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(GSPalette.grafito.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private func name(for userId: String) -> String {
        participants.first(where: { $0.id == userId })?.displayName ?? "Alguien"
    }

    private var myPreferenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GSSectionLabel(title: "Tu lista")
            GSCard {
                Button {
                    showSharePicker = true
                } label: {
                    GSRow(
                        icon: "gift.fill",
                        iconColor: GSPalette.menta,
                        title: mySharedItemIds.isEmpty ? "Compartir lista" : "Compartiendo \(mySharedItemIds.count) de \(myItemsCount)",
                        subtitle: subtitleForShareRow
                    )
                }
                .buttonStyle(.plain)
                .disabled(myItemsCount == 0)
            }
            Text("Vos elegís qué mostrar — no depende de compartir un grupo con el resto de los participantes.")
                .font(GSFont.caption(12))
                .foregroundStyle(GSPalette.grafito)
                .padding(.horizontal, 4)
        }
    }

    private var subtitleForShareRow: String {
        if myItemsCount == 0 { return "Todavía no tenés nada en tu lista" }
        if mySharedItemIds.isEmpty {
            return "Tenés \(myItemsCount) \(myItemsCount == 1 ? "producto" : "productos") — elegí cuáles quiere ver quien te toque"
        }
        return "Tocá para cambiar qué mostrar"
    }

    @ViewBuilder
    private var giftIdeasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GSSectionLabel(title: "Ideas de regalo")
            if isLoadingItems {
                GSCard {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(20)
                }
            } else if recipientSharedItems.isEmpty {
                GSCard {
                    Text("\(recipient?.displayName ?? "Esta persona") todavía no compartió ningún producto para este evento.")
                        .font(GSFont.body(14))
                        .foregroundStyle(GSPalette.grafito)
                        .padding(16)
                }
            } else {
                GSCard {
                    VStack(spacing: 0) {
                        ForEach(Array(recipientSharedItems.enumerated()), id: \.element.id) { index, item in
                            SharedGiftItemRow(
                                item: item,
                                overBudget: event.budget.map { (item.price ?? 0) > $0 } ?? false
                            )
                            if index < recipientSharedItems.count - 1 { GSDivider() }
                        }
                    }
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(GSFont.body(14))
                .foregroundStyle(GSPalette.grafito)
            Spacer()
            Text(value)
                .font(GSFont.body(15, weight: .semibold))
                .foregroundStyle(GSPalette.noche)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func deleteEvent() async {
        guard let id = event.id else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await FirestoreService.shared.deleteSecretSantaEvent(id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveBudget() async {
        guard let id = event.id else { return }
        isSavingBudget = true
        errorMessage = nil
        defer { isSavingBudget = false }
        let trimmed = editBudgetText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let newBudget = trimmed.isEmpty ? nil : Double(trimmed)
        do {
            try await FirestoreService.shared.updateSecretSantaBudget(eventId: id, budget: newBudget)
            event.budget = newBudget
            showEditBudget = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func draw() async {
        guard let id = event.id else { return }
        isDrawing = true
        errorMessage = nil
        defer { isDrawing = false }
        do {
            try await FunctionsService.shared.drawSecretSanta(eventId: id)
            event.status = .drawn
            event.drawnAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadAssignment() async {
        guard let eventId = event.id, let uid = currentUid else { return }
        isLoadingAssignment = true
        errorMessage = nil
        defer { isLoadingAssignment = false }
        do {
            assignment = try await FirestoreService.shared.myAssignment(for: eventId, userId: uid)
            if let recipientId = assignment?.recipientId {
                let snap = try await FirestoreService.shared.user(recipientId).getDocument()
                recipient = try? snap.data(as: AppUser.self)
                showAssignment = true
                await loadRecipientItems(recipientId: recipientId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadParticipants() async {
        exclusions = event.exclusions
        var found: [AppUser] = []
        for id in event.participantIds {
            guard let snap = try? await FirestoreService.shared.user(id).getDocument(),
                  let person = try? snap.data(as: AppUser.self) else { continue }
            found.append(person)
        }
        self.participants = found.sorted { $0.displayName < $1.displayName }
    }

    private func addExclusion() async {
        guard let from = excludeFromId, let to = excludeToId, from != to else { return }
        guard let eventId = event.id else { return }
        isSavingExclusions = true
        errorMessage = nil
        defer { isSavingExclusions = false }
        let updated = exclusions + [ExclusionRule(fromUserId: from, toUserId: to)]
        do {
            try await FirestoreService.shared.updateExclusions(eventId: eventId, exclusions: updated)
            exclusions = updated
            excludeFromId = nil
            excludeToId = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeExclusion(_ rule: ExclusionRule) async {
        guard let eventId = event.id else { return }
        isSavingExclusions = true
        errorMessage = nil
        defer { isSavingExclusions = false }
        let updated = exclusions.filter { $0.id != rule.id }
        do {
            try await FirestoreService.shared.updateExclusions(eventId: eventId, exclusions: updated)
            exclusions = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMySharingState() async {
        guard let eventId = event.id, let uid = currentUid else { return }
        do {
            let snap = try await FirestoreService.shared.items()
                .whereField("ownerId", isEqualTo: uid)
                .whereField("isArchived", isEqualTo: false)
                .count
                .getAggregation(source: .server)
            myItemsCount = Int(truncating: snap.count)
        } catch {
            Logger.shared.error("loadMySharingState count: \(error)")
        }
        do {
            let shared = try await FirestoreService.shared.sharedItems(eventId: eventId, uid: uid)
            mySharedItemIds = Set(shared.map(\.itemId))
        } catch {
            Logger.shared.error("loadMySharingState shared: \(error)")
        }
    }

    private func loadRecipientItems(recipientId: String) async {
        isLoadingItems = true
        defer { isLoadingItems = false }
        guard let eventId = event.id else { return }
        do {
            let shared = try await FirestoreService.shared.sharedItems(eventId: eventId, uid: recipientId)
            if let budget = event.budget {
                let within = shared.filter { ($0.price ?? 0) <= budget }.sorted { ($0.price ?? 0) < ($1.price ?? 0) }
                let over = shared.filter { ($0.price ?? 0) > budget }.sorted { ($0.price ?? 0) < ($1.price ?? 0) }
                self.recipientSharedItems = within + over
            } else {
                self.recipientSharedItems = shared.sorted { ($0.price ?? 0) < ($1.price ?? 0) }
            }
        } catch {
            Logger.shared.error("SecretSantaDetailView.loadRecipientItems: \(error)")
        }
    }
}

private struct SharedGiftItemRow: View {
    let item: SharedGiftItem
    let overBudget: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(GSPalette.grafito.opacity(0.10))
                    .frame(width: 56, height: 56)
                AsyncImage(url: item.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "gift")
                            .foregroundStyle(GSPalette.grafito)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(GSFont.body(14, weight: .bold))
                    .foregroundStyle(GSPalette.noche)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let price = item.price {
                        Text(price, format: .currency(code: item.currency))
                            .font(GSFont.body(13, weight: .bold))
                            .foregroundStyle(GSPalette.noche)
                    }
                    if overBudget {
                        Text("Supera el tope")
                            .font(GSFont.caption(9))
                            .foregroundStyle(GSPalette.alerta)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(GSPalette.alerta.opacity(0.14)))
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct ShareGiftListPicker: View {
    let eventId: String
    var onSave: (Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIds: Set<String>
    @State private var items: [WishlistItem] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(eventId: String, initialSelection: Set<String>, onSave: @escaping (Set<String>) -> Void) {
        self.eventId = eventId
        self.onSave = onSave
        _selectedIds = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GSPalette.crema.ignoresSafeArea()
                if isLoading {
                    ProgressView()
                } else if items.isEmpty {
                    EmptyStateView(
                        icon: "gift",
                        title: "Tu lista está vacía",
                        message: "Agregá productos desde \"Mi lista\" antes de compartir.",
                        primaryActionTitle: nil,
                        primaryAction: nil
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Tenés \(items.count) \(items.count == 1 ? "producto" : "productos") en tu lista. Elegí cuáles querés que vea quien te toque.")
                                .font(GSFont.body(14))
                                .foregroundStyle(GSPalette.grafito)

                            GSCard {
                                VStack(spacing: 0) {
                                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                        pickerRow(item)
                                        if index < items.count - 1 { GSDivider() }
                                    }
                                }
                            }

                            if let errorMessage {
                                GSBanner(message: errorMessage, isError: true)
                            }

                            GSPrimaryButton(
                                title: "Guardar",
                                isLoading: isSaving,
                                isEnabled: !isSaving
                            ) {
                                Task { await save() }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Compartir lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(GSPalette.grafito)
                }
            }
            .task { await loadItems() }
        }
    }

    private func pickerRow(_ item: WishlistItem) -> some View {
        let isSelected = selectedIds.contains(item.id ?? "")
        return Button {
            guard let id = item.id else { return }
            if isSelected { selectedIds.remove(id) } else { selectedIds.insert(id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? GSPalette.menta : GSPalette.grafito.opacity(0.4))
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(GSPalette.grafito.opacity(0.10))
                        .frame(width: 44, height: 44)
                    AsyncImage(url: item.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "photo")
                                .font(.system(size: 14))
                                .foregroundStyle(GSPalette.grafito)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(GSFont.body(14, weight: .semibold))
                        .foregroundStyle(GSPalette.noche)
                        .lineLimit(1)
                    if let price = item.price {
                        Text(price, format: .currency(code: item.currency))
                            .font(GSFont.caption(12))
                            .foregroundStyle(GSPalette.grafito)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadItems() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let snap = try await FirestoreService.shared.items()
                .whereField("ownerId", isEqualTo: uid)
                .whereField("isArchived", isEqualTo: false)
                .getDocuments()
            let fetched = snap.documents.compactMap { try? $0.data(as: WishlistItem.self) }
            self.items = fetched.sorted { ($0.price ?? .greatestFiniteMagnitude) < ($1.price ?? .greatestFiniteMagnitude) }
        } catch {
            Logger.shared.error("ShareGiftListPicker.loadItems: \(error)")
        }
    }

    private func save() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let selected = items.filter { selectedIds.contains($0.id ?? "") }
        let snapshots = selected.map {
            SharedGiftItem(itemId: $0.id ?? "", name: $0.name, price: $0.price, currency: $0.currency, imageURL: $0.imageURL)
        }
        do {
            try await FirestoreService.shared.setSharedItems(eventId: eventId, uid: uid, items: snapshots)
            onSave(selectedIds)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
