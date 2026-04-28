import SwiftUI
import SwiftData

/// "Calm capture" task sheet.
///
/// Two tiers:
///   * Tier 1 (medium detent) — title-first capture. Three meta pills below
///     (date, project, more), a "+ note" and "+ break it down" affordance.
///     Designed so the 80% path is "type, glance at pills, save."
///   * Tier 2 (large detent) — adds priority, repeat, and remind-me. Reveals
///     when the user taps the more-pill or drags the sheet up. Editing an
///     existing task opens straight at Tier 2.
///
/// NLP cues in the title fill the pills automatically (Todoist-style):
/// "tomorrow", "5pm", "urgent" / "!!", "@projectname" all silently bind
/// state and pulse the affected pill. Once the user taps a pill, that
/// field becomes user-set and NLP stops overwriting it.
///
/// Section views (title, meta row, pills, inline pickers, subtasks,
/// Tier 2 details) live in QuickAddSheet+Views.swift; state setters,
/// NLP parser, and submit logic live in QuickAddSheet+Logic.swift.
/// State below is internal-access (no `private`) so the cross-file
/// extensions can read/write it.
struct QuickAddSheet: View {
    let existingTask: PlootTask?
    let initialProjectId: String?
    /// Pre-fill the date pill when creating a new task (e.g. from
    /// Calendar with a specific day selected). Ignored when
    /// `existingTask` is set.
    let initialDueDate: Date?
    var onClose: () -> Void

    @Environment(\.plootPalette) var palette
    @Environment(\.modelContext) var modelContext
    // Live projects only. Tombstones (deletedAt != nil) shouldn't be
    // pickable as a destination, NLP shouldn't @mention-match against
    // them, and currentProject's display lookup shouldn't latch on to
    // a deleted row's name.
    @Query(
        filter: #Predicate<PlootProject> { $0.deletedAt == nil },
        sort: \PlootProject.order
    ) var allProjects: [PlootProject]

    // MARK: - Field state

    @State var title: String
    @State var note: String
    @State var projectId: String
    @State var priority: Priority
    @State var due: DueOption
    /// Overrides `due` when the user picks a specific calendar date that
    /// doesn't fit the coarse buckets. Preserves arbitrary dueDates across
    /// an edit cycle (the previous design silently dropped them).
    @State var customDate: Date?
    @State var time: String?
    @State var remindMe: Bool
    @State var repeats: RepeatOption
    @State var subtasks: [Subtask]
    @State var subInput: String = ""

    // MARK: - UI state

    @State var showNote: Bool
    @State var showSubtasks: Bool
    @State var datePickerOpen: Bool = false
    @State var projectPickerOpen: Bool = false
    @State var fullCalendarOpen: Bool = false

    // NLP override flags — stop auto-fill once the user has manually set a
    // field. Edits start with these true so we don't trample existing values.
    @State var dateUserSet: Bool
    @State var priorityUserSet: Bool
    @State var projectUserSet: Bool

    // Pulse triggers — bumped (incremented) to spring-scale the matching pill
    // when NLP or a user tap commits a value.
    @State var datePulse: Int = 0
    @State var projectPulse: Int = 0

    @State var placeholderIndex: Int = Int.random(in: 0..<placeholders.count)
    @FocusState var titleFocused: Bool
    @FocusState var noteFocused: Bool

