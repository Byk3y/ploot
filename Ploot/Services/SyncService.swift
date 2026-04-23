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

    // Realtime subscription state. One channel per signed-in owner, three
    // postgres-change bindings on it (tasks, subtasks, projects), one
    // listener Task per binding.
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTasks: [Task<Void, Never>] = []

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

    // MARK: - Profile onboarding push

    /// Writes the OnboardingAnswers bundle to the user's `profiles` row.
    /// Not debounced — this is called once at the end of onboarding and
    /// the caller awaits completion before advancing to land screen.
    ///
    /// The profiles row already exists via the AFTER INSERT trigger on
    /// auth.users (see 0001), so we UPDATE, not UPSERT.
    func pushOnboarding(answers: OnboardingAnswers, userId: UUID?) async throws {
        guard let userId = userId ?? currentOwnerIdSync() else {
            throw NSError(domain: "Ploot.Sync", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No user session — can't push onboarding answers."
            ])
        }

        struct OnboardingUpdate: Encodable {
            let chronotype: String?
            let daily_goal: Int
            let checkin_time: String          // HH:mm for Postgres `time`
            let reminder_style: String
            let primary_role: String?
            let planning_time: String?
            let current_system: String?
            let tasks_per_day: Int
            let uses_projects: Bool?
            let recurrence_heavy: Bool?
            let track_streak: Bool
            let onboarded_at: String          // ISO8601 for timestamptz
            let onboarding_answers: [String: [String]]
        }

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        timeFmt.locale = Locale(identifier: "en_US_POSIX")

        let update = OnboardingUpdate(
            chronotype: answers.chronotype?.rawValue,
            daily_goal: answers.dailyGoal,
            checkin_time: timeFmt.string(from: answers.checkinTime),
            reminder_style: answers.reminderStyle.rawValue,
            primary_role: answers.primaryRole?.rawValue,
            planning_time: answers.planningTime?.rawValue,
            current_system: answers.currentSystem?.rawValue,
            tasks_per_day: answers.tasksPerDay,
            uses_projects: answers.usesProjects,
            recurrence_heavy: answers.recurrenceHeavy,
            track_streak: answers.trackStreak,
            onboarded_at: ISO8601DateFormatter().string(from: Date()),
            onboarding_answers: [
                "whatBringsYou": Array(answers.whatBringsYou),
                "gettingInTheWay": Array(answers.gettingInTheWay)
            ]
        )

        try await client
            .from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    /// Snapshot of the onboarding-derived columns on `public.profiles`.
    /// Returned by `fetchOnboardingProfile` so a returning user on a
    /// fresh install can hydrate their local `UserPrefs` without
    /// re-walking the quiz.
    struct OnboardingProfileSnapshot: Decodable {
        let onboarded_at: String?
        let chronotype: String?
        let daily_goal: Int?
        let checkin_time: String?      // "HH:mm:ss" from the Postgres `time` column
        let reminder_style: String?
        let primary_role: String?
        let track_streak: Bool?

        var isCompleted: Bool { onboarded_at != nil }
    }

    /// Fetch the onboarding snapshot for the current user. Returns nil
    /// on network failure OR missing profile row — the caller treats
    /// that as "probably not completed; fall through to OnboardingFlow."
    func fetchOnboardingProfile() async -> OnboardingProfileSnapshot? {
        guard let userId = await currentOwnerIdAsync() else { return nil }
        do {
            let snapshot: OnboardingProfileSnapshot = try await client
                .from("profiles")
                .select("onboarded_at,chronotype,daily_goal,checkin_time,reminder_style,primary_role,track_streak")
                .eq("id", value: userId.uuidString)
                .single()
                .execute().value
            return snapshot
        } catch {
            log("onboarding profile fetch failed: \(error)")
            return nil
        }
    }

    /// Legacy shorthand — kept so existing callers compile. Prefer
    /// `fetchOnboardingProfile()` so the snapshot can drive UserPrefs
    /// hydration in the same roundtrip.
    func hasCompletedOnboardingRemotely() async -> Bool {
        await fetchOnboardingProfile()?.isCompleted ?? false
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

    // MARK: - Realtime subscribe

    /// Open a Supabase realtime channel for the current user and bind
    /// postgres-change streams for tasks, subtasks, and projects. Events
    /// flow through the same last-write-wins merge as `pullAll`, so an
    /// event echoing back our own recent push is a no-op (remote ts ==
    /// local ts, strict `>` guard skips the apply).
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

    // MARK: - Realtime action handlers

    private func handleTaskAction(_ action: AnyAction, context: ModelContext) {
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

    private func handleSubtaskAction(_ action: AnyAction, context: ModelContext) {
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

    private func handleProjectAction(_ action: AnyAction, context: ModelContext) {
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

    private func applyRemoteTask(_ dto: TaskDTO, context: ModelContext) {
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

    private func applyRemoteSubtask(_ dto: SubtaskDTO, context: ModelContext) {
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

    private func applyRemoteProject(_ dto: ProjectDTO, context: ModelContext) {
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

    private func hardDeleteTask(id: UUID, context: ModelContext) {
        let desc = FetchDescriptor<PlootTask>(
            predicate: #Predicate { $0.id == id }
        )
        if let local = (try? context.fetch(desc))?.first { context.delete(local) }
    }

    private func hardDeleteSubtask(id: UUID, context: ModelContext) {
        let desc = FetchDescriptor<Subtask>(
            predicate: #Predicate { $0.id == id }
        )
        if let local = (try? context.fetch(desc))?.first { context.delete(local) }
    }

    private func hardDeleteProject(id: String, context: ModelContext) {
        let desc = FetchDescriptor<PlootProject>(
            predicate: #Predicate { $0.id == id }
        )
        if let local = (try? context.fetch(desc))?.first { context.delete(local) }
    }

    // MARK: - Realtime JSON decoder

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

    nonisolated private static func parsePostgresISO8601(_ raw: String) -> Date? {
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

    // MARK: - Debug log

    private func log(_ message: String) {
        #if DEBUG
        print("[Ploot sync] \(message)")
        #endif
    }
}
