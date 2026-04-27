import SwiftUI

// MARK: - Screen 6 · Current system

struct CurrentSystemScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingFrame(
            step: .currentSystem,
            canAdvance: answers.currentSystem != nil,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            SingleChoiceBody(
                eyebrow: "Before Ploot",
                title: "What are you using right now?",
                subtitle: "So we know what to help you leave behind.",
                options: [
                    OptionOption(value: CurrentSystem.appleReminders, emoji: "🍎", title: "Apple Reminders", subtitle: nil),
                    OptionOption(value: .notion, emoji: "📝", title: "Notion", subtitle: nil),
                    OptionOption(value: .postIts, emoji: "🗒️", title: "Post-its and memory", subtitle: nil),
                    OptionOption(value: .nothing, emoji: "🤷", title: "Nothing really", subtitle: nil),
                    OptionOption(value: .multiple, emoji: "🧃", title: "Several apps — it's a mess", subtitle: nil)
                ],
                selected: answers.currentSystem,
                onPick: { answers.currentSystem = $0 }
            )
        }
    }
}
