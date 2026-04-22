import SwiftUI
import SwiftData
import UserNotifications

@main
struct PlootApp: App {
    private let modelContainer: ModelContainer

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
            HomeView()
        }
        .modelContainer(modelContainer)
    }
}
