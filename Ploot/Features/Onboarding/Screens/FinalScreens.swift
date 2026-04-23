import SwiftUI
import AuthenticationServices
import UserNotifications
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
        do {
            try await SyncService.shared.pushOnboarding(answers: answers, userId: session.currentUser?.id)
        } catch {
            pushError = "Couldn't save your plan to the cloud. We'll retry later."
            #if DEBUG
            print("[Onboarding] pushOnboarding failed: \(error)")
            #endif
        }
        if answers.seedStarterProjects {
            await seedStarterProjects()
        }
    }

    @MainActor
    private func seedStarterProjects() async {
        let suggestions = answers.suggestedProjects
        for (idx, sp) in suggestions.enumerated() {
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

// MARK: - Screen 23 · Notifications

struct NotificationsScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onComplete: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var isRequesting: Bool = false

    var body: some View {
        OnboardingFrame(
            step: .notifications,
            canAdvance: true,
            continueTitle: isRequesting ? "…" : "Turn on nudges",
            onBack: nil,
            onContinue: { Task { await requestAndAdvance() } },
            onSkip: { scheduleOnlyThenAdvance() }
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "Last thing",
                    title: "Can we ping you at \(formatTime(answers.checkinTime))?",
                    subtitle: reminderCopy
                )

                // Illustration card
                VStack(spacing: Spacing.s3) {
                    Text("🔔")
                        .font(.system(size: 56))
                        .opacity(answers.reminderStyle == .none ? 0.3 : 1)
                    Text(answers.reminderStyle == .none ? "You chose no reminders — we'll stay quiet." : "One nudge per day. No five-minute spam.")
                        .font(.geist(size: 13, weight: 500))
                        .foregroundStyle(palette.fg3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.s6)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: Radius.lg, offset: 2)

                Spacer(minLength: 0)
            }
        }
    }

    private var reminderCopy: String {
        switch answers.reminderStyle {
        case .gentle: return "Gentle nudge — easy to ignore if you're in flow."
        case .firm: return "Firm ping — you asked, we'll mean it."
        case .none: return "We'll skip the ping. You can turn it on in Settings later."
        }
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date).lowercased()
    }

    private func requestAndAdvance() async {
        isRequesting = true
        defer { isRequesting = false }

        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await OnboardingNotifications.scheduleTrialReminder()
            }
        } catch {
            #if DEBUG
            print("[Onboarding] Notification auth failed: \(error)")
            #endif
        }
        onComplete()
    }

    private func scheduleOnlyThenAdvance() {
        Task {
            await OnboardingNotifications.scheduleTrialReminder()
            onComplete()
        }
    }
}

// MARK: - Screen 24 · Land

struct LandScreen: View {
    @Binding var onboardingCompleted: Bool

    @Environment(\.plootPalette) private var palette
    @State private var entered: Bool = false

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()

            VStack(spacing: Spacing.s6) {
                Text("🧡")
                    .font(.system(size: 88))
                    .scaleEffect(entered ? 1.0 : 0.4)
                    .opacity(entered ? 1 : 0)

                VStack(spacing: Spacing.s2) {
                    Text("You're in.")
                        .font(.fraunces(size: 36, weight: 600, opsz: 144, soft: 50))
                        .tracking(-0.02 * 36)
                        .foregroundStyle(palette.fg1)
                    Text("Let's see what today looks like.")
                        .font(.geist(size: 15, weight: 500))
                        .foregroundStyle(palette.fg3)
                }
                .opacity(entered ? 1 : 0)
                .offset(y: entered ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(Motion.spring.delay(0.05)) { entered = true }
            Task {
                try? await Task.sleep(for: .milliseconds(1500))
                onboardingCompleted = true
            }
        }
        .sensoryFeedback(.success, trigger: entered)
    }
}

// MARK: - Notification scheduling

enum OnboardingNotifications {
    /// Schedule the Day-5 trial-ending reminder. Safe to call even if
    /// permissions weren't granted — UNNotificationCenter silently
    /// no-ops the request.
    static func scheduleTrialReminder() async {
        let center = UNUserNotificationCenter.current()
        // Clear any prior Day-5 schedules so re-runs don't stack up.
        center.removePendingNotificationRequests(withIdentifiers: ["ploot.trial.day5"])

        let content = UNMutableNotificationContent()
        content.title = "Your trial ends in 2 days"
        content.body = "Your plan, your streak, your projects — keep them going with Ploot Pro."
        content.sound = .default

        // 5 days from now. For local testing, override PLOOT_TRIAL_DEBUG
        // at build time to fire at 30s.
        let trigger: UNNotificationTrigger
        #if DEBUG
        if ProcessInfo.processInfo.environment["PLOOT_TRIAL_DEBUG"] == "1" {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 24 * 5, repeats: false)
        }
        #else
        trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 24 * 5, repeats: false)
        #endif

        let request = UNNotificationRequest(
            identifier: "ploot.trial.day5",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
}
