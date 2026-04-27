import Foundation
import SwiftData
import Supabase

// Supabase realtime subscription + per-event merge. One channel per
// signed-in owner with three postgres-change bindings (tasks, subtasks,
// projects). Events flow through the same last-write-wins guard as
// pullAll, so an echo of our own push is a no-op.

extension SyncService {

    // MARK: - Subscribe / unsubscribe

    /// Open a Supabase realtime channel for the current user and bind
    /// postgres-change streams for tasks, subtasks, and projects.
    ///
    /// Safe to call more than once: the SDK caches channels by topic, and
    /// if we already have a channel we rebuild cleanly (stop → start) so
    /// a scene-phase-driven restart after a background disconnect doesn't
    /// leak listeners.
    func startRealtime(context: ModelContext) async {
        guard let ownerId = currentOwnerIdSync() else { return }
        // Idempotent restart — evict any prior channel before creating a
        // new one. `client.channel(topic)` caches by topic, and bindings
        // can only be added BEFORE subscribe (see RealtimeChannelV2
        // _onPostgresChange). Reusing a subscribed channel would silently
        // drop our new bindings, so we must remove-and-recreate.
        await stopRealtime()

        let ownerFilter: RealtimePostgresFilter = .eq("owner_id", value: ownerId)
        let channel = client.channel("ploot:owner:\(ownerId.uuidString)")
        self.realtimeChannel = channel

        // Register bindings BEFORE subscribe.
        let taskStream = channel.postgresChange(
            AnyAction.self, schema: "public", table: "tasks", filter: ownerFilter
        )
        let subtaskStream = channel.postgresChange(
            AnyAction.self, schema: "public", table: "subtasks", filter: ownerFilter
        )
        let projectStream = channel.postgresChange(
            AnyAction.self, schema: "public", table: "projects", filter: ownerFilter
        )

        do {
            try await channel.subscribeWithError()
            log("realtime subscribed for \(ownerId.uuidString.prefix(8))…")
        } catch {
            log("realtime subscribe failed: \(error)")
            // Don't spin up consumers for a channel that never joined.
            // Next foreground will try again via startRealtime.
            self.realtimeChannel = nil
            return
        }

        // Kick off consumers. Streams buffer events (unbounded) while
        // these Tasks are starting up, so no events between subscribe
        // confirmation and the first iteration are lost.
        realtimeTasks.append(Task { [weak self] in
            for await action in taskStream {
                guard let self else { return }
                self.handleTaskAction(action, context: context)
            }
        })
        realtimeTasks.append(Task { [weak self] in
            for await action in subtaskStream {
                guard let self else { return }
                self.handleSubtaskAction(action, context: context)
            }
        })
        realtimeTasks.append(Task { [weak self] in
            for await action in projectStream {
                guard let self else { return }
                self.handleProjectAction(action, context: context)
            }
        })
    }

    func stopRealtime() async {
        for t in realtimeTasks { t.cancel() }
        realtimeTasks.removeAll()
        if let channel = realtimeChannel {
            // removeChannel unsubscribes (if subscribed) AND evicts the
            // topic from the SDK's cache, so the next startRealtime builds
            // a fresh channel instance with working bindings.
            await client.removeChannel(channel)
        }
        realtimeChannel = nil
    }

    // MARK: - Action handlers

    func handleTaskAction(_ action: AnyAction, context: ModelContext) {
        do {
            switch action {
            case .insert(let a):
                let dto: TaskDTO = try a.decodeRecord(decoder: Self.realtimeDecoder)
                applyRemoteTask(dto, context: context)
            case .update(let a):
                let dto: TaskDTO = try a.decodeRecord(decoder: Self.realtimeDecoder)
                applyRemoteTask(dto, context: context)
            case .delete(let a):
                // We never hard-delete tasks — tombstones are the norm —
                // but if it ever happens, mirror it locally.
                let dto: TaskDTO = try a.decodeOldRecord(decoder: Self.realtimeDecoder)
                hardDeleteTask(id: dto.id, context: context)
            }
            try? context.save()
        } catch {
            log("realtime task decode failed: \(error)")
        }
    }

    func handleSubtaskAction(_ action: AnyAction, context: ModelContext) {
        do {
            switch action {
            case .insert(let a):
                let dto: SubtaskDTO = try a.decodeRecord(decoder: Self.realtimeDecoder)
                applyRemoteSubtask(dto, context: context)
            case .update(let a):
                let dto: SubtaskDTO = try a.decodeRecord(decoder: Self.realtimeDecoder)
                applyRemoteSubtask(dto, context: context)
            case .delete(let a):
                let dto: SubtaskDTO = try a.decodeOldRecord(decoder: Self.realtimeDecoder)
                hardDeleteSubtask(id: dto.id, context: context)
            }
            try? context.save()
        } catch {
            log("realtime subtask decode failed: \(error)")
        }
    }

