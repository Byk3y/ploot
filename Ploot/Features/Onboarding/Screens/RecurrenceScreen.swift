import SwiftUI

// MARK: - Screen 10 · Recurrence

struct RecurrenceScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingFrame(
            step: .recurrence,
            canAdvance: answers.recurrenceHeavy != nil,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            SingleChoiceBody(
                eyebrow: "Routine",
                title: "Recurring tasks or one-offs?",
                subtitle: "Daily vitamins versus ship-the-deck.",
                options: [
                    OptionOption(value: true, emoji: "🔁", title: "Lots of repeating stuff", subtitle: "Morning routine, weekly review…"),
                    OptionOption(value: false, emoji: "🎯", title: "Mostly one-offs", subtitle: "Each day is different.")
                ],
                selected: answers.recurrenceHeavy,
                onPick: { answers.recurrenceHeavy = $0 }
            )
        }
    }
}
