import SwiftUI

// MARK: - Screen 7 · Tasks per day

struct TasksPerDayScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingFrame(
            step: .tasksPerDay,
            canAdvance: true,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                QuestionHeader(
                    eyebrow: "Rough count",
                    title: "How many tasks land on a typical day?",
                    subtitle: "Be honest. We won't tell."
                )
                IntensitySlider(
                    value: $answers.tasksPerDay,
                    range: 1...20,
                    caption: { n in
                        switch n {
                        case 1...3: return "calm day"
                        case 4...7: return "steady"
                        case 8...12: return "busy"
                        default: return "that's a lot"
                        }
                    }
                )
                Spacer(minLength: 0)
            }
        }
    }
}
