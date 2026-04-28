import SwiftUI
import SwiftData
import UserNotifications
import RevenueCat
import Lottie

@main
struct PlootApp: App {
    private let modelContainer: ModelContainer
    @State private var session = SessionManager()

    init() {
        PlootFonts.register()

        // Use the Core Animation renderer so the streak Lottie doesn't
        // flash a blank frame when a tab containing it remounts. Core
        // Animation also lifts animation playback off the main thread.
        LottieConfiguration.shared.renderingEngine = .coreAnimation
        FireLottieView.preload()

        // RevenueCat must be configured before any SubscriptionManager
        // work touches Purchases.shared. Log level is verbose only in
        // DEBUG so we see offerings / purchase events during dev.
        #if DEBUG
        Purchases.logLevel = .info
        #endif
        Purchases.configure(withAPIKey: Secrets.revenueCatPublicKey)

        // Register the foreground-banner delegate before any notification
        // would have the chance to fire. Must be set before any scheduled
        // reminder lands while the user is actively using the app.
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared

        do {
            self.modelContainer = try ModelContainer(
                for: PlootTask.self, Subtask.self, PlootProject.self
            )
        } catch {
            fatalError("Failed to initialize Ploot model container: \(error)")
        }

        // No seed. New users land in the empty-state UIs ("Nothing on the
        // list. Suspicious." / "No projects yet."); signed-in users get
        // their own data via SyncService.pullAll on the first signedIn
        // transition.
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
        }
        .modelContainer(modelContainer)
    }
}

/// Top-level auth gate. While the SDK restores the Keychain session on
/// launch we show a brief cream splash; once the state settles we route
/// into OnboardingFlow or HomeView.
///
/// OnboardingFlow renders whenever `onboardingCompleted` is false,
/// regardless of whether the user is signedOut or signedIn. That lets
/// the post-purchase SIWA (screen 22) flip session state to .signedIn
/// without kicking the user out of the quiz mid-flow — they keep
/// advancing through screens 23–24 until LandScreen sets the flag.
private struct RootView: View {
    @Bindable var session: SessionManager
    @Bindable var subscription = SubscriptionManager.shared
    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("ploot.onboardingCompleted") private var onboardingCompleted: Bool = false

    var body: some View {
        Group {
            if session.state == .loading {
                splash
            } else if session.state == .signedIn && onboardingCompleted && subscription.isActive {
                HomeView(session: session)
                    .transition(.opacity)
            } else if session.state == .signedIn && onboardingCompleted && !subscription.isActive {
                // Trial ended / subscription cancelled / refund. Lockscreen
                // paywall — same plan cards as onboarding screen 21, but
                // with a sign-out escape so the user isn't trapped.
                PaywallScreen(
                    chrome: .lockscreen(session: session),
                    onBack: nil,
                    onPurchased: {}
                )
                .transition(.opacity)
            } else {
                // .signedOut OR (.signedIn && !onboardingCompleted)
                // Same structural position so OnboardingFlow's @State
                // survives the mid-flow signIn transition.
                OnboardingFlow(session: session, onboardingCompleted: $onboardingCompleted)
                    .transition(.opacity)
            }
        }
        .animation(Motion.spring, value: session.state)
        .animation(Motion.spring, value: onboardingCompleted)
        .animation(Motion.spring, value: subscription.isActive)
        .task {
            // Prime subscription state on cold launch so the gate resolves
            // correctly before the user notices a flicker.
            await subscription.loadProducts()
        }
        .onChange(of: session.state) { old, new in
            // Full pull on every transition into signedIn — covers first
            // sign-in, session restore on cold launch, and sign-in after
            // signing out. After the pull, open the realtime channel so
            // subsequent mutations from other devices stream in live.
            //
            // The returning-user check (hasCompletedOnboardingRemotely)
            // lives inside OnboardingFlow itself — doing it here would
            // race the new-user path's pushOnboarding write and could
            // flip onboardingCompleted early, skipping screens 23–24.
            if new == .signedIn && old != .signedIn {
                Task {
                    await SyncService.shared.pullAll(context: modelContext)
                    await SyncService.shared.startRealtime(context: modelContext)
                }
            }
            // On sign-out, close realtime first so a late event can't
            // re-insert data after the wipe. Await the teardown before
            // the 300ms UI settle so the wipe can't race a stray echo.
            // Reset the onboarding flag so the next user of this device
            // starts at screen 1.
            if new == .signedOut && old == .signedIn {
                Task {
                    await SyncService.shared.stopRealtime()
                    try? await Task.sleep(for: .milliseconds(300))
                    SyncService.shared.wipeLocal(context: modelContext)
                    ReminderService.shared.cancelDailyCheckin()
                    UserPrefs.wipe()
                    onboardingCompleted = false
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Foreground pulls catch changes made on other devices while
            // the app was suspended (websocket was torn down by iOS) —
            // then re-open realtime so the foreground stays live.
            if phase == .active && session.state == .signedIn {
                Task {
                    await SyncService.shared.pullAll(context: modelContext)
                    await SyncService.shared.startRealtime(context: modelContext)
                }
                // Daily auto-roll sweep — moves yesterday's incomplete
                // dated tasks to today when the user has opted in. Runs
                // at most once per local day; the service's own
                // bookkeeping handles the dedupe.
                AutoRollService.sweepIfEnabled(context: modelContext)
            }
        }
    }

    private var splash: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            Text("🧡")
                .font(.system(size: 72))
        }
    }
}
