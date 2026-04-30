import SwiftUI
import SwiftData

/// Main AI breakdown experience. Streams events from the `breakdown` edge
/// function and renders them live: tasks appear one at a time, questions
/// interrupt the stream as a card, and terminal states (hint/split/refused
/// /error/rate-limit) collapse to a friendly one-screen surface.
///
/// When `reviewMode` is true (Settings → Review plan before starting),
/// tasks stream into a local buffer — nothing touches SwiftData until
/// the user taps "Start with step 1". This lets them reorder, rename,
/// and remove steps before committing. When false, the legacy behavior
/// of instant-insert is preserved.
///
/// Sub-views (header lines, streaming list, terminal cards) live in
/// BreakdownSheet+Views.swift; SwiftData inserts and removals live in
/// BreakdownSheet+SwiftData.swift. State below is internal-access (no
/// `private`) so the cross-file extensions can read/write it.
struct BreakdownSheet: View {
    let project: PlootProject
    var onClose: () -> Void

    @Environment(\.plootPalette) var palette
    @Environment(\.modelContext) var modelContext

    @State var phase: Phase = .thinking
    @State var streamedTasks: [StreamedTask] = []
    @State var pendingQuestion: PendingQuestion? = nil
    @State var answers: [BreakdownAnswer] = []
    @State var streamTask: Task<Void, Never>? = nil
    @State var completedCount: Int = 0
    @State var finishedHaptic: Int = 0
    @State var donePulse: Bool = false
    /// User-selected timeline window for the streamed tasks. Defaults
    /// from `Settings → AI breakdown → Default timeline`. Picking
    /// anything else triggers `applyTimeline(...)` which re-stamps every
    /// task's dueDate.
    @State var timelineMode: TimelineMode = TimelineMode.fromPref(UserPrefs.defaultTimelineMode)
    /// Captured when the sheet opens so every task in a single breakdown
    /// batch shares a base timestamp — insertion order then becomes the
    /// only distinguishing factor in createdAt.
    @State var baseCreatedAt: Date = Date()
    /// When true, tasks stream into a local buffer and SwiftData is
    /// untouched until the user explicitly commits via "Start with step 1".
    @State var reviewMode: Bool = UserPrefs.reviewBeforeCommit
    /// Index of the task currently being inline-renamed, if any.
    @State var editingTaskIndex: Int? = nil
    /// Temporary text buffer for inline rename.
    @State var editingText: String = ""

    enum Phase {
        case thinking
        case asking
        case streamingTasks
        case reviewing   // review mode: tasks buffered, awaiting commit
        case finished     // legacy mode: tasks already inserted
        case hint
        case split(projects: [String])
        case refused(reason: String)
        case error(code: String, recoverable: Bool)
        case rateLimited(resetAt: Date?, used: Int, limit: Int)
    }

