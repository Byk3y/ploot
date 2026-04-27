import SwiftUI

/// Generic option presentation for the enum-backed single-choice
/// onboarding screens (Role, CurrentSystem, Chronotype, ProjectsVsList,
/// Recurrence, ReminderStyle, PlanningTime). Each screen passes its own
/// option list + binding; this view handles the layout, selection
/// styling, and pick callback.
struct OptionOption<T: Hashable> {
    let value: T
    let emoji: String
    let title: String
    let subtitle: String?
}

struct SingleChoiceBody<T: Hashable>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let options: [OptionOption<T>]
    let selected: T?
    let onPick: (T) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s6) {
            QuestionHeader(eyebrow: eyebrow, title: title, subtitle: subtitle)
            VStack(spacing: Spacing.s3) {
                ForEach(options, id: \.value) { opt in
                    ChoiceCard(
                        emoji: opt.emoji,
                        title: opt.title,
                        subtitle: opt.subtitle,
                        selected: selected == opt.value,
                        action: { onPick(opt.value) }
                    )
                }
            }
        }
    }
}
