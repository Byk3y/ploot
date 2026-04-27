import SwiftUI

// MARK: - Screen 11 · Reminder style

struct ReminderStyleScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingFrame(
            step: .reminderStyle,
            canAdvance: true,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            SingleChoiceBody(
                eyebrow: "Nudges",
                title: "How do you want reminders?",
                subtitle: "You can change this in Settings anytime.",
                options: [
                    OptionOption(value: ReminderStyle.gentle, emoji: "🫶", title: "Gentle nudge", subtitle: "A soft tap, easy to ignore."),
                    OptionOption(value: .firm, emoji: "🚨", title: "Firm ping", subtitle: "You asked — we'll mean it."),
                    OptionOption(value: .none, emoji: "🤫", title: "No reminders", subtitle: "I'll check in on my own.")
                ],
                selected: answers.reminderStyle,
                onPick: { answers.reminderStyle = $0 }
            )
        }
    }
}
