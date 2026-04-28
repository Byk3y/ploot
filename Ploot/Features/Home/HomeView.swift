import SwiftUI
import SwiftData

/// Root view of the authenticated app. Owns the tab bar + FAB + the
/// permission-explainer / quick-add / breakdown sheets, and drives the
/// voice-capture lifecycle (long-press FAB → record → transcript →
/// IntentService classification). The intent → SwiftData mutation
/// pipeline lives in HomeView+VoiceIntent.swift; the overlay subviews
/// (bubble, cancel pill, toast, hint) live in HomeView+Overlays.swift.
///
/// Properties below are intentionally `internal` (the default) rather
/// than `private` so the cross-file extensions can read/write them.
struct HomeView: View {
    @Bindable var session: SessionManager

    @State var tab: PlootTab = .today
    @State var quickAddOpen: Bool = false
    @State var openSettings: Bool = false
    @State var openTask: PlootTask? = nil
    @State var openProject: PlootProject? = nil
    @State var theme: PlootTheme = .light
    /// CalendarScreen mirrors its selected day here so the FAB can
    /// pre-fill new tasks with the right date when the user is browsing
    /// the calendar.
    @State var calendarSelected: Date = Date()

    // Voice capture
    @State var speech = SpeechService()
    @State var voicePhase: VoiceCaptureBubble.Phase? = nil
    @State var voiceCancelPreview: Bool = false
    @State var voiceIntentTask: Task<Void, Never>? = nil
    @State var breakdownProject: PlootProject? = nil
    @State var voiceToast: String? = nil
    @State var voiceToastTaskId: UUID? = nil
    @State var editingTask: PlootTask? = nil
    @State var permissionExplainerOpen: Bool = false
    @State var showCancelPill: Bool = false
    @State var cancelBounceTrigger: Int = 0
    @State var isCancellingVoice: Bool = false
    @AppStorage("voiceHintSeen") var voiceHintSeen: Bool = false
    @AppStorage("voicePrimerSeen") var voicePrimerSeen: Bool = false
    @State var fabTapCount: Int = 0
    @State var showVoiceHint: Bool = false

    @Environment(\.plootPalette) var palette
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PlootProject.order) var allProjects: [PlootProject]

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
            QuickAddSheet(
                initialDueDate: tab == .calendar ? calendarSelected : nil,
                onClose: { quickAddOpen = false }
            )
            .plootTheme(theme)
        }
        .sheet(item: $editingTask) { task in
            QuickAddSheet(existingTask: task, onClose: { editingTask = nil })
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

    // MARK: - FAB + tab content

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
            CalendarScreen(selected: $calendarSelected)
        case .done:
            DoneScreen(onOpen: { openTask = $0 })
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

    func dismissVoiceHint() {
        withAnimation(Motion.spring) { showVoiceHint = false }
        voiceHintSeen = true
    }

    // MARK: - Voice lifecycle

    private func handleVoiceStart() {
        dismissVoiceHint()

        // Reconcile our cached permission state with iOS before any
        // branching — the @State SpeechService starts at .unknown on
        // every cold launch, which would otherwise force us through the
        // async requestPermissions path and race the user's release.
        speech.refreshPermissionStateFromOS()

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

        // If we never started recording (permission denied), the bubble
        // is showing a sticky message with a Got-it button. Leave it up
        // so the user can read + dismiss it on their own time — auto-
        // dismissing here means the bubble vanishes the instant the
        // finger lifts and they never get to tap anything.
        if voicePhase == .permissionDenied {
            // Hide the cancel pill that came up when we (briefly) thought
            // we'd be listening, but keep voicePhase as-is.
            withAnimation(Motion.spring) { showCancelPill = false }
            voiceCancelPreview = false
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

    func dismissVoice() {
        speech.cancel()
        voiceIntentTask?.cancel()
        voiceCancelPreview = false
        withAnimation(Motion.spring) {
            voicePhase = nil
            showCancelPill = false
        }
    }
}
