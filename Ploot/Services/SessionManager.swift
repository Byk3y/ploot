import Foundation
import Observation
import Supabase
import AuthenticationServices
import CryptoKit

/// Owns the auth session for the whole app. The Supabase SDK persists the
/// session to the iOS Keychain and auto-refreshes access tokens, so on
/// launch we just restore whatever's there and observe changes.
///
/// State exposed to SwiftUI:
///   * `state` drives the root route (loading / signed in / signed out).
///   * `currentUser` is convenience access to the underlying auth.users row.
///   * `authError` is a non-nil error message when something fails.
@MainActor
@Observable
final class SessionManager {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn
    }

    var state: State = .loading
    var currentUser: User? = nil
    var authError: String? = nil

    private var authTask: Task<Void, Never>? = nil
    private var currentNonce: String? = nil

    init() {
        // Subscribe to the SDK's auth state stream. Anything that mutates
        // the session — sign-in, sign-out, token refresh — lands here.
        // SessionManager lives for the app's lifetime, so the task runs
        // until the process exits; the weak-self capture prevents a retain
        // cycle if that ever changes.
        authTask = Task { [weak self] in
            for await (event, session) in Supa.client.auth.authStateChanges {
                await self?.handle(event: event, session: session)
            }
        }
    }

    private func handle(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
            if let session {
                currentUser = session.user
                state = .signedIn
                authError = nil
                // Tell RevenueCat who this user is. Aliases the anonymous
                // RC user (created during the paywall purchase on screen
                // 21) to the real Supabase user, so the entitlement
                // follows them across devices / reinstalls.
                //
                // No-op for `.initialSession` of an unchanged user —
                // calling logIn with the same id is safe and cheap.
                await SubscriptionManager.shared.identify(userId: session.user.id.uuidString)
                // Pull the profile row so the local @AppStorage matches the
                // source of truth. Handles the "I signed in on another
                // device and renamed myself" case too — every session
                // transition re-syncs.
                await syncProfileDownstream(userId: session.user.id)
            } else {
                state = .signedOut
                currentUser = nil
            }
        case .signedOut, .userDeleted:
            state = .signedOut
            currentUser = nil
            // Reset RC to anonymous so the next user of this device
            // doesn't inherit the prior user's entitlement.
            await SubscriptionManager.shared.resetUser()
        case .passwordRecovery, .mfaChallengeVerified:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Profile display-name sync

    private struct ProfileRow: Decodable {
        let display_name: String?
    }

    /// Fetch the `profiles.display_name` for the current user and mirror
    /// it into the UserDefaults key that `@AppStorage("displayName")`
    /// reads from. Called after every sign-in / token-refresh.
    private func syncProfileDownstream(userId: UUID) async {
        do {
            let profile: ProfileRow = try await Supa.client
                .from("profiles")
                .select("display_name")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            if let name = profile.display_name, !name.isEmpty {
                UserDefaults.standard.set(name, forKey: "displayName")
            }
        } catch {
            #if DEBUG
            print("[Ploot] Failed to sync profile downstream: \(error)")
            #endif
        }
    }

    /// Push a new display_name to the remote profiles row. Called by
    /// SettingsScreen (debounced) when the user edits the name field.
    func updateRemoteDisplayName(_ name: String) async {
        guard let userId = currentUser?.id else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try await upsertDisplayName(trimmed, userId: userId)
        } catch {
            #if DEBUG
            print("[Ploot] Failed to push display name: \(error)")
            #endif
        }
    }

    // MARK: - Sign in with Apple

    /// Called by AuthView with the raw ASAuthorization credential. Sends the
    /// identity token + raw nonce to Supabase, which verifies against Apple
    /// and issues a Session. The AFTER INSERT trigger on auth.users creates
    /// the matching profiles row for first-time sign-ins.
    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) async {
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            authError = "Apple didn't return an identity token."
            return
        }
        guard let nonce = currentNonce else {
            authError = "Sign-in state got lost. Try again."
            return
        }

        do {
            let session = try await Supa.client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            // First-time sign-in: Apple sends full name only once per Apple
            // ID. Capture it into the profile row while we have it.
            if let fullName = credential.fullName,
               let display = Self.formattedName(fullName) {
                try? await upsertDisplayName(display, userId: session.user.id)
            }
        } catch {
            authError = (error as NSError).localizedDescription
        }
    }

    private func upsertDisplayName(_ name: String, userId: UUID) async throws {
        struct ProfileUpdate: Encodable { let display_name: String }
        try await Supa.client
            .from("profiles")
            .update(ProfileUpdate(display_name: name))
            .eq("id", value: userId.uuidString)
            .execute()
    }

    private static func formattedName(_ components: PersonNameComponents) -> String? {
        let fmt = PersonNameComponentsFormatter()
        fmt.style = .default
        let name = fmt.string(from: components).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    // MARK: - Sign out

    func signOut() async {
        do {
            try await Supa.client.auth.signOut()
        } catch {
            authError = (error as NSError).localizedDescription
        }
    }

    // MARK: - Nonce helpers for SIWA

    /// Generate a fresh nonce for the next sign-in attempt. Call before
    /// configuring the ASAuthorizationAppleIDRequest; the hashed version
    /// goes to Apple, the raw version is held here and forwarded to
    /// Supabase alongside the returned identity token.
    func prepareNonce() -> String {
        let raw = Self.randomNonce()
        currentNonce = raw
        return Self.sha256(raw)
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("SecRandomCopyBytes failed: \(status)")
            }
            for byte in randoms where remaining > 0 {
                if byte < chars.count {
                    result.append(chars[Int(byte) % chars.count])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
