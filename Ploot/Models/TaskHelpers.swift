import Foundation

/// Derived statistics over a live tasks array. Phase 3a keeps these as pure
/// functions over `[PlootTask]` — each view passes in its @Query result and
/// receives the computed value. Phase 3b will swap the heuristics (streak,
/// weekly counts) for real date-aware math once `due` is a Date.
enum TaskHelpers {

    // MARK: - Section filtering

    static func tasks(in section: TaskSection, from tasks: [PlootTask]) -> [PlootTask] {
        tasks.filter { $0.section == section }
    }

    static func doneTasks(from tasks: [PlootTask]) -> [PlootTask] {
        tasks.filter { $0.done }
    }

    // MARK: - Project lookup

    static func project(id: String?, from projects: [PlootProject]) -> PlootProject? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    // MARK: - Stats (placeholders until Phase 3b)

    /// Consecutive-day completion streak. Placeholder — returns 7 while the
    /// data model lacks real completion dates per day.
    static func streak(from tasks: [PlootTask]) -> Int { 7 }

    /// Seven-day completion histogram, Mon → Sun. Placeholder shape; the
    /// trailing bar shows the current `done` count so checking things off in
    /// the UI at least animates the last bar during Phase 3a.
    static func weeklyCounts(from tasks: [PlootTask]) -> [Int] {
        [3, 5, 2, 7, 4, 6, max(1, doneTasks(from: tasks).count)]
    }

    // MARK: - Today subtitle

    static func todaySubtitle(from tasks: [PlootTask]) -> String {
        let today = self.tasks(in: .today, from: tasks)
        let total = today.count
        let done = today.filter { $0.done }.count
        if total == 0 {
            return "Nothing on the list. Suspicious."
        }
        return "\(done) of \(total) crushed. Keep going."
    }
}
