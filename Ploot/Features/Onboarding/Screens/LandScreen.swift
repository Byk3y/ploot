import SwiftUI

// MARK: - Screen 24 · Land

struct LandScreen: View {
    @Binding var onboardingCompleted: Bool

    @Environment(\.plootPalette) private var palette
    @State private var entered: Bool = false
    @State private var ctaVisible: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("🧡")
                .font(.system(size: 88))
                .scaleEffect(entered ? 1.0 : 0.4)
                .opacity(entered ? 1 : 0)

            Spacer().frame(height: Spacing.s6)

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

            Spacer()

            // Explicit CTA so the user is never stuck waiting. Appears
            // slightly after the mark + copy land. Auto-advance still
            // fires via the .task below — whichever happens first wins.
            PrimaryCTA(title: "Open my list", action: complete)
                .padding(.horizontal, Spacing.s5)
                .padding(.bottom, Spacing.s6)
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg.ignoresSafeArea())
        .task {
            withAnimation(Motion.spring.delay(0.05)) { entered = true }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(Motion.spring) { ctaVisible = true }
            try? await Task.sleep(for: .milliseconds(1800))
            // Auto-advance if the user's still watching.
            complete()
        }
        .plootHaptic(.success, trigger: entered)
    }

    private func complete() {
        guard !onboardingCompleted else { return }
        onboardingCompleted = true
    }
}
