import Foundation
import SwiftData

/// First-launch seed. Checks whether the model store already has tasks or
/// projects and only inserts the demo set if both are empty — safe to call
/// on every launch.
enum DemoData {

    /// The Inbox project isn't persisted; it's used as a placeholder in the
    /// QuickAdd project picker when the user hasn't chosen one yet.
    static let inboxProject = PlootProject(
        id: "inbox",
        name: "Inbox",
        emoji: "📮",
        tileColor: .inbox,
        order: 0
    )

    static func seedIfNeeded(context: ModelContext) {
        let taskCount = (try? context.fetchCount(FetchDescriptor<PlootTask>())) ?? 0
        let projectCount = (try? context.fetchCount(FetchDescriptor<PlootProject>())) ?? 0
        guard taskCount == 0 && projectCount == 0 else { return }

        for project in seededProjects() {
            context.insert(project)
        }
        for task in seededTasks() {
            context.insert(task)
        }

        try? context.save()
    }

    // MARK: - Seed sets

    private static func seededProjects() -> [PlootProject] {
        [
            PlootProject(id: "work",    name: "Work",       emoji: "💼", tileColor: .sky,     order: 1),
            PlootProject(id: "home",    name: "Home",       emoji: "🏡", tileColor: .forest,  order: 2),
            PlootProject(id: "side",    name: "Side quest", emoji: "🚀", tileColor: .plum,    order: 3),
            PlootProject(id: "errands", name: "Errands",    emoji: "🛒", tileColor: .butter,  order: 4),
            PlootProject(id: "reading", name: "Reading",    emoji: "📚", tileColor: .primary, order: 5),
        ]
    }

    private static func seededTasks() -> [PlootTask] {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: startOfToday)
        let todayAt2PM = cal.date(bySettingHour: 14, minute: 0, second: 0, of: startOfToday)
        let in3Days = cal.date(byAdding: .day, value: 3, to: startOfToday)
        let in4Days = cal.date(byAdding: .day, value: 4, to: startOfToday)
        let in5Days = cal.date(byAdding: .day, value: 5, to: startOfToday)

        // Some "done" tasks completed at staggered points over the last 4
        // days so the weekly chart and streak look alive on first launch.
        let completedToday = cal.date(bySettingHour: 9, minute: 15, second: 0, of: startOfToday)
        let completed1DayAgo = cal.date(byAdding: .hour, value: -20, to: now)
        let completed2DaysAgo = cal.date(byAdding: .day, value: -2, to: now)

        return [
            taskWithCompletion(
                PlootTask(
                    title: "Reply to the one email I've been avoiding",
                    note: "It's the one from accounting. You know the one.",
                    dueDate: todayAt2PM,
                    projectId: "work",
                    priority: .urgent,
                    tags: ["deep work"]
                ),
                completedAt: nil
            ),
            PlootTask(
                title: "Buy more oat milk (again)",
                dueDate: startOfToday,
                duration: "15 min",
                projectId: "errands"
            ),
            PlootTask(
                title: "Outline the Q3 pitch deck",
                dueDate: startOfToday,
                duration: "45 min",
                projectId: "work",
                priority: .high,
                subtasks: [
                    Subtask(title: "Problem statement", done: true, order: 0),
                    Subtask(title: "Market data + chart", done: false, order: 1),
                    Subtask(title: "The funny opening slide", done: false, order: 2)
                ]
            ),
            taskWithCompletion(
                PlootTask(
                    title: "Go for a walk (a real one)",
                    dueDate: startOfToday,
                    projectId: "home",
                    done: true
                ),
                completedAt: completedToday
            ),
            PlootTask(
                title: "Call mom",
                dueDate: yesterday,
                projectId: "home",
                priority: .medium
            ),
            PlootTask(
                title: "Water the mysterious plant",
                dueDate: in3Days,
                projectId: "home"
            ),
            PlootTask(
                title: "Ship v2 of the thing",
                dueDate: in4Days,
                projectId: "work",
                priority: .high,
                tags: ["sprint"]
            ),
            PlootTask(
                title: "Pretend to understand the new CSS spec",
                dueDate: in5Days,
                projectId: "side"
            ),
            taskWithCompletion(
                PlootTask(
                    title: "Morning stretch",
                    projectId: "home",
                    done: true
                ),
                completedAt: completed1DayAgo
            ),
            taskWithCompletion(
                PlootTask(
                    title: "Review PR #1247",
                    projectId: "work",
                    done: true
                ),
                completedAt: completed2DaysAgo
            ),
        ]
    }

    /// Overrides the auto-assigned completedAt (now) on seeded done tasks so
    /// the streak + weekly chart have plausible history on first launch.
    private static func taskWithCompletion(_ task: PlootTask, completedAt: Date?) -> PlootTask {
        if let completedAt {
            task.completedAt = completedAt
        }
        return task
    }
}
