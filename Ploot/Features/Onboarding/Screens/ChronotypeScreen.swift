import SwiftUI

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
