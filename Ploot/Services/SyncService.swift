import Foundation
import SwiftData
import Observation
import Supabase

/// Bridges SwiftData (local) and Supabase (remote) for tasks, subtasks,
/// and projects.
///
/// Contract:
///   * `push(task:)` / `push(project:)` / `push(subtask:)` are idempotent.
///     Each upserts by primary key (UUID for tasks/subtasks; composite
///     owner_id+slug for projects). Debounced per id (400ms) so rapid
///     edits coalesce into one network call.
///   * `push(task:)` also pushes that task's live subtasks AFTER the task
///     upserts, sequentially. This guarantees FK ordering (subtasks can't
///     land before their parent task exists on the server).
///   * `pullAll(context:)` fetches every row the current user owns, then
///     merges row-by-row using `updatedAt` as the tiebreaker. Remote rows
///     missing locally are inserted; local rows newer than remote (or
///     missing from remote) are pushed.
///   * `wipeLocal(context:)` hard-deletes everything in SwiftData. Used
///     on sign-out so the next user of this device starts fresh.
///
/// Error posture: best-effort. Network failures log and move on; the next
/// mutation's push or the next foreground pull will reconcile.
@MainActor
final class SyncService {
    static let shared = SyncService()
    private init() {}

    private let client = Supa.client
    private var pushTaskTimers: [UUID: Task<Void, Never>] = [:]
    private var pushProjectTimers: [String: Task<Void, Never>] = [:]
    private var pushSubtaskTimers: [UUID: Task<Void, Never>] = [:]

    // MARK: - Current user id (sync fast-path)

    private func currentOwnerIdSync() -> UUID? {
        // The SDK stores the current session in memory after auth state
        // changes fire. Reading it is synchronous and non-throwing.
        client.auth.currentSession?.user.id
    }

    private func currentOwnerIdAsync() async -> UUID? {
        if let cached = client.auth.currentSession?.user.id { return cached }
        return try? await client.auth.session.user.id
    }

    // MARK: - Push API (debounced)

    func push(task: PlootTask) {
        guard let ownerId = currentOwnerIdSync() else { return }
        let id = task.id
        // Snapshot the task AND its live subtasks on the main actor so the
        // detached work has value-type copies that won't race against
        // subsequent edits.
        let taskDTO = TaskDTO(from: task, ownerId: ownerId)
        // Include tombstoned subtasks too so their deletion propagates.
        let subDTOs = task.subtasks.map {
            SubtaskDTO(from: $0, parentId: task.id, ownerId: ownerId)
        }

        pushTaskTimers[id]?.cancel()
        pushTaskTimers[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            // Task FIRST, then subtasks. FK on subtasks.task_id means the
            // parent row must exist before children land.
            await self.upsertTask(taskDTO)
            for subDTO in subDTOs {
                await self.upsertSubtask(subDTO)
            }
        }
    }

    func push(project: PlootProject) {
        guard let ownerId = currentOwnerIdSync() else { return }
        let id = project.id
        let dto = ProjectDTO(from: project, ownerId: ownerId)

        pushProjectTimers[id]?.cancel()
        pushProjectTimers[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            await self.upsertProject(dto)
        }
    }

    func push(subtask: Subtask) {
        guard let parentId = subtask.task?.id else { return }
        guard let ownerId = currentOwnerIdSync() else { return }
        let dto = SubtaskDTO(from: subtask, parentId: parentId, ownerId: ownerId)
        let id = subtask.id

        pushSubtaskTimers[id]?.cancel()
        pushSubtaskTimers[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            await self.upsertSubtask(dto)
        }
    }

    // MARK: - Upsert (raw)

    private func upsertTask(_ dto: TaskDTO) async {
        do {
            try await client.from("tasks").upsert(dto).execute()
        } catch {
            log("upsert task failed: \(error)")
        }
    }

    private func upsertProject(_ dto: ProjectDTO) async {
        do {
            try await client
                .from("projects")
                .upsert(dto, onConflict: "owner_id,id")
                .execute()
        } catch {
            log("upsert project failed: \(error)")
        }
    }

    private func upsertSubtask(_ dto: SubtaskDTO) async {
        do {
            try await client.from("subtasks").upsert(dto).execute()
        } catch {
            log("upsert subtask failed: \(error)")
        }
    }

    // MARK: - Pull

    func pullAll(context: ModelContext) async {
        guard let ownerId = await currentOwnerIdAsync() else { return }

        let remoteTasks: [TaskDTO]
        let remoteSubtasks: [SubtaskDTO]
        let remoteProjects: [ProjectDTO]
        do {
            remoteTasks = try await client.from("tasks")
                .select()
                .eq("owner_id", value: ownerId.uuidString)
                .execute().value
            remoteSubtasks = try await client.from("subtasks")
                .select()
                .eq("owner_id", value: ownerId.uuidString)
                .execute().value
            remoteProjects = try await client.from("projects")
                .select()
                .eq("owner_id", value: ownerId.uuidString)
                .execute().value
        } catch {
            log("pullAll fetch failed: \(error)")
            return
        }

        // Projects first — task rows reference project ids via FK.
        mergeProjects(remoteProjects, into: context)
        mergeTasks(remoteTasks, subtasks: remoteSubtasks, into: context)

        try? context.save()

        // After the merge, push anything where local is newer OR local has
        // a row that remote is missing. Catches edits that never got to
        // flush (e.g. app killed before the debounce fired) plus all
        // purely-local rows (demo-seeded data at first sign-in, etc.).
        await pushLocalsDiff(
            context: context,
            remoteTasks: remoteTasks,
            remoteSubtasks: remoteSubtasks,
            remoteProjects: remoteProjects
        )
    }

