import Foundation
import Observation
import RevenueCat

/// Owns the subscription lifecycle via RevenueCat.
///
/// RevenueCat handles: product fetching, trial/intro-offer detection,
/// receipt validation, cross-device entitlement state, and (once the
/// webhook → Supabase edge function lands) server-side source-of-truth
/// for `subscription_status`.
///
/// Public API is stable: callers see `isActive`, `yearlyPackage`,
/// `monthlyPackage`, `purchase(_:)`, `restore()`, etc. Units of purchase
/// are RevenueCat `Package` values (not raw StoreKit `Product`s).
///
/// `isActive` is the single source of truth for app gating. RootView
/// checks it before rendering HomeView; if false the app shows the
/// paywall lockscreen.
@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // MARK: - Identifiers
    //
    // Entitlement id is the RC-side "pro" identity. Package ids follow
    // the RC convention ($rc_annual, $rc_monthly) — set in the default
    // offering when we configured the project.

    static let entitlementID = "pro"
    static let yearlyPackageID = "$rc_annual"
    static let monthlyPackageID = "$rc_monthly"

    // MARK: - Observable state

    /// Loaded from RevenueCat. Nil while the initial fetch is in flight
    /// or when there's no current offering configured on the dashboard.
    var offerings: Offerings? = nil

    /// Latest customer info snapshot. Driver for `isActive` +
    /// `currentPeriodEndsAt` + `isInTrial`. Populated by the
    /// `customerInfoStream` listener on init and on every explicit
    /// refresh / purchase / restore.
    var customerInfo: CustomerInfo? = nil

    /// True if the user has the `pro` entitlement active (includes trial).
    var isActive: Bool = false

    /// When the current period (trial or regular) ends, per RC. Used
    /// by TrialEndingBanner + ReminderService to warn before lockout.
    var currentPeriodEndsAt: Date? = nil

    /// True when the active entitlement is still in the free-trial
    /// introductory-offer period.
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

    // MARK: - Init + customerInfo listener

    private var customerInfoTask: Task<Void, Never>? = nil

    private init() {
        // RC pushes updates here on: purchase, restore, refund, promo,
        // family share, trial expiration, etc. We stay subscribed for
        // the lifetime of the app (singleton).
        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard let self else { return }
                self.apply(customerInfo: info)
            }
        }
    }

    // Deinit is intentionally omitted — singleton, process-lifetime.

    // MARK: - Offerings + packages

    /// Pulls the current offering from RevenueCat. Safe to call
    /// repeatedly — the UI calls this on paywall appearance so a flaky
    /// first-launch network can recover on re-visit.
    func loadProducts() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
        } catch {
            log("offerings fetch failed: \(error)")
        }
        await refreshEntitlements()
    }

    /// Convenience lookups for the paywall UI. Nil until `loadProducts`
    /// completes successfully.
    var yearlyPackage: Package? {
        offerings?.current?.availablePackages.first { $0.identifier == Self.yearlyPackageID }
    }
    var monthlyPackage: Package? {
        offerings?.current?.availablePackages.first { $0.identifier == Self.monthlyPackageID }
    }

    // MARK: - Entitlements

    /// Force a customer-info refresh from RC. Usually not needed in
    /// practice — `customerInfoStream` already pushes updates — but
    /// exposed for app-foreground reconciliation.
    func refreshEntitlements() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(customerInfo: info)
        } catch {
            log("customerInfo fetch failed: \(error)")
        }
    }

    private func apply(customerInfo info: CustomerInfo) {
        self.customerInfo = info
        let pro = info.entitlements[Self.entitlementID]
        let active = pro?.isActive == true
        let endDate = pro?.expirationDate
        let inTrial = pro?.periodType == .trial

        // Capture the flip to inactive for lockscreen "just expired" copy.
        if self.isActive && !active {
            self.lastActiveAt = Date()
        }

        self.isActive = active
        self.currentPeriodEndsAt = endDate
        self.isInTrial = inTrial

        // Reschedule (or cancel) the T-2h trial-end push whenever the
        // entitlement state changes. RC doesn't do local scheduling for
        // us — this is our "last chance" reinforcement.
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

    /// Triggers the RevenueCat purchase flow (which wraps StoreKit).
    /// Resolves true on successful purchase (including trial start).
    /// User-cancel is `false` with no error surfaced.
    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            apply(customerInfo: result.customerInfo)
            return result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            lastError = (error as NSError).localizedDescription
            return false
        }
    }

    // MARK: - Restore

    /// Triggers Apple's restore flow via RevenueCat. Useful if the
    /// user re-installs, switches devices, or switches Apple IDs.
    func restore() async {
        lastError = nil
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
        } catch {
            lastError = (error as NSError).localizedDescription
        }
    }

    // MARK: - User identity (Supabase user ↔ RC app user)

    /// Alias the current anonymous RC user to the authenticated Supabase
    /// user id. Called from SessionManager right after SIWA succeeds.
    ///
    /// RC's "anonymous → identified" pattern: the paywall purchase on
    /// screen 21 creates an $RCAnonymousID-prefixed RC user. Once we
    /// know the real user, `logIn` merges the purchase onto them so
    /// the entitlement survives sign-out + fresh install on other
    /// devices.
    func identify(userId: String) async {
        do {
            let result = try await Purchases.shared.logIn(userId)
            apply(customerInfo: result.customerInfo)
        } catch {
            log("logIn failed: \(error)")
        }
    }

    /// Reset to an anonymous RC user. Called on sign-out so the next
    /// user of this device starts with a clean slate.
    func resetUser() async {
        do {
            let info = try await Purchases.shared.logOut()
            apply(customerInfo: info)
        } catch {
            log("logOut failed: \(error)")
        }
    }

    // MARK: - Display helpers

    /// "Save 73%" badge math — computes yearly savings vs. 12x monthly.
    /// Returns nil if either package isn't loaded.
    var yearlySavingsPercent: Int? {
        guard let m = monthlyPackage?.storeProduct.price,
              let y = yearlyPackage?.storeProduct.price else { return nil }
        let monthly12 = m * 12
        guard monthly12 > 0 else { return nil }
        let savings = (monthly12 - y) / monthly12
        return Int((NSDecimalNumber(decimal: savings).doubleValue * 100).rounded())
    }

    /// Per-month equivalent of the yearly plan, formatted for the badge.
    var yearlyPerMonth: String? {
        guard let yp = yearlyPackage?.storeProduct else { return nil }
        let perMonth = yp.price / 12
        let perMonthNS = NSDecimalNumber(decimal: perMonth)
        if let formatter = yp.priceFormatter {
            return formatter.string(from: perMonthNS)
        }
        return String(format: "%.2f", perMonthNS.doubleValue)
    }

    // MARK: - Logging

    private func log(_ msg: String) {
        #if DEBUG
        print("[Subscription] \(msg)")
        #endif
    }

    // MARK: - Dev bypass

    #if DEBUG
    /// Flip `isActive` true without going through RC. Lets the owner
    /// walk past the paywall (screen 21) during dev before App Store
    /// Connect + RC In-App Purchase Key are configured. Simulates a
    /// 7-day trial so the TrialEndingBanner + lockscreen paths are
    /// still exercisable. Stripped from release builds.
    func debugBypassPaywall() {
        let end = Date().addingTimeInterval(60 * 60 * 24 * 7)
        self.isActive = true
        self.isInTrial = true
        self.currentPeriodEndsAt = end
        ReminderService.shared.scheduleTrialEndingReminder(
            at: end,
            isInTrial: true
        )
    }
    #endif
}
