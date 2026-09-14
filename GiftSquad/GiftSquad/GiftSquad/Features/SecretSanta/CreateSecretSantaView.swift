import SwiftUI
import FirebaseFirestore

struct CreateSecretSantaView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var descriptionText = ""
    @State private var hasBudget = true
    @State private var budget = ""
    @State private var currency = "ARS"
    @State private var hasDate = true
    @State private var exchangeDate = Date().addingTimeInterval(60 * 60 * 24 * 14)
    @State private var participants: [AppUser] = []
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var myGroupMembers: [AppUser] = []
    @State private var showWhatsAppInvite = false

    var body: some View {
        NavigationStack {
            ZStack {
                GSPalette.crema.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Nuevo Amigo Invisible")
                            .font(GSFont.display(24))
                            .foregroundStyle(GSPalette.noche)

                        VStack(alignment: .leading, spacing: 8) {
                            GSSectionLabel(title: "Evento")
                            GSCard {
                                VStack(spacing: 16) {
                                    GSUnderlineField(icon: "textformat") {
                                        TextField("", text: $name, prompt: gsPlaceholder("Nombre (ej. Navidad 2026)"))
                                            .textInputAutocapitalization(.sentences)
                                    }
                                    GSUnderlineField(icon: "text.alignleft") {
                                        TextField("", text: $descriptionText, prompt: gsPlaceholder("Descripción (opcional)"), axis: .vertical)
                                            .lineLimit(1...3)
                                    }
                                }
                                .padding(16)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            GSSectionLabel(title: "Presupuesto")
                            GSCard {
                                Toggle(isOn: $hasBudget.animation(.easeInOut(duration: 0.2))) {
                                    Text("Tope de gasto")
                                        .font(GSFont.body(15, weight: .semibold))
                                        .foregroundStyle(GSPalette.noche)
                                }
                                .tint(GSPalette.oceano)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)

                                if hasBudget {
                                    GSDivider()
                                    VStack(alignment: .leading, spacing: 10) {
                                        GSUnderlineField(icon: "dollarsign.circle") {
                                            TextField("", text: $budget, prompt: gsPlaceholder("Monto"))
                                                .keyboardType(.decimalPad)
                                        }
                                        Text("Moneda")
                                            .font(GSFont.caption())
                                            .foregroundStyle(GSPalette.grafito)
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
                                    .padding(14)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            GSSectionLabel(title: "Intercambio")
                            GSCard {
                                Toggle(isOn: $hasDate.animation(.easeInOut(duration: 0.2))) {
                                    Text("Fecha de entrega")
                                        .font(GSFont.body(15, weight: .semibold))
                                        .foregroundStyle(GSPalette.noche)
                                }
                                .tint(GSPalette.oceano)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)

                                if hasDate {
                                    GSDivider()
                                    DatePicker("Fecha", selection: $exchangeDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(GSPalette.mandarina)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            GSSectionLabel(title: "Participantes (\(participants.count))")
                            GSCard {
                                let availableFromGroups = myGroupMembers.filter { member in
                                    !participants.contains { $0.id == member.id }
                                }
                                if !availableFromGroups.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("DE TUS GRUPOS")
                                            .font(GSFont.caption(10))
                                            .tracking(1)
                                            .foregroundStyle(GSPalette.grafito)
                                            .padding(.horizontal, 16)
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 10) {
                                                ForEach(availableFromGroups, id: \.id) { person in
                                                    Button {
                                                        participants.append(person)
                                                    } label: {
                                                        VStack(spacing: 4) {
                                                            ZStack(alignment: .bottomTrailing) {
                                                                ZStack {
                                                                    Circle().fill(GSPalette.menta.opacity(0.14)).frame(width: 44, height: 44)
                                                                    if let url = person.photoURL {
                                                                        AsyncImage(url: url) { phase in
                                                                            switch phase {
                                                                            case .success(let image):
                                                                                image.resizable().scaledToFill()
                                                                            default:
                                                                                Image(systemName: "person.fill")
                                                                                    .font(.system(size: 16, weight: .semibold))
                                                                                    .foregroundStyle(GSPalette.menta)
                                                                            }
                                                                        }
                                                                        .frame(width: 44, height: 44)
                                                                        .clipShape(Circle())
                                                                    } else {
                                                                        Image(systemName: "person.fill")
                                                                            .font(.system(size: 16, weight: .semibold))
                                                                            .foregroundStyle(GSPalette.menta)
                                                                    }
                                                                }
                                                                ZStack {
                                                                    Circle().fill(GSPalette.menta).frame(width: 18, height: 18)
                                                                    Circle().strokeBorder(GSPalette.crema, lineWidth: 2).frame(width: 18, height: 18)
                                                                    Image(systemName: "plus")
                                                                        .font(.system(size: 9, weight: .bold))
                                                                        .foregroundStyle(.white)
                                                                }
                                                                .offset(x: 2, y: 2)
                                                            }
                                                            Text(person.displayName.split(separator: " ").first.map(String.init) ?? person.displayName)
                                                                .font(GSFont.caption(10))
                                                                .foregroundStyle(GSPalette.noche)
                                                                .lineLimit(1)
                                                        }
                                                        .frame(width: 60)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                    .padding(.top, 14)
                                    .padding(.bottom, 10)
                                    GSDivider()
                                }

                                HStack(spacing: 10) {
                                    GSUnderlineField(icon: "person.badge.plus") {
                                        TextField("", text: $searchQuery, prompt: gsPlaceholder("@usuario, código o email"))
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .onSubmit { Task { await addParticipant() } }
                                    }
                                    Button {
                                        Task { await addParticipant() }
                                    } label: {
                                        if isSearching {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 26))
                                                .foregroundStyle(GSPalette.menta)
                                        }
                                    }
                                    .disabled(isSearching || searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                                .padding(16)

                                if let searchError {
                                    Text(searchError)
                                        .font(GSFont.caption(12))
                                        .foregroundStyle(GSPalette.alerta)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 12)
                                }

                                if !participants.isEmpty {
                                    GSDivider()
                                    ForEach(Array(participants.enumerated()), id: \.element.id) { index, person in
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle().fill(GSPalette.oceano.opacity(0.12)).frame(width: 40, height: 40)
                                                if let url = person.photoURL {
                                                    AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case .success(let image):
                                                            image.resizable().scaledToFill()
                                                        default:
                                                            Image(systemName: "person.fill")
                                                                .font(.system(size: 16, weight: .semibold))
                                                                .foregroundStyle(GSPalette.oceano)
                                                        }
                                                    }
                                                    .frame(width: 40, height: 40)
                                                    .clipShape(Circle())
                                                } else {
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundStyle(GSPalette.oceano)
                                                }
                                            }
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(person.displayName)
                                                    .font(GSFont.body(15, weight: .semibold))
                                                    .foregroundStyle(GSPalette.noche)
                                                if person.id == AuthService.shared.currentUserId {
                                                    Text("Vos")
                                                        .font(GSFont.caption(11))
                                                        .foregroundStyle(GSPalette.grafito)
                                                }
                                            }
                                            Spacer()
                                            if person.id != AuthService.shared.currentUserId {
                                                Button {
                                                    participants.removeAll { $0.id == person.id }
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundStyle(GSPalette.grafito.opacity(0.5))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        if index < participants.count - 1 { GSDivider() }
                                    }
                                }
                            }
                            Text("Buscá a cualquier persona con cuenta en GiftSquad — no hace falta que compartan un grupo. Hacen falta al menos 3 para que el sorteo tenga sentido.")
                                .font(GSFont.caption(12))
                                .foregroundStyle(GSPalette.grafito)
                                .padding(.horizontal, 4)
                            Text("Las reglas de exclusión (\"X no le toca a Y\") las podés cargar después de crear el evento, antes de sortear.")
                                .font(GSFont.caption(12))
                                .foregroundStyle(GSPalette.grafito)
                                .padding(.horizontal, 4)

                            Button {
                                showWhatsAppInvite = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.right.square.fill")
                                        .font(.system(size: 17))
                                    Text("Invitar por WhatsApp a alguien sin la app")
                                        .font(GSFont.body(14, weight: .bold))
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(GSPalette.menta)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(GSPalette.menta.opacity(0.4), lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }

                        if let errorMessage {
                            GSBanner(message: errorMessage, isError: true)
                        }

                        GSPrimaryButton(
                            title: "Crear evento",
                            isLoading: isSaving,
                            isEnabled: !isSaving && canCreate
                        ) {
                            Task { await create() }
                        }
                        .padding(.top, 4)
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
                addSelfIfNeeded()
                await loadMyGroupMembers()
            }
            .sheet(isPresented: $showWhatsAppInvite) {
                ShareSheet(items: [whatsAppInviteMessage])
            }
        }
    }

    private var whatsAppInviteMessage: String {
        let code = AuthService.shared.appUser?.friendCode ?? ""
        return "Te sumo a nuestro Amigo Invisible en GiftSquad 🎁 Descargate la app y agregame con mi código: \(code)"
    }

    private func loadMyGroupMembers() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        do {
            let groupsSnap = try await FirestoreService.shared.groups()
                .whereField("memberIds", arrayContains: uid)
                .getDocuments()
            let memberIds = Set(groupsSnap.documents
                .compactMap { try? $0.data(as: GiftGroup.self) }
                .flatMap(\.memberIds))
                .subtracting([uid])
            guard !memberIds.isEmpty else { return }
            var found: [AppUser] = []
            for id in memberIds {
                guard let snap = try? await FirestoreService.shared.user(id).getDocument(),
                      let person = try? snap.data(as: AppUser.self) else { continue }
                found.append(person)
            }
            self.myGroupMembers = found.sorted { $0.displayName < $1.displayName }
        } catch {
            Logger.shared.error("loadMyGroupMembers: \(error)")
        }
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        participants.count >= 3
    }

    private func addSelfIfNeeded() {
        guard participants.isEmpty, let me = AuthService.shared.appUser else { return }
        participants = [me]
    }

    private func addParticipant() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        searchError = nil
        defer { isSearching = false }
        do {
            guard let found = try await FirestoreService.shared.findUser(matching: query) else {
                searchError = "No encontramos a nadie con ese dato."
                return
            }
            guard !participants.contains(where: { $0.id == found.id }) else {
                searchError = "Ya está en la lista."
                return
            }
            participants.append(found)
            searchQuery = ""
        } catch {
            searchError = error.localizedDescription
        }
    }

    private func create() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let event = SecretSantaEvent(
            name: name.trimmingCharacters(in: .whitespaces),
            description: descriptionText.isEmpty ? nil : descriptionText,
            budget: hasBudget ? Double(budget.replacingOccurrences(of: ",", with: ".")) : nil,
            currency: currency,
            exchangeDate: hasDate ? exchangeDate : nil,
            participantIds: participants.compactMap(\.id),
            createdBy: uid
        )
        do {
            _ = try await FirestoreService.shared.createSecretSantaEvent(event)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
