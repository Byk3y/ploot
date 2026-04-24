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
    /// Soft-delete tombstone; see PlootTask.deletedAt for rationale.
    var deletedAt: Date?
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
    /// task change. Push immediately (synchronously) so the DTO captures the
    /// live parent id before any downstream relationship mutation can nil it.
    ///
    /// @MainActor: callers are always SwiftUI views; isolation lets us call
    /// the main-actor SyncService without a Task hop that could defer the
    /// DTO capture until after the parent relationship was cleared.
    @MainActor
    func setDone(_ value: Bool) {
        done = value
        touch()
        task?.touch()
        SyncService.shared.push(subtask: self)
        if let parent = self.task { SyncService.shared.push(task: parent) }
    }

    func touch() {
        updatedAt = Date()
    }

    @MainActor
    func softDelete() {
        deletedAt = Date()
        touch()
        task?.touch()
        SyncService.shared.push(subtask: self)
        if let parent = self.task { SyncService.shared.push(task: parent) }
    }

    var isLive: Bool { deletedAt == nil }
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
    /// When true, a local notification is scheduled for this task's
    /// `dueDate`. Optional so adding this column is a clean lightweight
    /// migration — existing rows read as nil (treated as false).
    var remindMe: Bool?
    var createdAt: Date
    var completedAt: Date?
    /// Bumped on every mutation — basis for last-write-wins conflict
    /// resolution once Supabase sync lands. Optional so this column can be
    /// added as a lightweight SwiftData migration without rejecting existing
    /// rows; see Subtask.updatedAt for the full rationale.
    var updatedAt: Date?
    /// Soft-delete tombstone. When non-nil, this task is deleted as far as
    /// the UI is concerned — @Query call sites filter it out — but the row
    /// sticks around long enough for the sync layer to propagate the
    /// deletion to other devices.
    var deletedAt: Date?

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
        repeats: String? = nil,
        remindMe: Bool = false
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
        self.remindMe = remindMe
        let now = Date()
        self.createdAt = now
        self.completedAt = done ? now : nil
        self.updatedAt = now
    }

    /// Apply a done/undone toggle with the side-effects needed for UI to
    /// stay consistent (section, timestamps). Also re-syncs the task's
    /// local reminder and pushes the change upstream to Supabase.
    /// @MainActor because ReminderService and SyncService are both
    /// main-actor-isolated; our call sites are SwiftUI views so this is
    /// already the case, we're just telling the compiler.
    @MainActor
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
        ReminderService.shared.schedule(for: self)
        SyncService.shared.push(task: self)
        if value, let ctx = self.modelContext {
            StreakManager.bumpIfGoalHit(context: ctx)
            // If this task belonged to a breakdown project, surface the
            // next queued task so the project always has exactly one
            // active step in Today.
            ProjectTaskPromoter.promoteNextIfNeeded(afterCompleting: self, context: ctx)
        }
    }

    /// Bump `updatedAt` to now. Call after any mutation that should flow up
    /// to Supabase as a change.
    func touch() {
        updatedAt = Date()
    }

    /// Soft-delete. Stamps `deletedAt` and bumps `updatedAt` so the tombstone
    /// is pushed to Supabase on the next sync. UI queries filter
    /// `deletedAt != nil` out so the row disappears instantly. Hard-removal
    /// happens during the GC pass (future).
    @MainActor
    func softDelete() {
        deletedAt = Date()
        touch()
        SyncService.shared.push(task: self)
    }

    /// `true` for rows the UI should render. False for tombstones pending
    /// deletion propagation.
    var isLive: Bool { deletedAt == nil }
}
