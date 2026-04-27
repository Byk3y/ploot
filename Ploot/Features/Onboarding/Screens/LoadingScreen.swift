import SwiftUI

// MARK: - Screen 17 · Loading

/// Fake-loading screen: streams the user's own answers past them so they
/// feel the quiz was actually read. Auto-advances after ~3s.
struct LoadingScreen: View {
    @Bindable var answers: OnboardingAnswers
    let onComplete: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var visibleLines: Int = 0

    private var lines: [(emoji: String, text: String)] {
        var out: [(String, String)] = []
        if let r = answers.primaryRole {
            out.append(("🧩", "\(roleLabel(r)) — got it."))
        }
        if !answers.whatBringsYou.isEmpty {
            let n = answers.whatBringsYou.count
            out.append(("🌀", n == 1 ? "1 reason noted." : "\(n) reasons noted."))
        }
        if !answers.gettingInTheWay.isEmpty {
            let n = answers.gettingInTheWay.count
            out.append(("🚧", n == 1 ? "1 tripwire — we'll dodge it." : "\(n) tripwires — we'll dodge them."))
        }
        if let c = answers.chronotype {
            out.append((chronoEmoji(c), "\(chronoLabel(c)) peak hours locked in."))
        }
        out.append(("🎯", "Daily goal: \(answers.dailyGoal) crushes."))
        out.append(("⏰", "Check-in: \(formatTime(answers.checkinTime))."))
        if answers.trackStreak {
            out.append(("🔥", "Streak tracking on."))
        }
        return out
    }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            VStack(spacing: Spacing.s8) {
                Spacer(minLength: 0)

                // Spinner-ish mark
                Text("🧡")
                    .font(.system(size: 56))
                    .frame(width: 96, height: 96)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(palette.butter300)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(palette.borderInk, lineWidth: 2.5)
                    )
                    .stampedShadow(radius: 24, offset: 3)

                VStack(spacing: Spacing.s2) {
                    Text("Building your plan…")
                        .font(.fraunces(size: 24, weight: 600, opsz: 100, soft: 40))
                        .foregroundStyle(palette.fg1)

                    Text("Reading your \(OnboardingStep.planningTime.ordinal - 2) answers.")
                        .font(.geist(size: 13, weight: 500))
                        .foregroundStyle(palette.fg3)
                }

                // Answer stream
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    ForEach(Array(lines.prefix(visibleLines).enumerated()), id: \.offset) { _, line in
                        HStack(spacing: Spacing.s3) {
                            Text(line.emoji)
                                .font(.system(size: 16))
                            Text(line.text)
                                .font(.geist(size: 14, weight: 500))
                                .foregroundStyle(palette.fg2)
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(palette.success)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .frame(maxWidth: 320, alignment: .leading)
                .animation(Motion.spring, value: visibleLines)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.s6)
        }
        .task {
            for i in 0..<lines.count {
                try? await Task.sleep(for: .milliseconds(i == 0 ? 400 : 500))
                visibleLines = i + 1
            }
            try? await Task.sleep(for: .milliseconds(700))
            onComplete()
        }
    }

    private func roleLabel(_ r: PrimaryRole) -> String {
        switch r {
        case .student: return "Student life"
        case .individualContributor: return "IC grind"
        case .manager: return "Manager mode"
        case .founder: return "Founder life"
        case .parent: return "Parent brain"
        case .creative: return "Creative workflow"
        case .multiHat: return "All-the-hats"
        case .other: return "Your mix"
        }
    }

    private func chronoLabel(_ c: Chronotype) -> String {
        switch c {
        case .early: return "Early-bird"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .night: return "Night-owl"
        }
    }

    private func chronoEmoji(_ c: Chronotype) -> String {
        switch c {
        case .early: return "🌅"
        case .morning: return "☕️"
        case .afternoon: return "☀️"
        case .night: return "🌙"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date).lowercased()
    }
}
