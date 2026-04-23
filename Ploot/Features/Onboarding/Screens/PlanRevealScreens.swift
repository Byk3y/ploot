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

// MARK: - Screen 17 · Loading

/// Fake-loading screen: streams the user's own answers past them so they
/// feel the quiz was actually read. Auto-advances after ~3s.
struct LoadingScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onComplete: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var visibleLines: Int = 0

    private var lines: [(emoji: String, text: String)] {
        var out: [(String, String)] = []
        if let r = answers.primaryRole {
            out.append(("🧩", "\(roleLabel(r)) — got it."))
        }
        if let c = answers.chronotype {
            out.append((chronoEmoji(c), "\(chronoLabel(c)) peak hours locked in."))
        }
        out.append(("🎯", "Daily goal: \(answers.dailyGoal) crushes."))
        out.append(("⏰", "Check-in: \(formatTime(answers.checkinTime))."))
        if answers.trackStreak {
            out.append(("🔥", "Streak tracking on."))
        }
        return out
    }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            VStack(spacing: Spacing.s8) {
                Spacer(minLength: 0)

                // Spinner-ish mark
                Text("🧡")
                    .font(.system(size: 56))
                    .frame(width: 96, height: 96)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(palette.butter300)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(palette.borderInk, lineWidth: 2.5)
                    )
                    .stampedShadow(radius: 24, offset: 3)

                VStack(spacing: Spacing.s2) {
                    Text("Building your plan…")
                        .font(.fraunces(size: 24, weight: 600, opsz: 100, soft: 40))
                        .foregroundStyle(palette.fg1)

                    Text("Reading your \(OnboardingStep.planningTime.ordinal - 2) answers.")
                        .font(.geist(size: 13, weight: 500))
                        .foregroundStyle(palette.fg3)
                }

                // Answer stream
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    ForEach(Array(lines.prefix(visibleLines).enumerated()), id: \.offset) { _, line in
                        HStack(spacing: Spacing.s3) {
                            Text(line.emoji)
                                .font(.system(size: 16))
                            Text(line.text)
                                .font(.geist(size: 14, weight: 500))
                                .foregroundStyle(palette.fg2)
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(palette.success)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .frame(maxWidth: 320, alignment: .leading)
                .animation(Motion.spring, value: visibleLines)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.s6)
        }
        .task {
            for i in 0..<lines.count {
                try? await Task.sleep(for: .milliseconds(i == 0 ? 400 : 500))
                visibleLines = i + 1
            }
            try? await Task.sleep(for: .milliseconds(700))
            onComplete()
        }
    }

    private func roleLabel(_ r: PrimaryRole) -> String {
        switch r {
        case .student: return "Student life"
        case .individualContributor: return "IC grind"
        case .manager: return "Manager mode"
        case .founder: return "Founder life"
        case .parent: return "Parent brain"
        case .creative: return "Creative workflow"
        case .multiHat: return "All-the-hats"
        case .other: return "Your mix"
        }
    }

    private func chronoLabel(_ c: Chronotype) -> String {
        switch c {
        case .early: return "Early-bird"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .night: return "Night-owl"
        }
    }

    private func chronoEmoji(_ c: Chronotype) -> String {
        switch c {
        case .early: return "🌅"
        case .morning: return "☕️"
        case .afternoon: return "☀️"
        case .night: return "🌙"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date).lowercased()
    }
}

// MARK: - Screen 18 · Plan reveal

