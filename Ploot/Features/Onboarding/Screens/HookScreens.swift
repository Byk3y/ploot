import SwiftUI

// MARK: - Screen 1 · Welcome

struct WelcomeScreen: View {
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            mark
            Spacer(minLength: 0)
            copyBlock
            Spacer().frame(height: Spacing.s8)
            PrimaryCTA(title: "Let's go", action: onContinue)
            Spacer().frame(height: Spacing.s8)
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
}

// MARK: - Screen 2 · Social proof

struct SocialProofScreen: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        OnboardingFrame(
            step: .socialProof,
            canAdvance: true,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: nil
        ) {
            VStack(spacing: Spacing.s8) {
                Spacer().frame(height: Spacing.s4)

                // Stars
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(palette.butter500)
                    }
                }

                // Quote card
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text("\u{201C}Finally a list that doesn't stress me out. Feels like the app actually gets my brain.\u{201D}")
                        .font(.fraunces(size: 22, weight: 500, opsz: 72, soft: 40, italic: true))
                        .foregroundStyle(palette.fg1)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    HStack(spacing: Spacing.s2) {
                        Circle()
                            .fill(palette.clay300)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("M")
                                    .font(.geist(size: 14, weight: 600))
                                    .foregroundStyle(palette.clay700)
                            )
                            .overlay(
                                Circle().strokeBorder(palette.borderInk, lineWidth: 2)
                            )
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Maya R.")
                                .font(.geist(size: 13, weight: 600))
                                .foregroundStyle(palette.fg1)
                            Text("new user, switched from Notion")
                                .font(.geist(size: 11, weight: 400))
                                .foregroundStyle(palette.fg3)
                        }
                    }
                }
                .padding(Spacing.s5)
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

                Text("Used by folks who've tried everything else.")
                    .font(.geist(size: 13, weight: 500))
                    .foregroundStyle(palette.fg3)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Screen 3 · What brings you

struct WhatBringsYouScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    private let options: [(key: String, emoji: String, label: String)] = [
        ("overwhelmed", "🌀", "Feeling overwhelmed"),
        ("missed_deadlines", "⏰", "Missing deadlines"),
        ("too_many_projects", "🗂️", "Juggling too many projects"),
        ("trying_new", "✨", "Just trying something new"),
        ("something_else", "💭", "Something else")
    ]

    var body: some View {
        OnboardingFrame(
            step: .whatBringsYou,
            canAdvance: !answers.whatBringsYou.isEmpty,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "Quick check",
                    title: "What brings you here?",
                    subtitle: "Pick any that fit. No wrong answers."
                )
                VStack(spacing: Spacing.s3) {
                    ForEach(options, id: \.key) { opt in
                        ChoiceCard(
                            emoji: opt.emoji,
                            title: opt.label,
                            subtitle: nil,
                            selected: answers.whatBringsYou.contains(opt.key)
                        ) {
                            toggle(opt.key)
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ key: String) {
        if answers.whatBringsYou.contains(key) {
            answers.whatBringsYou.remove(key)
        } else {
            answers.whatBringsYou.insert(key)
        }
    }
}

// MARK: - Screen 4 · Getting in the way

struct GettingInTheWayScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    private let options: [(key: String, emoji: String, label: String)] = [
        ("forget", "🫥", "I forget to check my list"),
        ("too_many_lists", "📑", "Too many lists everywhere"),
        ("adhd", "🧠", "My ADHD brain"),
        ("perfectionism", "🎯", "Perfectionism"),
        ("something_else", "💭", "Something else")
    ]

    var body: some View {
        OnboardingFrame(
            step: .gettingInTheWay,
            canAdvance: !answers.gettingInTheWay.isEmpty,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "And honestly",
                    title: "What's getting in the way?",
                    subtitle: "Pick up to three. We'll tune Ploot to dodge them."
                )
                VStack(spacing: Spacing.s3) {
                    ForEach(options, id: \.key) { opt in
                        ChoiceCard(
                            emoji: opt.emoji,
                            title: opt.label,
                            subtitle: nil,
                            selected: answers.gettingInTheWay.contains(opt.key)
                        ) {
                            toggle(opt.key)
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ key: String) {
        if answers.gettingInTheWay.contains(key) {
            answers.gettingInTheWay.remove(key)
        } else if answers.gettingInTheWay.count < 3 {
            answers.gettingInTheWay.insert(key)
        }
    }
}
