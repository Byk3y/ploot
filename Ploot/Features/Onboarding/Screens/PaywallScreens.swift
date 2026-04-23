import SwiftUI
import RevenueCat

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
    enum Chrome {
        /// In-flow paywall (screen 21). Progress bar, no escape.
        case onboarding
        /// Post-onboarding lockscreen. Sign-out button replaces progress
        /// so the user can't be trapped if they decide not to pay.
        case lockscreen(session: SessionManager)
    }

    let chrome: Chrome
    let onBack: (() -> Void)?
    let onPurchased: () -> Void
    var subscription: SubscriptionManager = .shared

    @Environment(\.plootPalette) private var palette
    @State private var selected: PlanSelection = .yearly

    enum PlanSelection { case yearly, monthly }

    var body: some View {
        VStack(spacing: 0) {
            topBar

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
                    enabled: !subscription.isPurchasing && (selectedPackage != nil),
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

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        switch chrome {
        case .onboarding:
            OnboardingTopBar(
                canGoBack: onBack != nil,
                showProgress: true,
                step: OnboardingStep.paywall.ordinal,
                total: OnboardingStep.total,
                onBack: { onBack?() }
            )
        case .lockscreen(let session):
            HStack {
                Spacer()
                Button("Sign out") {
                    Task { await session.signOut() }
                }
                .font(.geist(size: 14, weight: 500))
                .foregroundStyle(palette.fg3)
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s3)
            .padding(.bottom, Spacing.s4)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text(eyebrowText)
                .eyebrow()
                .foregroundStyle(palette.fgBrand)
            Text(headlineText)
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

    private var eyebrowText: String {
        switch chrome {
        case .onboarding: return "Unlock Ploot Pro"
        case .lockscreen: return justExpired ? "Just expired" : "Welcome back"
        }
    }

    private var headlineText: String {
        switch chrome {
        case .onboarding:
            return "Keep the plan you just built."
        case .lockscreen:
            return justExpired
                ? "Pick it back up — we saved your plan."
                : "Ready to continue?"
        }
    }

    /// True when the subscription flipped inactive within the last 24h.
    /// Drives warmer "just expired" lockscreen copy vs. "come back" for
    /// users who cancelled months ago.
    private var justExpired: Bool {
        guard let lastActive = subscription.lastActiveAt else { return false }
        return Date().timeIntervalSince(lastActive) < 60 * 60 * 24
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
        if let y = subscription.yearlyPackage?.storeProduct {
            return "\(y.localizedPriceString) / year"
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
        if let m = subscription.monthlyPackage?.storeProduct {
            return "\(m.localizedPriceString) / month"
        }
        return "— / month"
    }

    private var selectedPackage: Package? {
        switch selected {
        case .yearly: return subscription.yearlyPackage
        case .monthly: return subscription.monthlyPackage
        }
    }

    // MARK: - Purchase

    private func startPurchase() async {
        guard let package = selectedPackage else { return }
        let ok = await subscription.purchase(package)
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
