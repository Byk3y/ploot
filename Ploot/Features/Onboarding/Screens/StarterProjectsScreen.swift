import SwiftUI

// MARK: - Screen 19 · Starter projects

struct StarterProjectsScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette

    private var selectedCount: Int {
        answers.selectedStarterSlugs.count
    }

    private var continueTitle: String {
        selectedCount == 0 ? "Start blank" :
        selectedCount == answers.suggestedProjects.count ? "Looks good" :
        "Create \(selectedCount)"
    }

    var body: some View {
        OnboardingFrame(
            step: .starterProjects,
            canAdvance: true,
            continueTitle: continueTitle,
            onBack: onBack,
            onContinue: onContinue,
            onSkip: nil
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "Almost there",
                    title: "Want these ready on day one?",
                    subtitle: "Tap to keep or skip any. We'll create the ones you want so your first list isn't a blank stare."
                )

                VStack(spacing: Spacing.s3) {
                    ForEach(answers.suggestedProjects) { p in
                        ProjectPreviewRow(
                            project: p,
                            selected: answers.selectedStarterSlugs.contains(p.slug),
                            action: { toggle(p.slug) }
                        )
                    }
                }

                // Select-all / select-none link
                HStack {
                    Spacer()
                    Button(selectedCount == answers.suggestedProjects.count ? "Deselect all" : "Select all") {
                        if selectedCount == answers.suggestedProjects.count {
                            answers.selectedStarterSlugs.removeAll()
                        } else {
                            answers.selectedStarterSlugs = Set(answers.suggestedProjects.map(\.slug))
                        }
                    }
                    .font(.geist(size: 13, weight: 500))
                    .foregroundStyle(palette.fg3)
                }
            }
        }
        .onAppear {
            // Pre-select everything by default. If the role changed later
            // (e.g. user went back and picked different role), refresh
            // the set — but preserve deselections within a stable role.
            if answers.selectedStarterSlugs.isEmpty {
                answers.selectedStarterSlugs = Set(answers.suggestedProjects.map(\.slug))
            }
        }
    }

    private func toggle(_ slug: String) {
        if answers.selectedStarterSlugs.contains(slug) {
            answers.selectedStarterSlugs.remove(slug)
        } else {
            answers.selectedStarterSlugs.insert(slug)
        }
    }

    private struct ProjectPreviewRow: View {
        let project: StarterProject
        let selected: Bool
        let action: () -> Void

        @Environment(\.plootPalette) private var palette

        var body: some View {
            Button(action: action) {
                HStack(spacing: Spacing.s3) {
                    Text(project.emoji)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(project.tileColor.fill(palette: palette).opacity(selected ? 0.25 : 0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(project.tileColor.fill(palette: palette), lineWidth: 2)
                        )
                    VStack(alignment: .leading, spacing: 0) {
                        Text(project.name)
                            .font(.geist(size: 15, weight: 600))
                            .foregroundStyle(selected ? palette.onPrimary : palette.fg1)
                        Text(project.slug)
                            .font(.jetBrainsMono(size: 11, weight: 400))
                            .foregroundStyle(selected ? palette.onPrimary.opacity(0.8) : palette.fg3)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(selected ? palette.onPrimary : palette.fg3)
                }
                .padding(.horizontal, Spacing.s3)
                .padding(.vertical, Spacing.s3)
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
            .plootHaptic(.selection, trigger: selected)
            .animation(Motion.springFast, value: selected)
        }
    }
}
