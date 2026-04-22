import SwiftUI
import AuthenticationServices

/// Sign-in gate. Shown when `session.state == .signedOut`. Native SIWA
/// only — no email / password / social alternatives. Styled to match
/// the Ploot cream + Fraunces display voice.
struct AuthView: View {
    @Bindable var session: SessionManager

    @Environment(\.plootPalette) private var palette
    @State private var isSigningIn: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            mark
            Spacer(minLength: 0)
            copyBlock
            Spacer().frame(height: Spacing.s8)
            signInButton
            errorStrip
            Spacer().frame(height: Spacing.s6)
            legal
        }
        .padding(.horizontal, Spacing.s6)
        .padding(.bottom, Spacing.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg.ignoresSafeArea())
    }

    // MARK: - Mark + copy

    private var mark: some View {
        VStack(spacing: Spacing.s4) {
            Text("🧡")
                .font(.system(size: 72))
                .frame(width: 120, height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(palette.butter300)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2.5)
                )
                .stampedShadow(radius: 32, offset: 3)

            Text("Ploot")
                .font(.fraunces(size: 44, weight: 600, opsz: 144, soft: 50))
                .tracking(-0.02 * 44)
                .foregroundStyle(palette.fg1)
        }
    }

    private var copyBlock: some View {
        VStack(spacing: Spacing.s3) {
            Text("What's next?")
                .font(.fraunces(size: 28, weight: 600, opsz: 100, soft: 40))
                .tracking(-0.015 * 28)
                .foregroundStyle(palette.fg1)
                .multilineTextAlignment(.center)

            Text("Sign in to start crushing your list. Your tasks follow you across devices.")
                .font(.geist(size: 15, weight: 400))
                .foregroundStyle(palette.fg2)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 320)
        }
    }

    // MARK: - Button

    private var signInButton: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: configureRequest,
            onCompletion: handleCompletion
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 52)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.borderInk, lineWidth: 2)
        )
        .stampedShadow(radius: 16, offset: 2)
        .disabled(isSigningIn)
        .opacity(isSigningIn ? 0.7 : 1)
    }

    private var errorStrip: some View {
        Group {
            if let error = session.authError {
                Text(error)
                    .font(.geist(size: 13, weight: 500))
                    .foregroundStyle(palette.danger)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.s3)
                    .transition(.opacity)
            }
        }
    }

    private var legal: some View {
        Text("By continuing you agree to the warm-hearted no-BS use of Ploot.")
            .font(.geist(size: 11, weight: 400))
            .foregroundStyle(palette.fg3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)
    }

    // MARK: - SIWA handlers

    private func configureRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        // Hash the raw nonce before handing it to Apple. The raw value is
        // stashed in SessionManager until the identity token comes back.
        request.nonce = session.prepareNonce()
    }

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                session.authError = "Unexpected credential type from Apple."
                return
            }
            isSigningIn = true
            Task {
                await session.signInWithApple(credential)
                isSigningIn = false
            }
        case .failure(let error):
            // User-cancelled is the most common path and isn't really an
            // error worth surfacing — just bail quietly.
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            session.authError = (error as NSError).localizedDescription
        }
    }
}
