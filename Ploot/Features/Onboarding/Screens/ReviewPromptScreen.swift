import SwiftUI
import StoreKit

// MARK: - Screen 16 · Review prompt

/// Fires SKStoreReviewController at the sentiment peak (right after the
/// commitment screens, right before the payoff reveal). Apple rate-limits
/// this to ~3 per year per user — if the sheet doesn't show, the screen
/// still advances on Continue. The ask itself is phrased as an honest
/// "if you like where this is going" rather than a demand.
struct ReviewPromptScreen: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        OnboardingFrame(
            step: .reviewPrompt,
            canAdvance: true,
            continueTitle: "Continue",
            onBack: onBack,
            onContinue: onContinue,
            onSkip: nil
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "Little favor",
                    title: "Like where this is going?",
                    subtitle: "Ploot is built by a small team. A quick review helps more than you'd think."
                )

                VStack(spacing: Spacing.s4) {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(palette.butter500)
                        }
                    }

                    Text("Tap stars, give us a second. No essay required.")
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
        .task {
            // Fire the system review prompt once on appearance. If Apple has
            // already shown it this year, nothing happens — that's fine, the
            // screen still renders and advances on Continue.
            try? await Task.sleep(for: .milliseconds(400))
            requestReview()
        }
    }
}
