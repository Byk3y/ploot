import SwiftUI
import SwiftData
import UserNotifications

@main
struct PlootApp: App {
    private let modelContainer: ModelContainer
    @State private var session = SessionManager()

    init() {
        PlootFonts.register()

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
/// into AuthView or HomeView.
private struct RootView: View {
    @Bindable var session: SessionManager
    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                splash
            case .signedOut:
                OnboardingFlow(session: session)
                    .transition(.opacity)
            case .signedIn:
                HomeView(session: session)
                    .transition(.opacity)
            }
        }
        .animation(Motion.spring, value: session.state)
        .onChange(of: session.state) { old, new in
            // Full pull on every transition into signedIn — covers first
            // sign-in, session restore on cold launch, and sign-in after
            // signing out. After the pull, open the realtime channel so
            // subsequent mutations from other devices stream in live.
            if new == .signedIn && old != .signedIn {
                Task {
                    await SyncService.shared.pullAll(context: modelContext)
                    await SyncService.shared.startRealtime(context: modelContext)
                }
            }
            // On sign-out, close realtime first so a late event can't
            // re-insert data after the wipe. Await the teardown before
            // the 300ms UI settle so the wipe can't race a stray echo.
            if new == .signedOut && old == .signedIn {
                Task {
                    await SyncService.shared.stopRealtime()
                    // Let the RootView body re-render into AuthView before we
                    // tear down the underlying data — otherwise HomeView is
                    // briefly reading @Query arrays whose models are about to
                    // be deleted, which can log "accessed deleted model" spew.
                    try? await Task.sleep(for: .milliseconds(300))
                    SyncService.shared.wipeLocal(context: modelContext)
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
