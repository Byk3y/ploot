import SwiftUI
import SwiftData

/// Main AI breakdown experience. Streams events from the `breakdown` edge
/// function and renders them live: tasks appear one at a time, questions
/// interrupt the stream as a card, and terminal states (hint/split/refused
/// /error/rate-limit) collapse to a friendly one-screen surface.
///
/// Tasks are inserted into SwiftData as they arrive so the user sees them
/// land in the project list behind the sheet too — no "commit" step.
struct BreakdownSheet: View {
    let project: PlootProject
    var onClose: () -> Void

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    @State private var phase: Phase = .thinking
    @State private var streamedTasks: [StreamedTask] = []
    @State private var pendingQuestion: PendingQuestion? = nil
    @State private var answers: [BreakdownAnswer] = []
    @State private var streamTask: Task<Void, Never>? = nil
    @State private var completedCount: Int = 0
    @State private var finishedHaptic: Int = 0
    @State private var donePulse: Bool = false
    /// Captured when the sheet opens so every task in a single breakdown
    /// batch shares a base timestamp — insertion order then becomes the
    /// only distinguishing factor in createdAt.
    @State private var baseCreatedAt: Date = Date()

    enum Phase {
        case thinking
        case asking
        case streamingTasks
        case finished
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
        let order: Int
        let emoji: String
        let title: String
        /// PlootTask.id for the row we inserted into SwiftData. Kept so the
        /// swipe-to-remove action can soft-delete the real row, not just
        /// hide it from the sheet.
        let taskId: UUID
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
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
        .background(palette.bg.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: finishedHaptic)
        .onAppear(perform: startInitialStream)
        .onDisappear {
            streamTask?.cancel()
            streamTask = nil
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button("Close", action: closeSheet)
                .font(.geist(size: 15, weight: 500))
                .foregroundStyle(palette.fg2)

            Spacer()

            Text("Breaking down")
                .font(.fraunces(size: 20, weight: 600, opsz: 20, soft: 80))
                .foregroundStyle(palette.fg1)

            Spacer()

            Button("Done", action: closeSheet)
                .buttonStyle(.ploot(.primary, size: .sm))
                .scaleEffect(donePulse ? 1.12 : 1)
                .opacity(phase.canFinish ? 1 : 0.35)
                .disabled(!phase.canFinish)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
    }

    // MARK: - Content

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

        case .streamingTasks, .finished:
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

    // MARK: - Sub-views

