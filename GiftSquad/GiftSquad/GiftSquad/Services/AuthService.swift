import AuthenticationServices
import CryptoKit
import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift
import UIKit

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var currentUser: FirebaseAuth.User?
    private(set) var appUser: AppUser?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var pendingLinkCredential: AuthCredential?

    var currentUserId: String? { currentUser?.uid }

    var isAuthenticated: Bool { currentUser != nil }

    private init() {
        currentUser = Auth.auth().currentUser
        observeAuthState()
    }

    private func observeAuthState() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                if let user {
                    self?.appUser = try? await Self.loadOrCreateAppUser(for: user)
                } else {
                    self?.appUser = nil
                }
            }
        }
    }

    func refreshAppUser() async {
        guard let user = currentUser else { return }
        appUser = try? await Self.loadOrCreateAppUser(for: user)
    }

    func signInWithGoogle(presenting: UIViewController) async throws {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AppError.auth("No se obtuvo idToken de Google")
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await signInHandlingAccountConflict(with: credential)
        await linkPendingCredentialIfNeeded(to: authResult.user)
    }

    func signInWithApple() async throws {
        let coordinator = AppleSignInCoordinator()
        let (appleIDCredential, rawNonce) = try await coordinator.performSignIn()
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AppError.auth("No se pudo obtener el token de Apple")
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: appleIDCredential.fullName
        )
        let result = try await signInHandlingAccountConflict(with: credential)
        await linkPendingCredentialIfNeeded(to: result.user)

        if let fullName = appleIDCredential.fullName {
            let displayName = PersonNameComponentsFormatter().string(from: fullName)
                .trimmingCharacters(in: .whitespaces)
            if !displayName.isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = displayName
                try? await change.commitChanges()
            }
        }
    }

    private func signInHandlingAccountConflict(with credential: AuthCredential) async throws -> AuthDataResult {
        do {
            return try await Auth.auth().signIn(with: credential)
        } catch let error as NSError where error.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
            pendingLinkCredential = error.userInfo[AuthErrors.userInfoUpdatedCredentialKey] as? AuthCredential
            let email = error.userInfo[AuthErrors.userInfoEmailKey] as? String
            let suffix = email.map { " (\($0))" } ?? ""
            throw AppError.auth(
                "Ya existe una cuenta con este email\(suffix) usando el otro botón. "
                    + "Iniciá sesión con ese para vincular las dos formas de entrar."
            )
        }
    }

    private func linkPendingCredentialIfNeeded(to user: FirebaseAuth.User) async {
        guard let pending = pendingLinkCredential else { return }
        pendingLinkCredential = nil
        do {
            _ = try await user.link(with: pending)
        } catch {
            Logger.shared.error("linkPendingCredentialIfNeeded: \(error)")
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    private static func loadOrCreateAppUser(for user: FirebaseAuth.User) async throws -> AppUser {
        let ref = Firestore.firestore().collection("users").document(user.uid)
        let snap = try await ref.getDocument()

        if snap.exists {
            if let appUser = try? snap.data(as: AppUser.self) {
                return await reconcileOwnedGroups(for: user.uid, appUser: appUser)
            }
            let displayName = (snap.get("displayName") as? String)
                ?? user.displayName ?? user.email ?? "Usuario"
            var patch: [String: Any] = [:]
            if snap.get("username") == nil {
                let username = AppUser.makeUsername(from: displayName)
                patch["username"] = username
                patch["usernameLower"] = username.lowercased()
            }
            if snap.get("friendCode") == nil {
                patch["friendCode"] = AppUser.makeFriendCode()
            }
            if !patch.isEmpty {
                try await ref.setData(patch, merge: true)
            }
            let patched = try await ref.getDocument()
            if let appUser = try? patched.data(as: AppUser.self) {
                return await reconcileOwnedGroups(for: user.uid, appUser: appUser)
            }
        }

        let displayName = user.displayName ?? user.email ?? "Usuario"
        let newUser = AppUser(
            id: user.uid,
            displayName: displayName,
            email: user.email ?? "",
            username: AppUser.makeUsername(from: displayName),
            photoURL: user.photoURL,
            hasCompletedGroupOnboarding: false
        )
        try ref.setData(from: newUser)
        return newUser
    }

    static let recommendedGroups: [(name: String, emoji: String)] = [
        ("Familia", "👨‍👩‍👧‍👦"),
        ("Amigos", "🎉"),
        ("Pareja", "💞"),
        ("Trabajo", "💼"),
        ("Cumpleaños", "🎂"),
        ("Navidad", "🎄"),
        ("Boda", "💍"),
        ("Baby shower", "🍼"),
        ("Graduación", "🎓"),
        ("Vecinos", "🏠")
    ]

    func completeGroupOnboarding(selected: [(name: String, emoji: String)]) async {
        guard let uid = currentUserId else { return }
        for (name, emoji) in selected {
            let group = GiftGroup(name: name, emoji: emoji, ownerId: uid, memberIds: [uid])
            do {
                _ = try await FirestoreService.shared.createGroup(group)
            } catch {
                Logger.shared.error("completeGroupOnboarding(\(name)): \(error)")
            }
        }
        do {
            try await Firestore.firestore().collection("users").document(uid).updateData([
                "hasCompletedGroupOnboarding": true
            ])
        } catch {
            Logger.shared.error("completeGroupOnboarding.flag: \(error)")
        }
        await refreshAppUser()
    }

    private static func reconcileOwnedGroups(for uid: String, appUser: AppUser) async -> AppUser {
        do {
            let snap = try await Firestore.firestore().collection("groups")
                .whereField("ownerId", isEqualTo: uid)
                .getDocuments()
            let missing = snap.documents.map(\.documentID).filter { !appUser.groupIds.contains($0) }
            guard !missing.isEmpty else { return appUser }
            try await Firestore.firestore().collection("users").document(uid).updateData([
                "groupIds": FieldValue.arrayUnion(missing)
            ])
            var patched = appUser
            patched.groupIds.append(contentsOf: missing)
            return patched
        } catch {
            Logger.shared.error("reconcileOwnedGroups: \(error)")
            return appUser
        }
    }
}

@MainActor
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<(ASAuthorizationAppleIDCredential, String), Error>?
    private var currentNonce: String?

    func performSignIn() async throws -> (ASAuthorizationAppleIDCredential, String) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce else {
            continuation?.resume(throwing: AppError.auth("Respuesta inesperada de Apple"))
            continuation = nil
            return
        }
        continuation?.resume(returning: (credential, nonce))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        if let window = windowScene?.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        guard let windowScene else {
            fatalError("No hay UIWindowScene activa para presentar Sign in with Apple")
        }
        return UIWindow(windowScene: windowScene)
    }

    private static func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "No se pudo generar el nonce")
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
