import Foundation

enum DemoData {
    static let projects: [PlootProject] = [
        PlootProject(id: "work",    name: "Work",       emoji: "💼", tileColor: .sky,     openCount: 8,  doneCount: 12),
        PlootProject(id: "home",    name: "Home",       emoji: "🏡", tileColor: .forest,  openCount: 4,  doneCount: 6),
        PlootProject(id: "side",    name: "Side quest", emoji: "🚀", tileColor: .plum,    openCount: 5,  doneCount: 2),
        PlootProject(id: "errands", name: "Errands",    emoji: "🛒", tileColor: .butter,  openCount: 3,  doneCount: 8),
        PlootProject(id: "reading", name: "Reading",    emoji: "📚", tileColor: .primary, openCount: 12, doneCount: 3),
    ]

    static let inboxProject = PlootProject(
        id: "inbox", name: "Inbox", emoji: "📮", tileColor: .inbox, openCount: 0, doneCount: 0
    )

    static func tasks() -> [PlootTask] {
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
                    Subtask(title: "Problem statement", done: true),
                    Subtask(title: "Market data + chart", done: false),
                    Subtask(title: "The funny opening slide", done: false)
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
