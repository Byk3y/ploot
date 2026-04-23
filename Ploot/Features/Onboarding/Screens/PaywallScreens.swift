import SwiftUI
import StoreKit

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

// MARK: - Screen 21 · Paywall

struct PaywallScreen: View {
    let onBack: (() -> Void)?
    let onPurchased: () -> Void
    var subscription: SubscriptionManager = .shared

    @Environment(\.plootPalette) private var palette
    @State private var selected: PlanSelection = .yearly

    enum PlanSelection { case yearly, monthly }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(
                canGoBack: onBack != nil,
                showProgress: true,
                step: OnboardingStep.paywall.ordinal,
                total: OnboardingStep.total,
                onBack: { onBack?() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    header
                    planCards
                    if let err = subscription.lastError {
                        Text(err)
                            .font(.geist(size: 13, weight: 500))
                            .foregroundStyle(palette.danger)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.bottom, Spacing.s4)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: Spacing.s3) {
                PrimaryCTA(
                    title: subscription.isPurchasing ? "…" : "Start 7-day free trial",
                    enabled: !subscription.isPurchasing && (selectedProduct != nil),
                    action: { Task { await startPurchase() } }
                )

                HStack(spacing: Spacing.s4) {
                    Button("Restore purchase") {
                        Task { await subscription.restore() }
                    }
                    .font(.geist(size: 13, weight: 500))
                    .foregroundStyle(palette.fg3)
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.bottom, Spacing.s4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg.ignoresSafeArea())
        .task {
            await subscription.loadProducts()
        }
        .onChange(of: subscription.isActive) { _, active in
            if active { onPurchased() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Unlock Ploot Pro")
                .eyebrow()
                .foregroundStyle(palette.fgBrand)
            Text("Keep the plan you just built.")
                .font(.fraunces(size: 30, weight: 600, opsz: 100, soft: 40))
                .tracking(-0.015 * 30)
                .foregroundStyle(palette.fg1)
                .fixedSize(horizontal: false, vertical: true)
            Text("Seven days free. Cancel anytime.")
                .font(.geist(size: 15, weight: 400))
                .foregroundStyle(palette.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plan cards

    private var planCards: some View {
        VStack(spacing: Spacing.s3) {
            PlanCard(
                title: "Yearly",
                priceLine: yearlyPriceLine,
                subline: yearlySubline,
                badge: yearlyBadge,
                ribbon: "MOST POPULAR",
                selected: selected == .yearly,
                action: { selected = .yearly }
            )
            PlanCard(
                title: "Monthly",
                priceLine: monthlyPriceLine,
                subline: "Billed monthly after 7-day trial.",
                badge: nil,
                ribbon: nil,
                selected: selected == .monthly,
                action: { selected = .monthly }
            )
        }
    }

    private var yearlyPriceLine: String {
        if let y = subscription.yearlyProduct {
            return "\(y.displayPrice) / year"
        }
        return "— / year"
    }

    private var yearlySubline: String {
        if let perMonth = subscription.yearlyPerMonth {
            return "\(perMonth)/mo — billed yearly after 7-day trial."
        }
        return "Billed yearly after 7-day trial."
    }

    private var yearlyBadge: String? {
        if let pct = subscription.yearlySavingsPercent, pct > 0 {
            return "Save \(pct)%"
        }
        return nil
    }

    private var monthlyPriceLine: String {
        if let m = subscription.monthlyProduct {
            return "\(m.displayPrice) / month"
        }
        return "— / month"
    }

    private var selectedProduct: Product? {
        switch selected {
        case .yearly: return subscription.yearlyProduct
        case .monthly: return subscription.monthlyProduct
        }
    }

    // MARK: - Purchase

    private func startPurchase() async {
        guard let product = selectedProduct else { return }
        let ok = await subscription.purchase(product)
        if ok { onPurchased() }
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let title: String
    let priceLine: String
    let subline: String
    let badge: String?
    let ribbon: String?
    let selected: Bool
    let action: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                HStack(alignment: .center, spacing: Spacing.s3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.geist(size: 14, weight: 600))
                            .foregroundStyle(selected ? palette.onPrimary.opacity(0.75) : palette.fg3)
                        Text(priceLine)
                            .font(.fraunces(size: 24, weight: 600, opsz: 72, soft: 40))
                            .foregroundStyle(selected ? palette.onPrimary : palette.fg1)
                    }
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.geist(size: 11, weight: 700))
                            .foregroundStyle(selected ? palette.onPrimary : palette.fgBrand)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(selected ? palette.onPrimary.opacity(0.15) : palette.clay100)
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    selected ? palette.onPrimary.opacity(0.3) : palette.clay300,
                                    lineWidth: 1.5
                                )
                            )
                    }
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(selected ? palette.onPrimary : palette.fg3)
                }

                Text(subline)
                    .font(.geist(size: 13, weight: 400))
                    .foregroundStyle(selected ? palette.onPrimary.opacity(0.85) : palette.fg3)
                    .lineSpacing(2)
            }
            .padding(Spacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(selected ? palette.primary : palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(palette.borderInk, lineWidth: 2)
            )
            .stampedShadow(radius: Radius.lg, offset: 2)
            .overlay(alignment: .topTrailing) {
                if let ribbon {
                    Text(ribbon)
                        .font(.geist(size: 10, weight: 700))
                        .foregroundStyle(palette.onPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(palette.fg1)
                        )
                        .offset(x: -12, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
        .animation(Motion.springFast, value: selected)
    }
}
