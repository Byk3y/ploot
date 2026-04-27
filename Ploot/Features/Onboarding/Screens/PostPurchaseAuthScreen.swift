import SwiftUI
import AuthenticationServices
import SwiftData

// MARK: - Screen 22 · Sign in with Apple (post-purchase)

/// Post-paywall auth. At this point the user has already started their
/// trial via StoreKit (on the device's Apple ID), so SIWA here is
/// framed as "save your plan + sync across devices" — not a gatekeeper.
/// On success we push OnboardingAnswers → public.profiles and seed the
/// selected starter projects before advancing.
struct PostPurchaseAuthScreen: View {
    @Bindable var session: SessionManager
    @Bindable var answers: OnboardingAnswers
    let modelContext: ModelContext
    let onComplete: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var isSigningIn: Bool = false
    @State private var pushError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(
                canGoBack: false,
                showProgress: true,
                step: OnboardingStep.auth.ordinal,
                total: OnboardingStep.total,
                onBack: {}
            )

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    QuestionHeader(
                        eyebrow: "Save your plan",
                        title: "Lock it in with Apple.",
                        subtitle: "One tap. Your tasks + plan sync across every device you sign into."
                    )

                    // Benefits card
                    VStack(alignment: .leading, spacing: Spacing.s3) {
                        BenefitRow(emoji: "☁️", text: "Sync across iPhone + iPad.")
                        BenefitRow(emoji: "🔒", text: "Apple handles the login — no password.")
                        BenefitRow(emoji: "🔥", text: "Keep your streak if you switch phones.")
                    }
                    .padding(Spacing.s4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(palette.bgElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .strokeBorder(palette.borderInk, lineWidth: 2)
                    )
                    .stampedShadow(radius: Radius.lg, offset: 2)

                    if let err = pushError {
                        Text(err)
                            .font(.geist(size: 13, weight: 500))
                            .foregroundStyle(palette.danger)
                    }
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.bottom, Spacing.s4)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: Spacing.s3) {
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
                .opacity(isSigningIn ? 0.6 : 1)

                if let authError = session.authError {
                    Text(authError)
                        .font(.geist(size: 13, weight: 500))
                        .foregroundStyle(palette.danger)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.bottom, Spacing.s4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg.ignoresSafeArea())
    }

    private struct BenefitRow: View {
        let emoji: String
        let text: String
        @Environment(\.plootPalette) private var palette

        var body: some View {
            HStack(spacing: Spacing.s3) {
                Text(emoji).font(.system(size: 20))
                Text(text)
                    .font(.geist(size: 14, weight: 500))
                    .foregroundStyle(palette.fg1)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - SIWA

    private func configureRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = session.prepareNonce()
    }

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                session.authError = "Unexpected credential type."
                return
            }
            isSigningIn = true
            Task {
                await session.signInWithApple(credential)
                if session.authError == nil, session.currentUser != nil {
                    await pushAnswersAndSeed()
                    onComplete()
                }
                isSigningIn = false
            }
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            session.authError = (error as NSError).localizedDescription
        }
    }

    // MARK: - Push onboarding + seed starter projects

    private func pushAnswersAndSeed() async {
        // Mirror answers into @AppStorage first — even if the network
        // push fails, the app can still personalize offline.
        UserPrefs.apply(from: answers)

        do {
            try await SyncService.shared.pushOnboarding(answers: answers, userId: session.currentUser?.id)
        } catch {
            pushError = "Couldn't save your plan to the cloud. We'll retry later."
            #if DEBUG
            print("[Onboarding] pushOnboarding failed: \(error)")
            #endif
        }
        if !answers.projectsToSeed.isEmpty {
            await seedStarterProjects()
        }
    }

    @MainActor
    private func seedStarterProjects() async {
        let toSeed = answers.projectsToSeed
        for (idx, sp) in toSeed.enumerated() {
            // Skip if a project with this slug already exists locally
            // (defensive: shouldn't happen on fresh sign-in, but avoids
            // a unique-constraint crash if realtime sync already pulled
            // remote data between SIWA and here).
            let slug = sp.slug
            let descriptor = FetchDescriptor<PlootProject>(
                predicate: #Predicate { $0.id == slug }
            )
            if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
                continue
            }

            let project = PlootProject(
                id: sp.slug,
                name: sp.name,
                emoji: sp.emoji,
                tileColor: sp.tileColor,
                order: idx + 1
            )
            modelContext.insert(project)
            try? modelContext.save()
            SyncService.shared.push(project: project)
        }
    }
}
