import SwiftUI

// MARK: - Screen 18 · Plan reveal

struct PlanRevealScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var entered: Bool = false

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: Spacing.s12)

                Text("Your plan.")
                    .eyebrow()
                    .foregroundStyle(palette.fgBrand)
                    .padding(.bottom, Spacing.s2)

                Text(headline)
                    .font(.fraunces(size: 32, weight: 600, opsz: 100, soft: 40))
                    .tracking(-0.015 * 32)
                    .foregroundStyle(palette.fg1)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.s5)
                    .padding(.bottom, Spacing.s6)

                planCard
                    .padding(.horizontal, Spacing.s5)
                    .scaleEffect(entered ? 1 : 0.92)
                    .opacity(entered ? 1 : 0)

                Spacer(minLength: 0)

                PrimaryCTA(title: "This is me", action: onContinue)
                    .padding(.horizontal, Spacing.s5)

                Spacer().frame(height: Spacing.s8)
            }
        }
        .onAppear {
            withAnimation(Motion.spring.delay(0.15)) {
                entered = true
            }
        }
        .sensoryFeedback(.success, trigger: entered)
    }

    private var headline: String {
        switch answers.chronotype {
        case .early: return "Early birds crush list first, coffee second."
        case .morning: return "Morning brain, beast mode list."
        case .afternoon: return "Afternoon is your arena."
        case .night: return "Night owl. List after sundown."
        case .none: return "A plan that actually fits you."
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            PlanRow(emoji: "🎯", title: "Daily goal", value: "\(answers.dailyGoal) crushes")
            Divider().background(palette.border)
            PlanRow(emoji: "⏰", title: "Check-in", value: formatTime(answers.checkinTime))
            Divider().background(palette.border)
            PlanRow(emoji: peakEmoji, title: "Peak hours", value: peakLabel)
            Divider().background(palette.border)
            PlanRow(emoji: "📋", title: "Typical day", value: "\(answers.tasksPerDay) tasks")
            if let usesProjects = answers.usesProjects {
                Divider().background(palette.border)
                PlanRow(emoji: usesProjects ? "🗂️" : "📝", title: "Shape", value: usesProjects ? "Projects" : "One list")
            }
            Divider().background(palette.border)
            PlanRow(emoji: reminderEmoji, title: "Reminders", value: reminderLabel)
            if answers.trackStreak {
                Divider().background(palette.border)
                PlanRow(emoji: "🔥", title: "Streak", value: "on")
            }
        }
        .padding(Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .strokeBorder(palette.borderInk, lineWidth: 2.5)
        )
        .stampedShadow(radius: Radius.xl, offset: 3)
    }

    private struct PlanRow: View {
        let emoji: String
        let title: String
        let value: String

        @Environment(\.plootPalette) private var palette

        var body: some View {
            HStack(alignment: .center, spacing: Spacing.s3) {
                Text(emoji).font(.system(size: 20))
                Text(title)
                    .font(.geist(size: 14, weight: 500))
                    .foregroundStyle(palette.fg3)
                Spacer()
                Text(value)
                    .font(.geist(size: 15, weight: 600))
                    .foregroundStyle(palette.fg1)
            }
        }
    }

    private var peakEmoji: String {
        switch answers.chronotype {
        case .early: return "🌅"
        case .morning: return "☕️"
        case .afternoon: return "☀️"
        case .night: return "🌙"
        case .none: return "✨"
        }
    }

    private var peakLabel: String {
        switch answers.chronotype {
        case .early: return "Early bird"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .night: return "Night owl"
        case .none: return "Flexible"
        }
    }

    private var reminderEmoji: String {
        switch answers.reminderStyle {
        case .gentle: return "🫶"
        case .firm: return "🚨"
        case .none: return "🤫"
        }
    }

    private var reminderLabel: String {
        switch answers.reminderStyle {
        case .gentle: return "Gentle"
        case .firm: return "Firm"
        case .none: return "Off"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date).lowercased()
    }
}
