import SwiftUI

// MARK: - Screen 9 · Projects vs flat list

struct ProjectsVsListScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingFrame(
            step: .projectsVsList,
            canAdvance: answers.usesProjects != nil,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            SingleChoiceBody(
                eyebrow: "Shape",
                title: "Projects, or one big list?",
                subtitle: "Either works. Ploot does both.",
                options: [
                    OptionOption(value: true, emoji: "🗂️", title: "Group into projects", subtitle: "Work, home, side quests…"),
                    OptionOption(value: false, emoji: "📋", title: "One big list", subtitle: "Everything together, simpler.")
                ],
                selected: answers.usesProjects,
                onPick: { answers.usesProjects = $0 }
            )
        }
    }
}