struct PlanRevealScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var entered: Bool = false

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: Spacing.s12)

                Text("Your plan.")
                    .eyebrow()
                    .foregroundStyle(palette.fgBrand)
                    .padding(.bottom, Spacing.s2)

                Text(headline)
                    .font(.fraunces(size: 32, weight: 600, opsz: 100, soft: 40))
                    .tracking(-0.015 * 32)
                    .foregroundStyle(palette.fg1)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.s5)
                    .padding(.bottom, Spacing.s6)

                planCard
                    .padding(.horizontal, Spacing.s5)
                    .scaleEffect(entered ? 1 : 0.92)
                    .opacity(entered ? 1 : 0)

                Spacer(minLength: 0)

                PrimaryCTA(title: "This is me", action: onContinue)
                    .padding(.horizontal, Spacing.s5)

                Spacer().frame(height: Spacing.s8)
            }
        }
        .onAppear {
            withAnimation(Motion.spring.delay(0.15)) {
                entered = true
            }
        }
        .sensoryFeedback(.success, trigger: entered)
    }

    private var headline: String {
        switch answers.chronotype {
        case .early: return "Early birds crush list first, coffee second."
        case .morning: return "Morning brain, beast mode list."
        case .afternoon: return "Afternoon is your arena."
        case .night: return "Night owl. List after sundown."
        case .none: return "A plan that actually fits you."
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            PlanRow(emoji: "🎯", title: "Daily goal", value: "\(answers.dailyGoal) crushes")
            Divider().background(palette.border)
            PlanRow(emoji: "⏰", title: "Check-in", value: formatTime(answers.checkinTime))
            Divider().background(palette.border)
            PlanRow(emoji: peakEmoji, title: "Peak hours", value: peakLabel)
            Divider().background(palette.border)
            PlanRow(emoji: reminderEmoji, title: "Reminders", value: reminderLabel)
            if answers.trackStreak {
                Divider().background(palette.border)
                PlanRow(emoji: "🔥", title: "Streak", value: "on")
            }
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .strokeBorder(palette.borderInk, lineWidth: 2.5)
        )
        .stampedShadow(radius: Radius.xl, offset: 3)
    }

    private struct PlanRow: View {
        let emoji: String
        let title: String
        let value: String

        @Environment(\.plootPalette) private var palette

        var body: some View {
            HStack(alignment: .center, spacing: Spacing.s3) {
                Text(emoji).font(.system(size: 20))
                Text(title)
                    .font(.geist(size: 14, weight: 500))
                    .foregroundStyle(palette.fg3)
                Spacer()
                Text(value)
                    .font(.geist(size: 15, weight: 600))
                    .foregroundStyle(palette.fg1)
            }
        }
    }

    private var peakEmoji: String {
        switch answers.chronotype {
        case .early: return "🌅"
        case .morning: return "☕️"
        case .afternoon: return "☀️"
        case .night: return "🌙"
        case .none: return "✨"
        }
    }

    private var peakLabel: String {
        switch answers.chronotype {
        case .early: return "Early bird"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .night: return "Night owl"
        case .none: return "Flexible"
        }
    }

    private var reminderEmoji: String {
        switch answers.reminderStyle {
        case .gentle: return "🫶"
        case .firm: return "🚨"
        case .none: return "🤫"
        }
    }

    private var reminderLabel: String {
        switch answers.reminderStyle {
        case .gentle: return "Gentle"
        case .firm: return "Firm"
        case .none: return "Off"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date).lowercased()
    }
}

// MARK: - Screen 19 · Starter projects

struct StarterProjectsScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        OnboardingFrame(
            step: .starterProjects,
            canAdvance: true,
            continueTitle: answers.seedStarterProjects ? "Looks good" : "Start blank",
            onBack: onBack,
            onContinue: onContinue,
            onSkip: nil
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "Almost there",
                    title: "Want these ready on day one?",
                    subtitle: "We'll create these projects so your first list isn't a blank stare."
                )

                VStack(spacing: Spacing.s3) {
                    ForEach(answers.suggestedProjects) { p in
                        ProjectPreviewRow(project: p)
                    }
                }

                // Toggle card
                Button {
                    answers.seedStarterProjects.toggle()
                } label: {
                    HStack {
                        Text(answers.seedStarterProjects ? "Seed these projects" : "Start blank")
                            .font(.geist(size: 14, weight: 600))
                            .foregroundStyle(palette.fg1)
                        Spacer()
                        Toggle("", isOn: $answers.seedStarterProjects)
                            .labelsHidden()
                            .tint(palette.primary)
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s3)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(palette.bgSunken)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(palette.border, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: answers.seedStarterProjects)
            }
        }
    }

    private struct ProjectPreviewRow: View {
        let project: StarterProject

        @Environment(\.plootPalette) private var palette

        var body: some View {
            HStack(spacing: Spacing.s3) {
                Text(project.emoji)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(project.tileColor.fill(palette: palette).opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .strokeBorder(project.tileColor.fill(palette: palette), lineWidth: 2)
                    )
                VStack(alignment: .leading, spacing: 0) {
                    Text(project.name)
                        .font(.geist(size: 15, weight: 600))
                        .foregroundStyle(palette.fg1)
                    Text(project.slug)
                        .font(.jetBrainsMono(size: 11, weight: 400))
                        .foregroundStyle(palette.fg3)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.s3)
            .padding(.vertical, Spacing.s3)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(palette.borderInk, lineWidth: 2)
            )
            .stampedShadow(radius: Radius.md, offset: 2)
        }
    }
}