    struct PendingQuestion: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let choices: [String]
        let allowCustom: Bool
    }

    struct StreamedTask: Identifiable, Equatable {
        let id = UUID()
        var order: Int
        var title: String
        /// PlootTask.id for the row we inserted into SwiftData. Kept so
        /// the swipe-to-remove action can soft-delete the real row, not
        /// just hide it from the sheet. nil in review mode (no row yet).
        var taskId: UUID?
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            
            if case .reviewing = phase {
                List {
                    Section {
                        if !answers.isEmpty {
                            contextPills
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.bottom, Spacing.s2)
                        }
                        
                        reviewableList
                        
                        reviewFooter
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.top, Spacing.s3)
                            .padding(.bottom, 40)
                    } header: {
                        projectLine
                            .padding(.bottom, Spacing.s4)
                            .padding(.top, Spacing.s3)
                            .textCase(nil)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, Spacing.s4)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.s4) {
                        projectLine
                        if !answers.isEmpty {
                            contextPills
                        }
                        content
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(palette.bg.ignoresSafeArea())
        .plootHaptic(.success, trigger: finishedHaptic)
        .onAppear(perform: startInitialStream)
        .onDisappear {
            streamTask?.cancel()
            streamTask = nil
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(phase.isWorking ? "Cancel" : "Close", action: closeSheet)
                .font(.geist(size: 15, weight: 500))
                .foregroundStyle(palette.fg2)

            Spacer()

            Text(topBarTitle)
                .font(.fraunces(size: 20, weight: 600, opsz: 20, soft: 80))
                .foregroundStyle(palette.fg1)

            Spacer()

            if case .reviewing = phase {
                // In review mode the commit button is inline, not the top bar.
                Color.clear.frame(width: 60, height: 1)
            } else {
                Button("Done", action: closeSheet)
                    .buttonStyle(.ploot(.primary, size: .sm))
                    .scaleEffect(donePulse ? 1.12 : 1)
                    .opacity(phase.canFinish ? 1 : 0.35)
                    .disabled(!phase.canFinish)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
    }

    private var topBarTitle: String {
        switch phase {
        case .reviewing: return "Your plan"
        case .finished: return "All set"
        default: return "Breaking down"
        }
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .thinking:
            thinkingShimmer

        case .asking:
            if let q = pendingQuestion {
                BreakdownQuestionCard(
                    question: q.text,
                    choices: q.choices,
                    allowCustom: q.allowCustom,
                    onAnswer: { answer in handleAnswer(questionText: q.text, answer: answer) }
                )
            }

        case .streamingTasks, .finished, .reviewing:
            streamedTaskList

        case .hint:
            terminalCard(
                emoji: "💡",
                title: "this feels more like a task.",
                body: "want to add it as a single task in \(project.name)?",
                primaryLabel: "Add as task",
                primaryAction: addAsSingleTask,
                secondaryLabel: "Not now",
                secondaryAction: closeSheet
            )

        case .split(let projects):
            splitCard(projects: projects)

        case .refused(let reason):
            terminalCard(
                emoji: "🙂",
                title: reason,
                body: nil,
                primaryLabel: "Okay",
                primaryAction: closeSheet,
                secondaryLabel: nil,
                secondaryAction: nil
            )

        case .error(let code, let recoverable):
            // Only offer retry when no tasks have landed yet — retrying with
            // partial rows in SwiftData would leave the earlier batch behind
            // and merge a fresh batch on top, duplicating work.
            let canRetry = recoverable && streamedTasks.isEmpty
            terminalCard(
                emoji: "🌀",
                title: errorTitle(for: code),
                body: streamedTasks.isEmpty
                    ? "something hiccuped on our end."
                    : "we kept what we got. try again another time.",
                primaryLabel: canRetry ? "Try again" : "Close",
                primaryAction: canRetry ? { retryStream() } : closeSheet,
                secondaryLabel: canRetry ? "Close" : nil,
                secondaryAction: canRetry ? closeSheet : nil
            )

        case .rateLimited(let resetAt, let used, let limit):
            terminalCard(
                emoji: "⏳",
                title: "that's your breakdowns for today.",
                body: rateLimitBody(resetAt: resetAt, used: used, limit: limit),
                primaryLabel: "Got it",
                primaryAction: closeSheet,
                secondaryLabel: nil,
                secondaryAction: nil
            )
        }
    }

    // MARK: - Stream lifecycle

    private func startInitialStream() {
        streamedTasks = []
        answers = []
        pendingQuestion = nil
        withAnimation(Motion.spring) { phase = .thinking }
        runStream(title: project.name, answers: [])
    }

    private func retryStream() {
        streamedTasks = []
        pendingQuestion = nil
        withAnimation(Motion.spring) { phase = .thinking }
        runStream(title: project.name, answers: answers)
    }

    /// Re-runs the breakdown stream from scratch with the same answers.
    /// Clears all buffered tasks so the user sees a fresh plan.
    func redoPlan() {
        streamedTasks = []
        completedCount = 0
        editingTaskIndex = nil
        baseCreatedAt = Date()
        withAnimation(Motion.spring) { phase = .thinking }
        runStream(title: project.name, answers: answers)
    }

    private func runStream(title: String, answers: [BreakdownAnswer]) {
        streamTask?.cancel()

        // Gather context from the sheet's modelContext (available via
        // @Environment). This is lightweight — just project names and a
        // count — so it adds no meaningful latency.
        let bio: String? = {
            let b = UserPrefs.bio
            return b.isEmpty ? nil : b
        }()

        let projectContext: BreakdownService.ProjectContext? = {
            let descriptor = FetchDescriptor<PlootProject>()
            guard let projects = try? modelContext.fetch(descriptor) else { return nil }
            let liveProjects = projects.filter(\.isLive)
            let names = liveProjects.prefix(10).map { $0.name }
            let taskDescriptor = FetchDescriptor<PlootTask>()
            let taskCount = (try? modelContext.fetchCount(taskDescriptor)) ?? 0
            let projectCount = max(1, liveProjects.count)
            return BreakdownService.ProjectContext(
                completed_projects: [],  // not tracked at project level yet
                active_projects: Array(names),
                avg_tasks_per_project: taskCount / projectCount
            )
        }()

        streamTask = Task { @MainActor in
            do {
                for try await event in BreakdownService.stream(
                    title: title,
                    answers: answers,
                    bio: bio,
                    projectContext: projectContext
                ) {
                    await handleEvent(event)
                }
            } catch BreakdownError.rateLimited(let resetAt, let used, let limit) {
                withAnimation(Motion.spring) {
                    phase = .rateLimited(resetAt: resetAt, used: used, limit: limit)
                }
            } catch BreakdownError.unauthorized {
                withAnimation(Motion.spring) {
                    phase = .error(code: "unauthorized", recoverable: false)
                }
            } catch BreakdownError.cancelled {
                return
            } catch {
                withAnimation(Motion.spring) {
                    phase = .error(code: "network", recoverable: true)
                }
            }
        }
    }

    @MainActor
    private func handleEvent(_ event: BreakdownEvent) async {
        switch event {
        case .heartbeat:
            break

        case .question(let text, let choices, let allowCustom):
            withAnimation(Motion.spring) {
                pendingQuestion = PendingQuestion(
                    text: text,
                    choices: choices,
                    allowCustom: allowCustom
                )
                phase = .asking
            }

        case .task(let order, let title):
            if case .thinking = phase {
                withAnimation(Motion.spring) { phase = .streamingTasks }
            } else if case .asking = phase {
                withAnimation(Motion.spring) {
                    pendingQuestion = nil
                    phase = .streamingTasks
                }
            }
            if reviewMode {
                // Buffer only — no SwiftData insert yet.
                let streamed = StreamedTask(
                    order: order,
                    title: title,
                    taskId: nil
                )
                withAnimation(Motion.spring) {
                    streamedTasks.append(streamed)
                }
            } else {
                let taskId = insertTask(title: title, order: order)
                let streamed = StreamedTask(
                    order: order,
                    title: title,
                    taskId: taskId
                )
                withAnimation(Motion.spring) {
                    streamedTasks.append(streamed)
                }
            }

        case .hint:
            withAnimation(Motion.spring) { phase = .hint }

        case .split(let projects):
            withAnimation(Motion.spring) { phase = .split(projects: projects) }

        case .refused(let reason):
            withAnimation(Motion.spring) { phase = .refused(reason: reason) }

        case .done(let count):
            completedCount = count
            if count > 0 {
                finishedHaptic &+= 1
                if reviewMode {
                    // Go to review — user must commit before tasks land in SwiftData.
                    withAnimation(Motion.spring) { phase = .reviewing }
                } else {
                    withAnimation(Motion.spring) { phase = .finished }
                    // Apply the user's default timeline immediately so a
                    // pref of "this week" actually spreads the tasks
                    // without requiring a chip tap. .drip is a no-op
                    // restore so it's safe to always call.
                    if timelineMode != .drip {
                        applyTimeline(timelineMode)
                    }
                }
                pulseDoneButton()
            }

        case .error(let code):
            withAnimation(Motion.spring) {
                phase = .error(code: code, recoverable: true)
            }
        }
    }

    private func handleAnswer(questionText: String, answer: String) {
        let newAnswers = answers + [BreakdownAnswer(q: questionText, a: answer)]
        withAnimation(Motion.spring) {
            answers = newAnswers
            pendingQuestion = nil
            phase = .thinking
        }
        runStream(title: project.name, answers: newAnswers)
    }

    // MARK: - Helpers

    private func pulseDoneButton() {
        withAnimation(Motion.spring) { donePulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(Motion.spring) { donePulse = false }
        }
    }

    func closeSheet() {
        streamTask?.cancel()
        onClose()
    }

    private func errorTitle(for code: String) -> String {
        switch code {
        case "timeout": return "that took too long."
        case "unauthorized": return "we couldn't verify your session."
        case "upstream": return "the ai is offline right now."
        default: return "something didn't click."
        }
    }

    private func rateLimitBody(resetAt: Date?, used: Int, limit: Int) -> String {
        let usage = "\(used) of \(limit) used today."
        if let resetAt {
            let fmt = DateFormatter()
            fmt.timeStyle = .short
            fmt.dateStyle = .none
            return "\(usage) resets at \(fmt.string(from: resetAt))."
        }
        return "\(usage) resets at midnight utc."
    }
}

private extension BreakdownSheet.Phase {
    var isWorking: Bool {
        switch self {
        case .thinking, .asking, .streamingTasks: return true
        default: return false
        }
    }

    var canFinish: Bool {
        switch self {
        case .thinking, .asking: return false
        case .streamingTasks, .finished, .reviewing, .hint, .split, .refused, .error, .rateLimited:
            return true
        }
    }
}
