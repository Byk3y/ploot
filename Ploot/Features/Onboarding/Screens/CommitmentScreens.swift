import SwiftUI

// MARK: - Screen 13 · Daily goal

struct DailyGoalScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette

    private struct Tier: Identifiable {
        let value: Int
        let name: String
        let tagline: String
        var id: Int { value }
    }

    private let tiers: [Tier] = [
        Tier(value: 3, name: "Gentle", tagline: "three wins, call it a day."),
        Tier(value: 5, name: "Standard", tagline: "the classic steady clip."),
        Tier(value: 8, name: "Beastmode", tagline: "for the overachievers.")
    ]

    var body: some View {
        OnboardingFrame(
            step: .dailyGoal,
            canAdvance: tiers.contains(where: { $0.value == answers.dailyGoal }),
            onBack: onBack,
            onContinue: onContinue,
            onSkip: nil
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "Commitment",
                    title: "Pick your daily goal.",
                    subtitle: "Crushes per day. Tap a tier — you can change it later."
                )
                VStack(spacing: Spacing.s3) {
                    ForEach(tiers) { tier in
                        TierCard(
                            tier: tier,
                            selected: answers.dailyGoal == tier.value
                        ) {
                            answers.dailyGoal = tier.value
                        }
                    }
                }
            }
        }
    }

    private struct TierCard: View {
        let tier: Tier
        let selected: Bool
        let action: () -> Void

        @Environment(\.plootPalette) private var palette

        var body: some View {
            Button(action: action) {
                HStack(alignment: .center, spacing: Spacing.s4) {
                    Text("\(tier.value)")
                        .font(.fraunces(size: 40, weight: 600, opsz: 100, soft: 40))
                        .foregroundStyle(selected ? palette.onPrimary : palette.fg1)
                        .frame(width: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.name)
                            .font(.geist(size: 16, weight: 600))
                            .foregroundStyle(selected ? palette.onPrimary : palette.fg1)
                        Text(tier.tagline)
                            .font(.geist(size: 13, weight: 400))
                            .foregroundStyle(selected ? palette.onPrimary.opacity(0.85) : palette.fg3)
                    }
                    Spacer(minLength: 0)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.onPrimary)
                    }
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.vertical, Spacing.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(selected ? palette.primary : palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: Radius.md, offset: 2)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: selected)
            .animation(Motion.springFast, value: selected)
        }
    }
}

// MARK: - Screen 14 · Check-in time

struct CheckinTimeScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        OnboardingFrame(
            step: .checkinTime,
            canAdvance: true,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: nil
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "Daily rhythm",
                    title: "When should we check in?",
                    subtitle: chronotypeHint
                )
                TimePickerCard(time: $answers.checkinTime)
                Text("We'll send one nudge at this time — not every five minutes. Pinky promise.")
                    .font(.geist(size: 13, weight: 400))
                    .foregroundStyle(palette.fg3)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                Spacer(minLength: 0)
            }
        }
    }

    private var chronotypeHint: String {
        switch answers.chronotype {
        case .early: return "We pre-filled a pre-dawn slot based on your early-bird answer."
        case .morning: return "We pre-filled a morning slot based on your answer."
        case .afternoon: return "We pre-filled an afternoon slot based on your answer."
        case .night: return "We pre-filled an evening slot based on your night-owl answer."
        case .none: return "Pick what fits your day."
        }
    }
}

// MARK: - Screen 15 · Streak opt-in

struct StreakScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        OnboardingFrame(
            step: .streak,
            canAdvance: true,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: nil
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "One more thing",
                    title: "Track your streak?",
                    subtitle: "A tiny 🔥 that grows each day you hit your goal. You can turn it off anytime."
                )

                // Big toggle card
                Button {
                    answers.trackStreak.toggle()
                } label: {
                    HStack(spacing: Spacing.s4) {
                        Text("🔥")
                            .font(.system(size: 44))
                            .opacity(answers.trackStreak ? 1 : 0.25)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(answers.trackStreak ? "Streak on" : "Streak off")
                                .font(.geist(size: 17, weight: 600))
                                .foregroundStyle(palette.fg1)
                            Text(answers.trackStreak ? "Tap to turn off." : "Tap to turn on.")
                                .font(.geist(size: 13, weight: 400))
                                .foregroundStyle(palette.fg3)
                        }
                        Spacer(minLength: 0)
                        Toggle("", isOn: $answers.trackStreak)
                            .labelsHidden()
                            .tint(palette.primary)
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
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: answers.trackStreak)
                .animation(Motion.springFast, value: answers.trackStreak)

                Spacer(minLength: 0)
            }
        }
    }
}
