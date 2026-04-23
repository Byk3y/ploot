import SwiftUI

// MARK: - Progress bar

/// Thin stamped progress bar at the top of each question screen.
struct OnboardingProgress: View {
    let step: Int      // 1-indexed
    let total: Int

    @Environment(\.plootPalette) private var palette

    private var fraction: CGFloat {
        CGFloat(step) / CGFloat(max(total, 1))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.bgSunken)
                Capsule()
                    .fill(palette.primary)
                    .frame(width: max(6, geo.size.width * fraction))
                    .animation(Motion.spring, value: step)
            }
        }
        .frame(height: 8)
        .overlay(
            Capsule()
                .strokeBorder(palette.borderInk, lineWidth: 1.5)
        )
    }
}

// MARK: - Top bar (back + progress)

struct OnboardingTopBar: View {
    let canGoBack: Bool
    let showProgress: Bool
    let step: Int
    let total: Int
    let onBack: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        HStack(spacing: Spacing.s4) {
            if canGoBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.fg1)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(palette.bgElevated)
                        )
                        .overlay(
                            Circle().strokeBorder(palette.borderInk, lineWidth: 2)
                        )
                        .stampedShadow(radius: 18, offset: 2)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: step)
            } else {
                Spacer().frame(width: 36, height: 36)
            }

            if showProgress {
                OnboardingProgress(step: step, total: total)
            } else {
                Spacer()
            }

            Spacer().frame(width: 36)
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.top, Spacing.s3)
        .padding(.bottom, Spacing.s4)
    }
}

// MARK: - Primary CTA

struct PrimaryCTA: View {
    let title: String
    var enabled: Bool = true
    var action: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var pressed: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.geist(size: 17, weight: 600))
                .foregroundStyle(palette.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(enabled ? palette.primary : palette.ink300)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: 16, offset: pressed || !enabled ? 0 : 2)
                .offset(y: pressed && enabled ? 2 : 0)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .sensoryFeedback(.impact(weight: .medium), trigger: pressed)
        .animation(Motion.springFast, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if enabled { pressed = true } }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - Secondary link (skip)

struct SkipLink: View {
    let title: String
    let action: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.geist(size: 14, weight: 500))
                .foregroundStyle(palette.fg3)
                .padding(.vertical, Spacing.s2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen frame

/// Standard wrapper used by every question screen. Supplies top-bar,
/// centered content slot, and bottom CTA / skip. Keeps padding + spacing
/// consistent across the 25-screen flow.
struct OnboardingFrame<Content: View>: View {
    let step: OnboardingStep
    let canAdvance: Bool
    var continueTitle: String = "Continue"
    let onBack: (() -> Void)?
    let onContinue: () -> Void
    let onSkip: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(
                canGoBack: onBack != nil,
                showProgress: !step.hidesProgress,
                step: step.ordinal,
                total: OnboardingStep.total,
                onBack: { onBack?() }
            )

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, Spacing.s5)

            VStack(spacing: Spacing.s2) {
                PrimaryCTA(title: continueTitle, enabled: canAdvance, action: onContinue)
                if let onSkip {
                    SkipLink(title: "Skip", action: onSkip)
                } else {
                    Spacer().frame(height: Spacing.s6)
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.bottom, Spacing.s4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg.ignoresSafeArea())
    }
}

// MARK: - Question header

struct QuestionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            if let eyebrow {
                Text(eyebrow)
                    .eyebrow()
                    .foregroundStyle(palette.fgBrand)
            }
            Text(title)
                .font(.fraunces(size: 30, weight: 600, opsz: 100, soft: 40))
                .tracking(-0.015 * 30)
                .foregroundStyle(palette.fg1)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.geist(size: 15, weight: 400))
                    .foregroundStyle(palette.fg2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
