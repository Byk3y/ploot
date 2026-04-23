import SwiftUI

/// Root container for the quiz → plan reveal → paywall → SIWA flow.
///
/// Phase A: placeholder screen + "Sign in" escape for returning users.
/// Phases B–E fill in the 25 real screens.
///
/// Returning-user path: tap "Sign in" (top trailing) → pushes `AuthView`
/// on the nav stack. When SIWA succeeds `session.state` flips to
/// `.signedIn`, `RootView` swaps in `HomeView`, and this stack is torn
/// down automatically.
struct OnboardingFlow: View {
    @Bindable var session: SessionManager

    @Environment(\.plootPalette) private var palette
    @State private var answers = OnboardingAnswers()

    var body: some View {
        NavigationStack {
            placeholder
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            AuthView(session: session)
                        } label: {
                            Text("Sign in")
                                .font(.geist(size: 15, weight: 500))
                                .foregroundStyle(palette.fg2)
                        }
                    }
                }
        }
    }

    // MARK: - Phase-A placeholder

    private var placeholder: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            mark
            Spacer(minLength: 0)
            copyBlock
            Spacer().frame(height: Spacing.s8)
            getStartedButton
            Spacer().frame(height: Spacing.s6)
        }
        .padding(.horizontal, Spacing.s6)
        .padding(.bottom, Spacing.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg.ignoresSafeArea())
    }

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
            Text("Let's build your plan.")
                .font(.fraunces(size: 28, weight: 600, opsz: 100, soft: 40))
                .tracking(-0.015 * 28)
                .foregroundStyle(palette.fg1)
                .multilineTextAlignment(.center)

            Text("A few quick questions so Ploot matches how you actually work.")
                .font(.geist(size: 15, weight: 400))
                .foregroundStyle(palette.fg2)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 320)
        }
    }

    private var getStartedButton: some View {
        Button {
            // Screens 1–25 are still being built. For Phase A this button
            // is intentionally inert; Phase B wires it up to advance.
        } label: {
            Text("Get started")
                .font(.geist(size: 17, weight: 600))
                .foregroundStyle(palette.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.primary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: 16, offset: 2)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: UUID())
    }
}
