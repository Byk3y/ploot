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
///   * `pullAll(context:)` (see SyncService+Pull.swift) fetches every row
///     the current user owns, then merges row-by-row using `updatedAt` as
///     the tiebreaker.
///   * `startRealtime(context:)` (see SyncService+Realtime.swift) opens a
///     Supabase realtime channel and streams postgres-change events
///     through the same merge.
///   * `wipeLocal(context:)` (see SyncService+Pull.swift) hard-deletes
///     everything in SwiftData. Used on sign-out.
///
/// Error posture: best-effort. Network failures log and move on; the next
/// mutation's push or the next foreground pull will reconcile.
///
/// Members below are intentionally `internal` rather than `private` where
/// the extensions in SyncService+Pull.swift / SyncService+Realtime.swift
/// need access. Same-file `private` doesn't span files.
@MainActor
final class SyncService {
    static let shared = SyncService()
    private init() {}

    let client = Supa.client
    private var pushTaskTimers: [UUID: Task<Void, Never>] = [:]
    private var pushProjectTimers: [String: Task<Void, Never>] = [:]
    private var pushSubtaskTimers: [UUID: Task<Void, Never>] = [:]

    // Realtime subscription state. One channel per signed-in owner, three
    // postgres-change bindings on it (tasks, subtasks, projects), one
    // listener Task per binding.
    var realtimeChannel: RealtimeChannelV2?
    var realtimeTasks: [Task<Void, Never>] = []

    // MARK: - Current user id (sync fast-path)

    func currentOwnerIdSync() -> UUID? {
        // The SDK stores the current session in memory after auth state
        // changes fire. Reading it is synchronous and non-throwing.
        client.auth.currentSession?.user.id
    }

    func currentOwnerIdAsync() async -> UUID? {
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

    /// Pushes the user's free-text bio to their profiles row. Called from
    /// Settings → AI Breakdown → About you. Debounced at the call-site
    /// (800ms) so rapid typing doesn't flood the network.
    func pushBio(_ bio: String) async throws {
        guard let userId = currentOwnerIdSync() else { return }
        struct BioUpdate: Encodable { let bio: String }
        try await client
            .from("profiles")
            .update(BioUpdate(bio: bio))
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

    // MARK: - Debug log

    func log(_ message: String) {
        #if DEBUG
        print("[Ploot sync] \(message)")
        #endif
    }
}
