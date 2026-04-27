import SwiftUI

// MARK: - Screen 12 · Planning time

struct PlanningTimeScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingFrame(
            step: .planningTime,
            canAdvance: answers.planningTime != nil,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            SingleChoiceBody(
                eyebrow: "Planning",
                title: "When do you actually plan?",
                subtitle: "Shapes when we show you tomorrow's list.",
                options: [
                    OptionOption(value: PlanningTime.nightBefore, emoji: "🌙", title: "Night before", subtitle: "Set it, sleep on it."),
                    OptionOption(value: .morningOf, emoji: "☕️", title: "Morning of", subtitle: "Coffee-then-list person."),
                    OptionOption(value: .winging, emoji: "🎲", title: "Winging it", subtitle: "I work it out as I go.")
                ],
                selected: answers.planningTime,
                onPick: { answers.planningTime = $0 }
            )
        }
    }
}
