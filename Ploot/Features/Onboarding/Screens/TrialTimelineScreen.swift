import SwiftUI

// MARK: - Screen 20 · Trial transparency

/// The single biggest trial-to-paid lever: telling users exactly what
/// will happen. Hiding the renewal date pushes users into rage-cancel
/// territory; transparency builds trust.
struct TrialTimelineScreen: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        OnboardingFrame(
            step: .trialTimeline,
            canAdvance: true,
            continueTitle: "See my options",
            onBack: onBack,
            onContinue: onContinue,
            onSkip: nil
        ) {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                QuestionHeader(
                    eyebrow: "No surprises",
                    title: "Here's how your free trial works.",
                    subtitle: "Seven days, full access, no tricks."
                )

                VStack(spacing: 0) {
                    TimelineRow(
                        day: "Today",
                        emoji: "🔓",
                        title: "Full access unlocks",
                        subtitle: "Everything we build. Every feature. Go."
                    )
                    TimelineConnector()
                    TimelineRow(
                        day: "Day 5",
                        emoji: "🔔",
                        title: "We remind you",
                        subtitle: "A quick ping so you're not caught off-guard."
                    )
                    TimelineConnector()
                    TimelineRow(
                        day: "Day 7",
                        emoji: "💳",
                        title: "Trial ends",
                        subtitle: "Cancel anytime in Settings before then.",
                        isLast: true
                    )
                }
                .padding(Spacing.s4)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: Radius.lg, offset: 2)

                Spacer(minLength: 0)
            }
        }
    }

    private struct TimelineRow: View {
        let day: String
        let emoji: String
        let title: String
        let subtitle: String
        var isLast: Bool = false

        @Environment(\.plootPalette) private var palette

        var body: some View {
            HStack(alignment: .top, spacing: Spacing.s3) {
                VStack(spacing: 0) {
                    Text(emoji)
                        .font(.system(size: 22))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(palette.butter300.opacity(0.5))
                        )
                        .overlay(
                            Circle().strokeBorder(palette.borderInk, lineWidth: 2)
                        )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.uppercased())
                        .font(.jetBrainsMono(size: 10, weight: 500))
                        .tracking(11 * 0.08)
                        .foregroundStyle(palette.fgBrand)
                    Text(title)
                        .font(.geist(size: 16, weight: 600))
                        .foregroundStyle(palette.fg1)
                    Text(subtitle)
                        .font(.geist(size: 13, weight: 400))
                        .foregroundStyle(palette.fg3)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.s2)
        }
    }

    private struct TimelineConnector: View {
        @Environment(\.plootPalette) private var palette
        var body: some View {
            HStack {
                Rectangle()
                    .fill(palette.border)
                    .frame(width: 2, height: 16)
                    .padding(.leading, 19)
                Spacer()
            }
        }
    }
}
