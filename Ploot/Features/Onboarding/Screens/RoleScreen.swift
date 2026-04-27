import SwiftUI

// MARK: - Screen 5 · Role

struct RoleScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingFrame(
            step: .role,
            canAdvance: answers.primaryRole != nil,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            ScrollView {
                SingleChoiceBody(
                    eyebrow: "About you",
                    title: "What do you spend your days doing?",
                    subtitle: "Shapes the starter projects we'll suggest later.",
                    options: [
                        OptionOption(value: PrimaryRole.student, emoji: "📚", title: "Student", subtitle: nil),
                        OptionOption(value: .individualContributor, emoji: "💻", title: "Individual contributor", subtitle: "Engineer, designer, analyst…"),
                        OptionOption(value: .manager, emoji: "🗂️", title: "Manager", subtitle: nil),
                        OptionOption(value: .founder, emoji: "🚀", title: "Founder / self-employed", subtitle: nil),
                        OptionOption(value: .parent, emoji: "🏡", title: "Parent / caregiver", subtitle: nil),
                        OptionOption(value: .creative, emoji: "🎨", title: "Creative / freelancer", subtitle: nil),
                        OptionOption(value: .multiHat, emoji: "🎩", title: "All of the above, honestly", subtitle: nil),
                        OptionOption(value: .other, emoji: "💭", title: "Something else", subtitle: nil)
                    ],
                    selected: answers.primaryRole,
                    onPick: { answers.primaryRole = $0 }
                )
                .padding(.bottom, Spacing.s4)
            }
            .scrollIndicators(.hidden)
        }
    }
}
