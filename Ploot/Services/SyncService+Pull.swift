import Foundation
import SwiftData
import Supabase

// Bulk reconcile (pullAll) and the merge helpers it uses. Pulled out of
// SyncService.swift to keep that file focused on the push-side debounced
// pipeline. All access to client / log goes through the parent class's
// internal members.

extension SyncService {

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

    func mergeProjects(_ remote: [ProjectDTO], into context: ModelContext) {
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

    func mergeTasks(
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

    func mergeSubtasks(_ remote: [SubtaskDTO], parent: PlootTask, context: ModelContext) {
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

    func pushLocalsDiff(
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
}
