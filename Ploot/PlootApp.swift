import SwiftUI
import SwiftData

@main
struct PlootApp: App {
    private let modelContainer: ModelContainer

    init() {
        PlootFonts.register()

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
