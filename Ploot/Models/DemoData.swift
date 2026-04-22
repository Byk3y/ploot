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
        [
            PlootTask(
                title: "Reply to the one email I've been avoiding",
                note: "It's the one from accounting. You know the one.",
                due: "Today, 2:00 PM",
                projectId: "work",
                priority: .urgent,
                tags: ["deep work"],
                section: .today
            ),
            PlootTask(
                title: "Buy more oat milk (again)",
                due: "Today",
                duration: "15 min",
                projectId: "errands",
                section: .today
            ),
            PlootTask(
                title: "Outline the Q3 pitch deck",
                due: "Today",
                duration: "45 min",
                projectId: "work",
                priority: .high,
                subtasks: [
                    Subtask(title: "Problem statement", done: true, order: 0),
                    Subtask(title: "Market data + chart", done: false, order: 1),
                    Subtask(title: "The funny opening slide", done: false, order: 2)
                ],
                section: .today
            ),
            PlootTask(
                title: "Go for a walk (a real one)",
                due: "Today",
                projectId: "home",
                done: true,
                section: .today
            ),
            PlootTask(
                title: "Call mom",
                due: "Yesterday",
                projectId: "home",
                priority: .medium,
                section: .overdue,
                overdue: true
            ),
            PlootTask(
                title: "Water the mysterious plant",
                due: "Thu",
                projectId: "home",
                section: .later
            ),
            PlootTask(
                title: "Ship v2 of the thing",
                due: "Fri",
                projectId: "work",
                priority: .high,
                tags: ["sprint"],
                section: .later
            ),
            PlootTask(
                title: "Pretend to understand the new CSS spec",
                due: "Sat",
                projectId: "side",
                section: .later
            ),
            PlootTask(
                title: "Morning stretch",
                projectId: "home",
                done: true,
                section: .today
            ),
            PlootTask(
                title: "Review PR #1247",
                projectId: "work",
                done: true,
                section: .today
            ),
        ]
    }
}
