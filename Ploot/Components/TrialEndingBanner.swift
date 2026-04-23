import SwiftUI
import StoreKit

/// In-app banner that appears on the Today screen when the user's
/// trial (or paid period) ends within the next 24 hours. Dismissible
/// per session via @State (re-appears on next app launch until the
/// entitlement state changes). Tap opens Apple's native manage-sub
/// sheet so the user can switch yearly↔monthly, cancel, or confirm
/// renewal without digging through iOS Settings.
///
/// Placed above the task list so it's the first thing the eye lands
/// on after opening the app during the critical 24-hour window.
struct TrialEndingBanner: View {
    @Bindable var subscription: SubscriptionManager
    @Environment(\.plootPalette) private var palette

    @State private var dismissedThisSession: Bool = false
    @State private var showingManage: Bool = false

    private var shouldShow: Bool {
        !dismissedThisSession &&
        subscription.isActive &&
        subscription.isWithin24HoursOfEnd
    }

    var body: some View {
        if shouldShow {
            banner
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(Motion.spring, value: shouldShow)
                .manageSubscriptionsSheet(isPresented: $showingManage)
        }
    }

    private var banner: some View {
        Button {
            showingManage = true
        } label: {
            HStack(spacing: Spacing.s3) {
                Text(subscription.isInTrial ? "⏰" : "🔁")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.geist(size: 14, weight: 700))
                        .foregroundStyle(palette.fg1)
                    Text(subhead)
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(Motion.spring) { dismissedThisSession = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.fg3)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss banner")
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s3)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(palette.clay100)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(palette.borderInk, lineWidth: 2)
            )
            .stampedShadow(radius: Radius.md, offset: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s3)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double-tap to manage your subscription")
    }

    private var headline: String {
        if subscription.isInTrial {
            return remainingCopy(prefix: "Trial ends")
        } else {
            return remainingCopy(prefix: "Renews")
        }
    }

    private var subhead: String {
        subscription.isInTrial
            ? "Keep your plan, projects, and streak. Tap to review."
            : "Your subscription renews automatically. Tap to manage."
    }

    private func remainingCopy(prefix: String) -> String {
        guard let mins = subscription.minutesUntilEnd else { return "\(prefix) soon" }
        if mins < 60 { return "\(prefix) in \(mins) min" }
        let hours = mins / 60
        if hours < 24 { return "\(prefix) in \(hours)h" }
        return "\(prefix) tomorrow"
    }
}
