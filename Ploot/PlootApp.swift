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

        // Seed on main thread before the first view materializes. Idempotent:
        // only inserts when the store is empty.
        DemoData.seedIfNeeded(context: modelContainer.mainContext)
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

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                splash
            case .signedOut:
                AuthView(session: session)
                    .transition(.opacity)
            case .signedIn:
                HomeView(session: session)
                    .transition(.opacity)
            }
        }
        .animation(Motion.spring, value: session.state)
    }

    private var splash: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            Text("🧡")
                .font(.system(size: 72))
        }
    }
}