    // MARK: - Merge helpers

    private func mergeProjects(_ remote: [ProjectDTO], into context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<PlootProject>())) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for dto in remote {
            if let local = existingById[dto.id] {
                let remoteTs = dto.updated_at ?? .distantPast
                let localTs = local.updatedAt ?? .distantPast
                if remoteTs > localTs {
                    dto.apply(to: local)
                }
            } else {
                context.insert(dto.makeLocal())
            }
        }
    }

    private func mergeTasks(
        _ remote: [TaskDTO],
        subtasks remoteSubtasks: [SubtaskDTO],
        into context: ModelContext
    ) {
        let existing = (try? context.fetch(FetchDescriptor<PlootTask>())) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        // Index subtasks by parent task id up front.
        var subtasksByTaskId: [UUID: [SubtaskDTO]] = [:]
        for sub in remoteSubtasks {
            subtasksByTaskId[sub.task_id, default: []].append(sub)
        }

        for dto in remote {
            if let local = existingById[dto.id] {
                let remoteTs = dto.updated_at ?? .distantPast
                let localTs = local.updatedAt ?? .distantPast
                if remoteTs > localTs {
                    dto.apply(to: local)
                }
                mergeSubtasks(subtasksByTaskId[dto.id] ?? [], parent: local, context: context)
            } else {
                let newTask = dto.makeLocal()
                context.insert(newTask)
                // Attach subtasks after insert so the relationship resolves.
                for subDTO in subtasksByTaskId[dto.id] ?? [] {
                    let sub = subDTO.makeLocal()
                    sub.task = newTask
                    context.insert(sub)
                }
            }
        }
    }

    private func mergeSubtasks(_ remote: [SubtaskDTO], parent: PlootTask, context: ModelContext) {
        let existing = parent.subtasks
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for dto in remote {
            if let local = existingById[dto.id] {
                let remoteTs = dto.updated_at ?? .distantPast
                let localTs = local.updatedAt ?? .distantPast
                if remoteTs > localTs {
                    dto.apply(to: local)
                }
            } else {
                let newSub = dto.makeLocal()
                newSub.task = parent
                context.insert(newSub)
            }
        }
    }

    // MARK: - Push locals that are newer than remote (or missing remotely)

    private func pushLocalsDiff(
        context: ModelContext,
        remoteTasks: [TaskDTO],
        remoteSubtasks: [SubtaskDTO],
        remoteProjects: [ProjectDTO]
    ) async {
        let localTasks = (try? context.fetch(FetchDescriptor<PlootTask>())) ?? []
        let localSubs = (try? context.fetch(FetchDescriptor<Subtask>())) ?? []
        let localProjects = (try? context.fetch(FetchDescriptor<PlootProject>())) ?? []

        let remoteTaskById = Dictionary(uniqueKeysWithValues: remoteTasks.map { ($0.id, $0) })
        let remoteSubById = Dictionary(uniqueKeysWithValues: remoteSubtasks.map { ($0.id, $0) })
        let remoteProjectById = Dictionary(uniqueKeysWithValues: remoteProjects.map { ($0.id, $0) })

        for project in localProjects {
            let localTs = project.updatedAt ?? .distantPast
            let remoteTs = remoteProjectById[project.id]?.updated_at ?? .distantPast
            if remoteProjectById[project.id] == nil || localTs > remoteTs {
                push(project: project)
            }
        }
        for task in localTasks {
            let localTs = task.updatedAt ?? .distantPast
            let remoteTs = remoteTaskById[task.id]?.updated_at ?? .distantPast
            if remoteTaskById[task.id] == nil || localTs > remoteTs {
                push(task: task)  // also pushes its subtasks after the task lands
            }
        }
        for sub in localSubs {
            let localTs = sub.updatedAt ?? .distantPast
            let remoteTs = remoteSubById[sub.id]?.updated_at ?? .distantPast
            // Only push subtasks whose parent task we're not already pushing —
            // push(task:) batch-pushes subtasks, so skipping orphans avoids
            // duplicate work. Safe to always push though; upserts are idempotent.
            if remoteSubById[sub.id] == nil || localTs > remoteTs {
                push(subtask: sub)
            }
        }
    }

    // MARK: - Sign-out

    func wipeLocal(context: ModelContext) {
        let subs = (try? context.fetch(FetchDescriptor<Subtask>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<PlootTask>())) ?? []
        let projects = (try? context.fetch(FetchDescriptor<PlootProject>())) ?? []
        for s in subs { context.delete(s) }
        for t in tasks { context.delete(t) }
        for p in projects { context.delete(p) }
        try? context.save()
    }

    // MARK: - Debug log

    private func log(_ message: String) {
        #if DEBUG
        print("[Ploot sync] \(message)")
        #endif
    }
}