    func handleProjectAction(_ action: AnyAction, context: ModelContext) {
        do {
            switch action {
            case .insert(let a):
                let dto: ProjectDTO = try a.decodeRecord(decoder: Self.realtimeDecoder)
                applyRemoteProject(dto, context: context)
            case .update(let a):
                let dto: ProjectDTO = try a.decodeRecord(decoder: Self.realtimeDecoder)
                applyRemoteProject(dto, context: context)
            case .delete(let a):
                let dto: ProjectDTO = try a.decodeOldRecord(decoder: Self.realtimeDecoder)
                hardDeleteProject(id: dto.id, context: context)
            }
            try? context.save()
        } catch {
            log("realtime project decode failed: \(error)")
        }
    }

    // MARK: - Single-row merge (used by realtime handlers)

    func applyRemoteTask(_ dto: TaskDTO, context: ModelContext) {
        let desc = FetchDescriptor<PlootTask>(
            predicate: #Predicate { $0.id == dto.id }
        )
        if let local = (try? context.fetch(desc))?.first {
            let remoteTs = dto.updated_at ?? .distantPast
            let localTs = local.updatedAt ?? .distantPast
            if remoteTs > localTs { dto.apply(to: local) }
        } else {
            context.insert(dto.makeLocal())
        }
    }

    func applyRemoteSubtask(_ dto: SubtaskDTO, context: ModelContext) {
        let desc = FetchDescriptor<Subtask>(
            predicate: #Predicate { $0.id == dto.id }
        )
        if let local = (try? context.fetch(desc))?.first {
            let remoteTs = dto.updated_at ?? .distantPast
            let localTs = local.updatedAt ?? .distantPast
            if remoteTs > localTs { dto.apply(to: local) }
            return
        }
        // Insert — attach to parent if we have it. If the parent hasn't
        // landed yet (rare race: subtask realtime before task realtime),
        // skip; the next foreground pullAll will stitch it.
        let parentId = dto.task_id
        let parentDesc = FetchDescriptor<PlootTask>(
            predicate: #Predicate { $0.id == parentId }
        )
        guard let parent = (try? context.fetch(parentDesc))?.first else { return }
        let newSub = dto.makeLocal()
        newSub.task = parent
        context.insert(newSub)
    }

    func applyRemoteProject(_ dto: ProjectDTO, context: ModelContext) {
        let desc = FetchDescriptor<PlootProject>(
            predicate: #Predicate { $0.id == dto.id }
        )
        if let local = (try? context.fetch(desc))?.first {
            let remoteTs = dto.updated_at ?? .distantPast
            let localTs = local.updatedAt ?? .distantPast
            if remoteTs > localTs { dto.apply(to: local) }
        } else {
            context.insert(dto.makeLocal())
        }
    }

    func hardDeleteTask(id: UUID, context: ModelContext) {
        let desc = FetchDescriptor<PlootTask>(
            predicate: #Predicate { $0.id == id }
        )
        if let local = (try? context.fetch(desc))?.first { context.delete(local) }
    }

    func hardDeleteSubtask(id: UUID, context: ModelContext) {
        let desc = FetchDescriptor<Subtask>(
            predicate: #Predicate { $0.id == id }
        )
        if let local = (try? context.fetch(desc))?.first { context.delete(local) }
    }

    func hardDeleteProject(id: String, context: ModelContext) {
        let desc = FetchDescriptor<PlootProject>(
            predicate: #Predicate { $0.id == id }
        )
        if let local = (try? context.fetch(desc))?.first { context.delete(local) }
    }

    // MARK: - JSON decoder

    /// Postgres realtime payloads ship ISO8601 timestamps with microsecond
    /// precision and "+00:00" offsets. ISO8601DateFormatter's fractional
    /// mode only accepts 3 digits, so we trim to millis before parsing.
    /// nonisolated so the Decoder closure (which must be @Sendable) can
    /// call it without a main-actor hop.
    nonisolated static let realtimeDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let raw = try c.decode(String.self)
            if let date = parsePostgresISO8601(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: c,
                debugDescription: "Invalid realtime date: \(raw)"
            )
        }
        return d
    }()

    nonisolated static func parsePostgresISO8601(_ raw: String) -> Date? {
        var s = raw
        // Trim >3-digit fractional seconds to millis.
        if let dot = s.firstIndex(of: ".") {
            var end = s.index(after: dot)
            while end < s.endIndex, s[end].isNumber { end = s.index(after: end) }
            let digits = s[s.index(after: dot)..<end]
            if digits.count > 3 {
                s.replaceSubrange(s.index(after: dot)..<end, with: digits.prefix(3))
            }
        }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: s) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: s)
    }
}
