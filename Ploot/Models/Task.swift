import Foundation
import SwiftData

// MARK: - Enums (stored as raw values in the model store)

enum Priority: String, CaseIterable, Codable, Identifiable {
    case normal, medium, high, urgent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .medium: return "Medium"
        case .high:   return "High"
        case .urgent: return "Urgent"
        }
    }

    var emoji: String {
        switch self {
        case .normal: return ""
        case .medium: return "⚡"
        case .high:   return "❗"
        case .urgent: return "🔥"
        }
    }
}

enum TaskSection: String, Codable, CaseIterable {
    case overdue
    case today
    case later
    case done

    var displayTitle: String {
        switch self {
        case .overdue: return "Overdue"
        case .today:   return "Today"
        case .later:   return "Later this week"
        case .done:    return "Done"
        }
    }
}

// MARK: - Subtask model

@Model
final class Subtask {
    var id: UUID
    var title: String
    var done: Bool
    var order: Int
    /// Bumped on every mutation — basis for last-write-wins conflict
    /// resolution once Supabase sync lands. Optional so that adding this
    /// field as a lightweight SwiftData migration doesn't reject existing
    /// on-device rows; nil means "never mutated since the column arrived"
    /// and is treated as distant-past at sync time.
    var updatedAt: Date?
    var task: PlootTask?

    init(title: String, done: Bool = false, order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.done = done
        self.order = order
        self.updatedAt = Date()
    }

    /// Toggle or set completion. Bumps both this subtask's timestamp and the
    /// parent task's — from sync's perspective, a subtask change counts as a
    /// task change.
    func setDone(_ value: Bool) {
        done = value
        touch()
        task?.touch()
    }

    func touch() {
        updatedAt = Date()
    }
}

// MARK: - PlootTask model

@Model
final class PlootTask {
    var id: UUID
    var title: String
    var note: String?
    /// Free-form label fallback (e.g. "Yesterday", "Next Tuesday"). Preferred
    /// display path goes through `dueDate`; this sticks around for tasks
    /// seeded before Phase 3b and for the odd dateless-with-label case.
    var due: String?
    /// Canonical due timestamp. When present, all section + display logic
    /// derives from this. `nil` means the task is dateless / floating.
    var dueDate: Date?
    var duration: String?
    /// References PlootProject.id (the String slug like "work", "home").
    /// Kept as a loose FK rather than a @Relationship because projects are
    /// identified by their slug, not by PersistentIdentifier.
    var projectId: String?
    var priority: Priority
    var tags: [String]
    @Relationship(deleteRule: .cascade, inverse: \Subtask.task)
    var subtasks: [Subtask]
    var done: Bool
    var section: TaskSection
    var overdue: Bool
    var repeats: String?
    var createdAt: Date
    var completedAt: Date?
    /// Bumped on every mutation — basis for last-write-wins conflict
    /// resolution once Supabase sync lands. Optional so this column can be
    /// added as a lightweight SwiftData migration without rejecting existing
    /// rows; see Subtask.updatedAt for the full rationale.
    var updatedAt: Date?

    init(
        title: String,
        note: String? = nil,
        due: String? = nil,
        dueDate: Date? = nil,
        duration: String? = nil,
        projectId: String? = nil,
        priority: Priority = .normal,
        tags: [String] = [],
        subtasks: [Subtask] = [],
        done: Bool = false,
        section: TaskSection = .today,
        overdue: Bool = false,
        repeats: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.due = due
        self.dueDate = dueDate
        self.duration = duration
        self.projectId = projectId
        self.priority = priority
        self.tags = tags
        self.subtasks = subtasks
        self.done = done
        self.section = section
        self.overdue = overdue
        self.repeats = repeats
        let now = Date()
        self.createdAt = now
        self.completedAt = done ? now : nil
        self.updatedAt = now
    }

    /// Apply a done/undone toggle with the side-effects needed for UI to
    /// stay consistent (section, timestamps).
    func setDone(_ value: Bool) {
        done = value
        if value {
            completedAt = Date()
            section = .done
        } else {
            completedAt = nil
            if section == .done {
                section = .today
            }
        }
        touch()
    }

    /// Bump `updatedAt` to now. Call after any mutation that should flow up
    /// to Supabase as a change.
    func touch() {
        updatedAt = Date()
    }
}
