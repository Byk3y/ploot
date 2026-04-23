import SwiftUI

// Shared option presentation for enum-backed single-choice screens.
private struct OptionOption<T: Hashable> {
    let value: T
    let emoji: String
    let title: String
    let subtitle: String?
}

private struct SingleChoiceBody<T: Hashable>: View {
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

// MARK: - Screen 8 · Chronotype

struct ChronotypeScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingFrame(
            step: .chronotype,
            canAdvance: answers.chronotype != nil,
            onBack: onBack,
            onContinue: {
                // Sync check-in default to the chosen chronotype unless the
                // user has already overridden on screen 14 (which comes later,
                // so this always wins the first pass).
                if let c = answers.chronotype {
                    var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    comps.hour = c.defaultCheckinHour
                    comps.minute = 47
                    if let d = Calendar.current.date(from: comps) {
                        answers.checkinTime = d
                    }
                }
                onContinue()
            },
            onSkip: onSkip
        ) {
            SingleChoiceBody(
                eyebrow: "Rhythm",
                title: "When does your brain actually work best?",
                subtitle: "We'll line up your check-in with your peak hours.",
                options: [
                    OptionOption(value: Chronotype.early, emoji: "🌅", title: "Early bird", subtitle: "5 to 9 am"),
                    OptionOption(value: .morning, emoji: "☕️", title: "Morning", subtitle: "9 am to noon"),
                    OptionOption(value: .afternoon, emoji: "☀️", title: "Afternoon", subtitle: "noon to 6 pm"),
                    OptionOption(value: .night, emoji: "🌙", title: "Night owl", subtitle: "6 pm and later")
                ],
                selected: answers.chronotype,
                onPick: { answers.chronotype = $0 }
            )
        }
    }
}

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
