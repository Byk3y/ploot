import Foundation
import Observation
import StoreKit

/// Owns the subscription lifecycle.
///
/// Native StoreKit 2 (iOS 15+). Two auto-renewing products in one
/// subscription group: monthly ($3.99) and yearly ($12.99), each with
/// a 7-day free trial. We listen for `Transaction.updates` on init so
/// external events (refund, promo, family share) also land here.
///
/// `isActive` is the single source of truth for app gating. RootView
/// checks it before rendering HomeView; if false the app shows the
/// paywall lockscreen.
///
/// NOTE: Server-side receipt validation is not implemented here.
/// Phase 2 of monetization can either (a) swap this for RevenueCat,
/// which handles server validation + webhooks for free under $2.5k MRR,
/// or (b) add a Supabase edge function that calls Apple's verify API.
@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // MARK: - Product IDs
    //
    // Must match the productIDs configured in App Store Connect AND in
    // the local Products.storekit config file used for sim testing. The
    // order matters for UI: yearly is pre-selected on the paywall, so
    // keeping yearly first in `productIDs` is deliberate.
    static let yearlyID = "ploot.pro.yearly"
    static let monthlyID = "ploot.pro.monthly"
    static let productIDs: [String] = [yearlyID, monthlyID]

    // MARK: - Observable state

    /// Loaded from StoreKit; nil while the initial fetch is in flight.
    var products: [Product] = []

    /// True if the user has an active entitlement to any product in
    /// `productIDs`. Includes trial periods.
    var isActive: Bool = false

    /// When the current period (trial or regular) ends, per Apple. Used
    /// by TrialBanner + ReminderService to warn before lockout. Nil
    /// when there's no active entitlement.
    var currentPeriodEndsAt: Date? = nil

    /// True when the active entitlement is still in the free-trial
    /// introductory-offer period. Drives copy shifts in the banner
    /// ("trial ends" vs. "renews") and the last-chance push.
    var isInTrial: Bool = false

    /// When the subscription went from active → inactive, if the flip
    /// happened within the current launch. Lockscreen reads this to
    /// pick warmer "just expired" copy vs. "come back" copy.
    var lastActiveAt: Date? = nil

    /// Set while a purchase sheet is in-flight so the UI can disable
    /// both plan buttons + show a spinner.
    var isPurchasing: Bool = false

    /// Human-readable error surfaced to the user after a failed purchase
    /// or restore. Cleared on the next purchase attempt.
    var lastError: String? = nil

    // MARK: - Init + transaction listener

    private var transactionListener: Task<Void, Never>? = nil

    private init() {
        transactionListener = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(update: update)
            }
        }
    }

    // Deinit is intentionally omitted — this is a shared singleton so
    // the app will be gone before it would run anyway, and a @MainActor
    // property can't be touched from nonisolated deinit context.

    // MARK: - Product loading

    /// Pulls the Product objects for our IDs. Safe to call repeatedly —
    /// the UI calls this on paywall appearance so a flaky first-launch
    /// network can recover on re-visit.
    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            // Preserve our preferred display order (yearly first).
            self.products = Self.productIDs.compactMap { id in
                loaded.first(where: { $0.id == id })
            }
        } catch {
            #if DEBUG
            print("[Subscription] Product load failed: \(error)")
            #endif
        }
        await refreshEntitlements()
    }

    /// Convenience lookups for the paywall UI.
    var yearlyProduct: Product? { products.first(where: { $0.id == Self.yearlyID }) }
    var monthlyProduct: Product? { products.first(where: { $0.id == Self.monthlyID }) }

    // MARK: - Entitlements

    /// Walks the current entitlements and flips `isActive` +
    /// populates `currentPeriodEndsAt` / `isInTrial`. Called on launch
    /// and after every purchase / transaction update.
    ///
    /// Also schedules the "trial ends soon" local notification and
    /// persists lastActiveAt so the lockscreen can render warmer copy
    /// right after expiration.
    func refreshEntitlements() async {
        var active = false
        var endDate: Date? = nil
        var inTrial = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
                endDate = transaction.expirationDate
                // StoreKit 2 reports the introductory trial via offerType.
                // `.introductory` includes free trials and pay-upfront intro
                // offers; we only configure free-trial introductory offers
                // in App Store Connect + Products.storekit, so this is
                // effectively "is the user currently in the 7-day trial?".
                // (transaction.offer was added in iOS 17.2 — we target 17.0.)
                if transaction.offerType == .introductory {
                    inTrial = true
                }
                break
            }
        }

        // Capture the flip to inactive for lockscreen copy.
        if self.isActive && !active {
            self.lastActiveAt = Date()
        }

        self.isActive = active
        self.currentPeriodEndsAt = endDate
        self.isInTrial = inTrial

        // Reschedule (or cancel) the trial-end push whenever the
        // entitlement state changes.
        ReminderService.shared.scheduleTrialEndingReminder(
            at: endDate,
            isInTrial: inTrial
        )
    }

    /// Minutes remaining until the current period ends. Nil if not
    /// active or the date is in the past.
    var minutesUntilEnd: Int? {
        guard let end = currentPeriodEndsAt else { return nil }
        let delta = end.timeIntervalSinceNow
        guard delta > 0 else { return nil }
        return Int(delta / 60)
    }

    /// True when we're within 24 hours of the period ending. Drives
    /// the Today-screen banner visibility.
    var isWithin24HoursOfEnd: Bool {
        guard let mins = minutesUntilEnd else { return false }
        return mins <= 60 * 24
    }

    // MARK: - Purchase

    /// Triggers the StoreKit purchase sheet for the given product.
    /// Resolves true on a verified success (including trial start).
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    return true
                case .unverified(_, let error):
                    lastError = "Couldn't verify purchase: \(error.localizedDescription)"
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                // Ask-to-buy / SCA pending — treat as not-yet-active.
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = (error as NSError).localizedDescription
            return false
        }
    }

    // MARK: - Restore

    /// Triggers Apple's restore flow — replays the receipt against any
    /// prior purchases on this Apple ID. Useful if the user re-installs.
    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = (error as NSError).localizedDescription
        }
    }

    // MARK: - Transaction updates

    private func handle(update: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = update {
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    // MARK: - Display helpers

    /// Formatted "FREE for 7 days, then $X/Y" line shown under each plan.
    /// Falls back to a stub string if the product isn't loaded yet so the
    /// UI doesn't look broken on first paint.
    func headlinePrice(for product: Product?) -> String {
        guard let product else { return "—" }
        return product.displayPrice
    }

    /// "Save 73%" badge math — computes yearly savings vs. 12x monthly.
    /// Returns nil if either product isn't loaded.
    var yearlySavingsPercent: Int? {
        guard let m = monthlyProduct, let y = yearlyProduct else { return nil }
        let monthly12 = m.price * 12
        guard monthly12 > 0 else { return nil }
        let savings = (monthly12 - y.price) / monthly12
        return Int((NSDecimalNumber(decimal: savings).doubleValue * 100).rounded())
    }

    /// Per-month equivalent of the yearly plan, formatted for the badge.
    var yearlyPerMonth: String? {
        guard let y = yearlyProduct else { return nil }
        let perMonth = y.price / 12
        return y.priceFormatStyle.format(perMonth)
    }
}
