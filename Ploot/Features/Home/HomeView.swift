import SwiftUI
import SwiftData

struct HomeView: View {
    @Bindable var session: SessionManager

    @State private var tab: PlootTab = .today
    @State private var quickAddOpen: Bool = false
    @State private var openSettings: Bool = false
    @State private var openTask: PlootTask? = nil
    @State private var openProject: PlootProject? = nil
    @State private var theme: PlootTheme = .light

    // Voice capture
    @State private var speech = SpeechService()
    @State private var voicePhase: VoiceCaptureBubble.Phase? = nil
    @State private var voiceCancelPreview: Bool = false
    @State private var voiceIntentTask: Task<Void, Never>? = nil
    @State private var breakdownProject: PlootProject? = nil
    @State private var voiceToast: String? = nil
    @State private var voiceToastTaskId: UUID? = nil
    @State private var editingTask: PlootTask? = nil
    @State private var permissionExplainerOpen: Bool = false
    @State private var showCancelPill: Bool = false
    @State private var cancelBounceTrigger: Int = 0
    @State private var isCancellingVoice: Bool = false
    @AppStorage("voiceHintSeen") private var voiceHintSeen: Bool = false
    @AppStorage("voicePrimerSeen") private var voicePrimerSeen: Bool = false
    @State private var fabTapCount: Int = 0
    @State private var showVoiceHint: Bool = false

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlootProject.order) private var allProjects: [PlootProject]

    var body: some View {
        NavigationStack {
            tabContent
                .overlay(alignment: .bottomTrailing) {
                    if tab != .projects {
                        fab
                            .padding(.trailing, 20)
                            .padding(.bottom, 12)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .bottomTrailing) { voiceBubbleLayer }
                .overlay(alignment: .bottomTrailing) { voiceCancelPillLayer }
                .overlay(alignment: .bottom) { toastLayer }
                .overlay(alignment: .bottom) { voiceHintLayer }
                .animation(Motion.spring, value: tab)
                .animation(Motion.spring, value: voicePhase)
                .animation(Motion.spring, value: voiceToast)
                .animation(Motion.spring, value: showVoiceHint)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    TabBar(current: $tab)
                }
                .background(palette.bg.ignoresSafeArea())
                .navigationDestination(item: $openTask) { task in
                    TaskDetailScreen(task: task)
                        .navigationBarBackButtonHidden()
                        .toolbar(.hidden, for: .navigationBar)
                        .plootTheme(theme)
                }
                .navigationDestination(item: $openProject) { project in
                    ProjectDetailScreen(project: project)
                        .navigationBarBackButtonHidden()
                        .toolbar(.hidden, for: .navigationBar)
                        .plootTheme(theme)
                }
                .navigationDestination(isPresented: $openSettings) {
                    SettingsScreen(theme: $theme, session: session)
                        .navigationBarBackButtonHidden()
                        .toolbar(.hidden, for: .navigationBar)
                        .plootTheme(theme)
                }
        }
        .plootTheme(theme)
        .sheet(isPresented: $quickAddOpen) {
            QuickAddSheet(onClose: { quickAddOpen = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
                .plootTheme(theme)
        }
        .sheet(item: $editingTask) { task in
            QuickAddSheet(existingTask: task, onClose: { editingTask = nil })
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
                .plootTheme(theme)
        }
        .sheet(item: $breakdownProject) { project in
            BreakdownSheet(project: project, onClose: { breakdownProject = nil })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .plootTheme(theme)
        }
        .sheet(isPresented: $permissionExplainerOpen) {
            VoicePermissionExplainer(
                onEnable: handlePermissionExplainerEnable,
                onDismiss: handlePermissionExplainerDismiss
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .plootTheme(theme)
        }
    }

    // MARK: - FAB

    private var fab: some View {
        FAB(
            action: handleFabTap,
            onLongPressStart: handleVoiceStart,
            onLongPressChanged: { cancel in voiceCancelPreview = cancel },
            onLongPressEnd: handleVoiceEnd
        )
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .today:
            TodayScreen(onOpen: { openTask = $0 }, onOpenSettings: { openSettings = true })
        case .projects:
            ProjectsScreen(onOpenProject: { openProject = $0 })
        case .calendar:
            CalendarScreen()
        case .done:
            DoneScreen(onOpen: { openTask = $0 })
        }
    }

    // MARK: - Voice bubble

    @ViewBuilder
    private var voiceBubbleLayer: some View {
        if let phase = voicePhase {
            VoiceCaptureBubble(
                phase: phase,
                transcript: speech.transcript,
                cancelPreview: voiceCancelPreview,
                onCancel: dismissVoice
            )
            .allowsHitTesting(phase != .listening) // listening: gesture goes to FAB
            .transition(bubbleTransition)
            .zIndex(10)
        }
    }

    /// Bubble enter is a friendly scale-from-bottom-right. Exit depends on
    /// context: a cancel exit shrinks to a point while sliding toward the
    /// cancel pill ("popping into the bin"); a normal exit fades.
    private var bubbleTransition: AnyTransition {
        let insertion: AnyTransition = .scale(scale: 0.85, anchor: .bottomTrailing)
            .combined(with: .opacity)
        let removal: AnyTransition
        if isCancellingVoice {
            removal = .scale(scale: 0.05, anchor: .bottomLeading)
                .combined(with: .opacity)
                .combined(with: .offset(x: -40, y: 40))
        } else {
            removal = .scale(scale: 0.85, anchor: .bottomTrailing)
                .combined(with: .opacity)
        }
        return .asymmetric(insertion: insertion, removal: removal)
    }

    /// Cancel pill sits directly to the LEFT of the FAB while listening.
    /// Stays visible briefly after cancel so the user sees the trash
    /// icon bounce as the bubble shrinks into it.
    @ViewBuilder
    private var voiceCancelPillLayer: some View {
        if showCancelPill {
            VoiceCancelPill(
                cancelPreview: voiceCancelPreview,
                bounceTrigger: cancelBounceTrigger
            )
            // FAB's outer right edge is at trailing padding 20 + width 60 = 80pt.
            // Put 8pt gap between pill and FAB → pill's right edge at 88pt.
            .padding(.trailing, 88)
            // FAB bottom padding 12 + FAB height 60, pill vertically
            // centered relative to FAB → pill bottom at ~12 + 17 = 29pt.
            .padding(.bottom, 29)
            .transition(.scale(scale: 0.85, anchor: .trailing).combined(with: .opacity))
            .zIndex(9)
        }
    }

    // MARK: - Toast (voice success + correction tap)

    @ViewBuilder
    private var toastLayer: some View {
        if let message = voiceToast {
            Button(action: handleToastTap) {
                HStack(spacing: 8) {
                    Text("✨").font(.system(size: 14))
                    Text(message)
                        .font(.geist(size: 13, weight: 500))
                        .foregroundStyle(palette.fg1)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    if voiceToastTaskId != nil {
                        Text("edit")
                            .font(.geist(size: 12, weight: 600))
                            .foregroundStyle(palette.primary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: Radius.md, offset: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.s4)
            .padding(.bottom, 100)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(5)
        }
    }

    // MARK: - First-run voice hint

    @ViewBuilder
    private var voiceHintLayer: some View {
        if showVoiceHint {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.primary)
                Text("hold + to dictate.")
                    .font(.geist(size: 13, weight: 500))
                    .foregroundStyle(palette.fg1)
                Button(action: dismissVoiceHint) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(palette.fg3)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(palette.bgElevated))
            .overlay(Capsule().strokeBorder(palette.borderInk, lineWidth: 1.5))
            .stampedShadow(radius: 999, offset: 2)
            .padding(.bottom, 100)
            .padding(.trailing, 90)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .transition(.scale.combined(with: .opacity))
            .zIndex(6)
        }
    }

    // MARK: - FAB tap handler

    private func handleFabTap() {
        fabTapCount += 1
        if !voiceHintSeen, fabTapCount == 2 {
            withAnimation(Motion.spring) { showVoiceHint = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if showVoiceHint { dismissVoiceHint() }
            }
        }
        quickAddOpen = true
    }

    private func dismissVoiceHint() {
        withAnimation(Motion.spring) { showVoiceHint = false }
        voiceHintSeen = true
    }

    // MARK: - Voice lifecycle

    private func handleVoiceStart() {
        dismissVoiceHint()

        // First-ever voice attempt: show the primer before the system
        // dialog. Doubles the grant rate vs. jumping straight into iOS's
        // permission prompt.
        if !voicePrimerSeen && speech.permissionState == .unknown {
            permissionExplainerOpen = true
            return
        }

        Task {
            if speech.permissionState == .unknown {
                _ = await speech.requestPermissions()
            }
            guard speech.permissionState == .granted else {
                withAnimation(Motion.spring) { voicePhase = .permissionDenied }
                return
            }
            do {
                try speech.start()
                withAnimation(Motion.spring) {
                    voicePhase = .listening
                    showCancelPill = true
                }
            } catch {
                withAnimation(Motion.spring) { voicePhase = .permissionDenied }
            }
        }
    }

    /// The "pop into the bin" cancel animation:
    ///   1. Trigger a symbolEffect bounce on the pill's trash icon so it
    ///      visually "consumes" the deleted content.
    ///   2. Set isCancellingVoice so the bubble uses the shrink-toward-
    ///      pill removal transition.
    ///   3. Set voicePhase = nil — bubble begins its cool shrink-to-bin.
    ///   4. After the bubble is done shrinking (~350ms), fade out the
    ///      pill and reset the cancel flag.
    private func triggerCancelAnimation() {
        cancelBounceTrigger &+= 1
        isCancellingVoice = true
        withAnimation(Motion.spring) { voicePhase = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(Motion.spring) {
                showCancelPill = false
                voiceCancelPreview = false
            }
            isCancellingVoice = false
        }
    }

    private func handlePermissionExplainerEnable() {
        voicePrimerSeen = true
        permissionExplainerOpen = false
        // Let the sheet dismiss animate before firing the system dialog
        // so they don't stack visually.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            Task {
                _ = await speech.requestPermissions()
                // User will long-press again to actually record — we
                // don't auto-start because their finger isn't down.
            }
        }
    }

    private func handlePermissionExplainerDismiss() {
        voicePrimerSeen = true
        permissionExplainerOpen = false
    }

    private func handleVoiceEnd(cancelled: Bool) {
        let transcript = speech.transcript
        speech.stop()

        if cancelled {
            triggerCancelAnimation()
            return
        }

        if transcript.trimmingCharacters(in: .whitespaces).isEmpty {
            dismissVoice()
            return
        }

        // Transcript is going to the LLM. Hide the cancel pill — the
        // commit moment has passed, there's nothing to cancel during
        // thinking.
        withAnimation(Motion.spring) {
            voicePhase = .thinking
            showCancelPill = false
        }

        voiceIntentTask?.cancel()
        voiceIntentTask = Task { @MainActor in
            do {
                let intent = try await IntentService.classify(transcript: transcript)
                handleIntent(intent, originalTranscript: transcript)
            } catch IntentError.rateLimited {
                fallbackToQuickAdd(transcript: transcript, message: "ai limit today. added as-is.")
            } catch IntentError.cancelled {
                return
            } catch {
                fallbackToQuickAdd(transcript: transcript, message: "added as typed.")
            }
        }
    }

    private func dismissVoice() {
        speech.cancel()
        voiceIntentTask?.cancel()
        voiceCancelPreview = false
        withAnimation(Motion.spring) {
            voicePhase = nil
            showCancelPill = false
        }
    }

    // MARK: - Intent routing

    private func handleIntent(_ intent: VoiceIntent, originalTranscript: String) {
        switch intent {
        case .task(let t):
            let task = insertTask(t)
            var label = t.title
            if let due = t.dueDate { label += " · \(Self.shortDate(due))" }
            voiceToast = label
            voiceToastTaskId = task.id
            withAnimation(Motion.spring) { voicePhase = nil }
            scheduleToastDismiss()

        case .tasks(let list):
            for t in list { _ = insertTask(t) }
            voiceToast = "\(list.count) tasks added."
            voiceToastTaskId = nil
            withAnimation(Motion.spring) { voicePhase = nil }
            scheduleToastDismiss()

        case .project(let title):
            let project = insertProject(title: title)
            withAnimation(Motion.spring) { voicePhase = nil }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                breakdownProject = project
            }

        case .ambiguous:
            fallbackToQuickAdd(transcript: originalTranscript, message: nil)
        }
    }

    private func scheduleToastDismiss() {
        let current = voiceToast
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if voiceToast == current {
                withAnimation(Motion.spring) {
                    voiceToast = nil
                    voiceToastTaskId = nil
                }
            }
        }
    }

    private func handleToastTap() {
        defer {
            withAnimation(Motion.spring) {
                voiceToast = nil
                voiceToastTaskId = nil
            }
        }
        guard let taskId = voiceToastTaskId else { return }
        let descriptor = FetchDescriptor<PlootTask>(
            predicate: #Predicate { $0.id == taskId && $0.deletedAt == nil }
        )
        if let task = try? modelContext.fetch(descriptor).first {
            editingTask = task
        }
    }

    // MARK: - SwiftData inserts

    @discardableResult
    private func insertTask(_ t: VoiceTask) -> PlootTask {
        let projectId = resolveProjectSlug(t.projectSlug)
        let priority: Priority = {
            switch t.priority {
            case .urgent: return .urgent
            case .high: return .high
            case .normal, .none: return .normal
            }
        }()
        let task = PlootTask(
            title: t.title,
            dueDate: t.dueDate,
            projectId: projectId,
            priority: priority,
            section: Self.section(for: t.dueDate),
            remindMe: t.dueDate != nil
        )
        modelContext.insert(task)
        try? modelContext.save()
        ReminderService.shared.schedule(for: task)
        SyncService.shared.push(task: task)
        return task
    }

    /// Bucket by due date. Mirrors QuickAddSheet grouping logic.
    private static func section(for dueDate: Date?) -> TaskSection {
        guard let dueDate else { return .today }
        let cal = Calendar.current
        if dueDate < Date().addingTimeInterval(-60) { return .overdue }
        if cal.isDateInToday(dueDate) { return .today }
        return .later
    }

    private func resolveProjectSlug(_ slug: String?) -> String? {
        guard let slug, !slug.isEmpty else { return nil }
        return allProjects.first(where: { $0.id == slug && $0.isLive })?.id
    }

    @discardableResult
    private func insertProject(title: String) -> PlootProject {
        let existingIds = Set(allProjects.map(\.id))
        let slug = Self.generateProjectSlug(from: title, existing: existingIds)
        let nextOrder = (allProjects.map(\.order).max() ?? 0) + 1
        let project = PlootProject(
            id: slug,
            name: title,
            emoji: "✨",
            tileColor: .primary,
            order: nextOrder
        )
        modelContext.insert(project)
        try? modelContext.save()
        SyncService.shared.push(project: project)
        return project
    }

    private static func generateProjectSlug(from name: String, existing: Set<String>) -> String {
        let cleaned = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 -]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " +", with: "-", options: .regularExpression)
        let base = cleaned.isEmpty ? "project" : cleaned
        if !existing.contains(base) && base != "inbox" { return base }
        var n = 2
        while true {
            let candidate = "\(base)-\(n)"
            if !existing.contains(candidate) && candidate != "inbox" { return candidate }
            n += 1
        }
    }

    private static func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInTomorrow(date) { return "tomorrow" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }

    // MARK: - Fallback

    private func fallbackToQuickAdd(transcript: String, message: String?) {
        let truncated = String(transcript.prefix(200))
        let task = PlootTask(title: truncated, section: .today)
        modelContext.insert(task)
        try? modelContext.save()
        SyncService.shared.push(task: task)

        voiceToast = message ?? truncated
        voiceToastTaskId = task.id
        scheduleToastDismiss()
        withAnimation(Motion.spring) { voicePhase = nil }
    }
}