    init(
        existingTask: PlootTask? = nil,
        initialProjectId: String? = nil,
        initialDueDate: Date? = nil,
        onClose: @escaping () -> Void
    ) {
        self.existingTask = existingTask
        self.initialProjectId = initialProjectId
        self.initialDueDate = initialDueDate
        self.onClose = onClose

        let isEditing = existingTask != nil
        // Editing wins; otherwise honor the caller's initialDueDate hint
        // (e.g. Calendar passed in the selected day). Otherwise default
        // to today's bucket.
        let seedDate: Date? = existingTask?.dueDate ?? initialDueDate
        let parsedDue = DueOption.fromDate(seedDate)
        // If the seed didn't fit a bucket, stash the real date in
        // customDate so it survives.
        let initialCustom: Date?
        if let seed = seedDate, parsedDue == .someday {
            initialCustom = seed
        } else {
            initialCustom = nil
        }

        _title = State(initialValue: existingTask?.title ?? "")
        _note = State(initialValue: existingTask?.note ?? "")
        _projectId = State(initialValue: existingTask?.projectId ?? initialProjectId ?? "inbox")
        _priority = State(initialValue: existingTask?.priority ?? .normal)
        _due = State(initialValue: parsedDue)
        _customDate = State(initialValue: initialCustom)
        _time = State(initialValue: Self.extractTimeSlot(from: seedDate))
        _remindMe = State(initialValue: existingTask?.remindMe ?? false)
        _repeats = State(initialValue: RepeatOption.fromStored(existingTask?.repeats))
        let initialSubs = existingTask?.subtasks
            .filter(\.isLive)
            .sorted { $0.order < $1.order } ?? []
        _subtasks = State(initialValue: initialSubs)

        _showNote = State(initialValue: !(existingTask?.note?.isEmpty ?? true))
        _showSubtasks = State(initialValue: !initialSubs.isEmpty)

        // Mark fields user-set so NLP doesn't overwrite them on title
        // edits. Editing → all populated fields are sticky. New task
        // with an initialDueDate hint → date is sticky too (the user
        // already committed to "this day" by tapping the cell).
        _dateUserSet = State(initialValue: isEditing
                              ? existingTask?.dueDate != nil
                              : initialDueDate != nil)
        _priorityUserSet = State(initialValue: isEditing && (existingTask?.priority ?? .normal) != .normal)
        _projectUserSet = State(initialValue: isEditing && existingTask?.projectId != nil)
    }

    private static func extractTimeSlot(from date: Date?) -> String? {
        guard let date else { return nil }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        if hour == 0 && minute == 0 { return nil }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }

    static let placeholders = [
        "Water the mysterious plant",
        "Finally reply to that email",
        "Outline the Q3 pitch deck",
        "Touch grass",
        "Fold the laundry (yes, today)",
        "Call mom — she misses you"
    ]


    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            grabber
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    titleSection
                    metaRow
                    inlinePickerArea
                    subtaskArea
                    detailsCard
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s2)
                .padding(.bottom, Spacing.s6)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(palette.bg)
        .overlay(alignment: .top) {
            RoundedCornersTopBorder()
                .stroke(palette.borderInk, lineWidth: 2)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedCornersTopShape())
        // Single .large detent — swipe-down dismisses directly without
        // a half-way stop. iOS auto-expands for the keyboard anyway, so
        // a smaller intermediate detent only added a dead-zone detour.
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        .contentShape(Rectangle())
        .onTapGesture {
            if datePickerOpen || projectPickerOpen {
                withAnimation(Motion.spring) {
                    datePickerOpen = false
                    projectPickerOpen = false
                }
            }
        }
        .animation(Motion.spring, value: datePickerOpen)
        .animation(Motion.spring, value: projectPickerOpen)
        .animation(Motion.spring, value: showNote)
        .animation(Motion.spring, value: showSubtasks)
        .onAppear {
            if existingTask == nil { titleFocused = true }
        }
        .onChange(of: title) { _, newVal in
            // axis: .vertical TextFields insert "\n" on return instead of
            // firing onSubmit. Treat return as "I'm done typing" — strip
            // the newline and drop the keyboard so the meta pills + Save
            // are reachable.
            if newVal.contains("\n") {
                title = newVal.replacingOccurrences(of: "\n", with: "")
                titleFocused = false
                return
            }
            applyNLP(from: newVal)
        }
        .sheet(isPresented: $fullCalendarOpen) {
            DatePickerSheet(initialDate: customDate ?? due.date(timeSlot: nil) ?? Date()) { picked in
                setCustomDate(picked)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }

    // MARK: - Header

    private var grabber: some View {
        Capsule()
            .fill(palette.borderStrong)
            .frame(width: 44, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 8)
    }

    private var topBar: some View {
        let canSave = !title.trimmingCharacters(in: .whitespaces).isEmpty
        return HStack {
            Button("Cancel", action: onClose)
                .font(.geist(size: 15, weight: 500))
                .foregroundStyle(palette.fg2)

            Spacer()

            Text(existingTask == nil ? "New task" : "Edit task")
                .font(.fraunces(size: 18, weight: 600, soft: 80))
                .tracking(-0.015 * 18)
                .foregroundStyle(palette.fg1)

            Spacer()

            Button("Save", action: submit)
                .buttonStyle(PlootButtonStyle(variant: .primary, size: .sm))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s2)
    }
}
