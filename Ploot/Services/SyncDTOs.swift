import Foundation

// MARK: - TaskDTO

/// On-the-wire shape of public.tasks. snake_case property names match the
/// column names exactly so the default JSONDecoder handles the mapping
/// without extra ceremony.
struct TaskDTO: Codable, Hashable {
    var id: UUID
    var owner_id: UUID
    var title: String
    var note: String?
    var due: String?
    var due_date: Date?
    var duration: String?
    var project_id: String?
    var priority: String
    var tags: [String]
    var done: Bool
    var section: String
    var overdue: Bool
    var repeats: String?
    var remind_me: Bool?
    var created_at: Date
    var completed_at: Date?
    var updated_at: Date?
    var deleted_at: Date?

    /// Snapshot the SwiftData model into a row suitable for upsert.
    init(from task: PlootTask, ownerId: UUID) {
        self.id = task.id
        self.owner_id = ownerId
        self.title = task.title
        self.note = task.note
        self.due = task.due
        self.due_date = task.dueDate
        self.duration = task.duration
        self.project_id = task.projectId
        self.priority = task.priority.rawValue
        self.tags = task.tags
        self.done = task.done
        self.section = task.section.rawValue
        self.overdue = task.overdue
        self.repeats = task.repeats
        self.remind_me = task.remindMe
        self.created_at = task.createdAt
        self.completed_at = task.completedAt
        self.updated_at = task.updatedAt ?? Date()
        self.deleted_at = task.deletedAt
    }

    /// Mutate a local model so it matches this remote row. Used when the
    /// remote wins a last-write-wins resolution.
    func apply(to task: PlootTask) {
        task.title = title
        task.note = note
        task.due = due
        task.dueDate = due_date
        task.duration = duration
        task.projectId = project_id
        task.priority = Priority(rawValue: priority) ?? .normal
        task.tags = tags
        task.done = done
        task.section = TaskSection(rawValue: section) ?? .today
        task.overdue = overdue
        task.repeats = repeats
        task.remindMe = remind_me
        task.createdAt = created_at
        task.completedAt = completed_at
        task.updatedAt = updated_at
        task.deletedAt = deleted_at
    }

    /// Build a fresh SwiftData model from this remote row. Subtasks are
    /// attached separately by SyncService.
    func makeLocal() -> PlootTask {
        let t = PlootTask(
            title: title,
            note: note,
            due: due,
            dueDate: due_date,
            duration: duration,
            projectId: project_id,
            priority: Priority(rawValue: priority) ?? .normal,
            tags: tags,
            subtasks: [],
            done: done,
            section: TaskSection(rawValue: section) ?? .today,
            overdue: overdue,
            repeats: repeats,
            remindMe: remind_me ?? false
        )
        t.id = id
        t.createdAt = created_at
        t.completedAt = completed_at
        t.updatedAt = updated_at
        t.deletedAt = deleted_at
        return t
    }
}

// MARK: - SubtaskDTO

struct SubtaskDTO: Codable, Hashable {
    var id: UUID
    var task_id: UUID
    var owner_id: UUID
    var title: String
    var done: Bool
    var sort_order: Int
    var updated_at: Date?
    var deleted_at: Date?
    // created_at is intentionally omitted: Postgres DEFAULT now() handles
    // fresh inserts, and on updates we don't want to stomp the server
    // value. We don't render Subtask.createdAt anywhere.

    init(from sub: Subtask, parentId: UUID, ownerId: UUID) {
        self.id = sub.id
        self.task_id = parentId
        self.owner_id = ownerId
        self.title = sub.title
        self.done = sub.done
        self.sort_order = sub.order
        self.updated_at = sub.updatedAt ?? Date()
        self.deleted_at = sub.deletedAt
    }

    func apply(to sub: Subtask) {
        sub.title = title
        sub.done = done
        sub.order = sort_order
        sub.updatedAt = updated_at
        sub.deletedAt = deleted_at
    }

    func makeLocal() -> Subtask {
        let s = Subtask(title: title, done: done, order: sort_order)
        s.id = id
        s.updatedAt = updated_at
        s.deletedAt = deleted_at
        return s
    }
}

// MARK: - ProjectDTO

struct ProjectDTO: Codable, Hashable {
    var id: String
    var owner_id: UUID
    var name: String
    var emoji: String
    var tile_color: String
    var sort_order: Int
    var updated_at: Date?
    var deleted_at: Date?
    // created_at omitted — Postgres DEFAULT now() on insert, preserved on
    // update.

    init(from project: PlootProject, ownerId: UUID) {
        self.id = project.id
        self.owner_id = ownerId
        self.name = project.name
        self.emoji = project.emoji
        self.tile_color = project.tileColor.rawValue
        self.sort_order = project.order
        self.updated_at = project.updatedAt ?? Date()
        self.deleted_at = project.deletedAt
    }

    func apply(to project: PlootProject) {
        project.name = name
        project.emoji = emoji
        project.tileColor = ProjectTileColor(rawValue: tile_color) ?? .inbox
        project.order = sort_order
        project.updatedAt = updated_at
        project.deletedAt = deleted_at
    }

    func makeLocal() -> PlootProject {
        let p = PlootProject(
            id: id,
            name: name,
            emoji: emoji,
            tileColor: ProjectTileColor(rawValue: tile_color) ?? .inbox,
            order: sort_order
        )
        p.updatedAt = updated_at
        p.deletedAt = deleted_at
        return p
    }
}