    private var projectLine: some View {
        HStack(spacing: Spacing.s2) {
            Text(project.emoji).font(.system(size: 18))
            Text(project.name)
                .font(.fraunces(size: 22, weight: 600, opsz: 22, soft: 60))
                .tracking(-0.01 * 22)
                .foregroundStyle(palette.fg1)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    private var contextPills: some View {
        // Index-based IDs so repeated answer text ("skip", "not sure" twice) can't
        // collapse a SwiftUI identity and crash the ForEach.
        HStack(spacing: 6) {
            ForEach(Array(answers.enumerated()), id: \.offset) { _, answer in
                Text(answer.a)
                    .font(.geist(size: 11, weight: 600))
                    .foregroundStyle(palette.fg2)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(palette.bgSunken))
                    .overlay(Capsule().strokeBorder(palette.border, lineWidth: 1.5))
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
    }

    private var thinkingShimmer: some View {
        HStack(spacing: Spacing.s2) {
            ProgressView()
                .tint(palette.fg2)
            Text("thinking...")
                .font(.geist(size: 14, weight: 500))
                .foregroundStyle(palette.fg3)
        }
        .padding(.top, Spacing.s3)
        .transition(.opacity)
    }

    private var streamedTaskList: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            ForEach(streamedTasks) { task in
                streamedRow(task)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
            if case .streamingTasks = phase {
                thinkingShimmer
                    .padding(.top, Spacing.s1)
            }
            if case .finished = phase {
                completionChip
                    .padding(.top, Spacing.s2)
            }
        }
    }

    private func streamedRow(_ task: StreamedTask) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Text(task.emoji)
                .font(.system(size: 20))
                .frame(width: 32, height: 32)
            Text(task.title)
                .font(.geist(size: 15, weight: 500))
                .foregroundStyle(palette.fg1)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.s3)
        .padding(.vertical, Spacing.s2)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(palette.borderInk, lineWidth: 2)
        )
        .stampedShadow(radius: Radius.md, offset: 2)
        .contextMenu {
            Button(role: .destructive) { removeStreamedTask(task) } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private var completionChip: some View {
        HStack(spacing: 6) {
            Text("✨").font(.system(size: 14))
            Text("\(completedCount) ready. all set.")
                .font(.geist(size: 13, weight: 500))
                .foregroundStyle(palette.fg2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(palette.primary.opacity(0.15)))
        .overlay(Capsule().strokeBorder(palette.primary.opacity(0.35), lineWidth: 1.5))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Terminal cards

    private func terminalCard(
        emoji: String,
        title: String,
        body: String?,
        primaryLabel: String,
        primaryAction: @escaping () -> Void,
        secondaryLabel: String?,
        secondaryAction: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text(emoji).font(.system(size: 36))
            Text(title)
                .font(.fraunces(size: 22, weight: 500, opsz: 22, soft: 60))
                .tracking(-0.01 * 22)
                .foregroundStyle(palette.fg1)
                .fixedSize(horizontal: false, vertical: true)
            if let body {
                Text(body)
                    .font(.geist(size: 14, weight: 400))
                    .foregroundStyle(palette.fg3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Spacing.s2) {
                Button(primaryLabel, action: primaryAction)
                    .buttonStyle(.ploot(.primary, size: .sm))
                if let secondaryLabel, let secondaryAction {
                    Button(secondaryLabel, action: secondaryAction)
                        .buttonStyle(.ploot(.ghost, size: .sm))
                }
            }
            .padding(.top, Spacing.s2)
        }
        .cardStyle(radius: Radius.lg, padding: Spacing.s4)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private func splitCard(projects: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("✌️").font(.system(size: 36))
            Text("looks like two projects.")
                .font(.fraunces(size: 22, weight: 500, opsz: 22, soft: 60))
                .foregroundStyle(palette.fg1)
            Text("rename this one and create the other separately?")
                .font(.geist(size: 14, weight: 400))
                .foregroundStyle(palette.fg3)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(projects, id: \.self) { p in
                    HStack(spacing: 8) {
                        Circle().fill(palette.primary).frame(width: 6, height: 6)
                        Text(p)
                            .font(.geist(size: 14, weight: 500))
                            .foregroundStyle(palette.fg1)
                    }
                }
            }
            .padding(.top, 4)
            Button("Got it", action: closeSheet)
                .buttonStyle(.ploot(.primary, size: .sm))
                .padding(.top, Spacing.s2)
        }
        .cardStyle(radius: Radius.lg, padding: Spacing.s4)
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

    private func runStream(title: String, answers: [BreakdownAnswer]) {
        streamTask?.cancel()
        streamTask = Task { @MainActor in
            do {
                for try await event in BreakdownService.stream(title: title, answers: answers) {
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

        case .task(let order, let emoji, let title):
            if case .thinking = phase {
                withAnimation(Motion.spring) { phase = .streamingTasks }
            } else if case .asking = phase {
                withAnimation(Motion.spring) {
                    pendingQuestion = nil
                    phase = .streamingTasks
                }
            }
            let taskId = insertTask(emoji: emoji, title: title, order: order)
            let streamed = StreamedTask(
                order: order,
                emoji: emoji,
                title: title,
                taskId: taskId
            )
            withAnimation(Motion.spring) {
                streamedTasks.append(streamed)
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
                withAnimation(Motion.spring) { phase = .finished }
                pulseDoneButton()
            }

        case .error(let code):
            withAnimation(Motion.spring) {
                phase = .error(code: code, recoverable: true)
            }
        }
    }

    // MARK: - Answer handling

    private func handleAnswer(questionText: String, answer: String) {
        let newAnswers = answers + [BreakdownAnswer(q: questionText, a: answer)]
        withAnimation(Motion.spring) {
            answers = newAnswers
            pendingQuestion = nil
            phase = .thinking
        }
        runStream(title: project.name, answers: newAnswers)
    }

    // MARK: - SwiftData insert

    /// Timeline model: ONLY the first task (order=0) goes into Today with
    /// a dueDate stamped for this morning. The rest go into `.later` with
    /// no dueDate — they live in the project, invisible in Today, until
    /// the user completes the one in motion (see ProjectTaskPromoter,
    /// which promotes the next .later task when one completes).
    ///
    /// createdAt ordering: streamed tasks arrive 60ms apart, so task 0
    /// has the earliest createdAt and task N the latest. But Today
    /// screen sorts by createdAt DESC, which flips the visible order.
    /// To preserve the AI's intended order under a DESC sort, we backdate
    /// each task by `order × 1ms` so task 0 is the newest (appears
    /// first) and task N is the oldest (appears last).
    @discardableResult
    private func insertTask(emoji: String, title: String, order: Int) -> UUID {
        let composed = "\(emoji) \(title)"
        let isFirst = order == 0
        let section: TaskSection = isFirst ? .today : .later
        let dueDate: Date? = isFirst ? Self.todayMorning() : nil
        let task = PlootTask(
            title: composed,
            dueDate: dueDate,
            projectId: project.id,
            section: section,
            remindMe: isFirst
        )
        // Stamp createdAt so DESC sort preserves AI task order.
        task.createdAt = baseCreatedAt.addingTimeInterval(-Double(order) * 0.001)
        task.updatedAt = task.createdAt
        modelContext.insert(task)
        try? modelContext.save()
        if isFirst {
            ReminderService.shared.schedule(for: task)
        }
        SyncService.shared.push(task: task)
        return task.id
    }

    private static func todayMorning() -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return cal.date(byAdding: .hour, value: 9, to: start) ?? start
    }

    private func removeStreamedTask(_ streamed: StreamedTask) {
        // Soft-delete the real row so sync knows it's gone and the project
        // stops showing it. Then drop it from the sheet with a spring.
        let taskId = streamed.taskId
        let descriptor = FetchDescriptor<PlootTask>(
            predicate: #Predicate { $0.id == taskId }
        )
        if let task = try? modelContext.fetch(descriptor).first {
            task.softDelete()
            try? modelContext.save()
        }
        withAnimation(Motion.spring) {
            streamedTasks.removeAll { $0.id == streamed.id }
            completedCount = max(0, completedCount - 1)
        }
    }

    private func pulseDoneButton() {
        withAnimation(Motion.spring) { donePulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(Motion.spring) { donePulse = false }
        }
    }

    // MARK: - Hint action

    private func addAsSingleTask() {
        // User accepted the "this is a task, not a project" hint. Add the
        // project title as a single task inside this project and close.
        let task = PlootTask(
            title: project.name,
            projectId: project.id,
            section: .today
        )
        modelContext.insert(task)
        try? modelContext.save()
        SyncService.shared.push(task: task)
        closeSheet()
    }

    // MARK: - Helpers

    private func closeSheet() {
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
    var canFinish: Bool {
        switch self {
        case .thinking, .asking: return false
        case .streamingTasks, .finished, .hint, .split, .refused, .error, .rateLimited:
            return true
        }
    }
}
