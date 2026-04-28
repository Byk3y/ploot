import SwiftUI
import SwiftData

/// Month-grid calendar. Top: month navigation (prev / next / today
/// shortcut). Middle: a 7×6 grid of day cells with density dots showing
/// how many open tasks are scheduled that day. Bottom: live task list
/// for the selected day, using the same TaskRow as Today / Done.
///
/// First-of-week is Monday so M T W T F S S reads as a work-then-rest
/// arc — matches the Done screen's weekly dot row and the brand's
/// "weekend is a destination" copy.
struct CalendarScreen: View {
    /// Bound to HomeView's `calendarSelected` so the root FAB can
    /// pre-fill new tasks with whichever day the user is browsing.
    @Binding var selected: Date

    @Query(sort: \PlootTask.createdAt, order: .reverse) private var allTasks: [PlootTask]
    @Query(sort: \PlootProject.order) private var projects: [PlootProject]
    /// First-of-month for whichever month is currently visible. Driven
    /// by the chevrons; selecting a day in a different month also slides
    /// this to follow.
    @State private var monthAnchor: Date = {
        let cal = Calendar.current
        let comp = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comp) ?? Date()
    }()
    /// Compact (single week strip) by default; expanded shows the full
    /// 6-week month grid. Tap the month label to toggle.
    @State private var monthExpanded: Bool = false
    @State private var openTask: PlootTask? = nil
    @State private var editingTask: PlootTask? = nil
    @State private var deletingTask: PlootTask? = nil

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    private static let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private static let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 0), count: 7
    )

    var body: some View {
        ScreenFrame(
            title: "Calendar",
            subtitle: "Plan the shape of your week."
        ) {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                    daySection
                    Color.clear.frame(height: 120)
                }
            }
        }
        .navigationDestination(item: $openTask) { task in
            TaskDetailScreen(task: task)
                .navigationBarBackButtonHidden()
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $editingTask) { task in
            QuickAddSheet(existingTask: task, onClose: { editingTask = nil })
        }
        .alert("Delete this task?", isPresented: .init(
            get: { deletingTask != nil },
            set: { if !$0 { deletingTask = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingTask = nil }
            Button("Delete", role: .destructive) {
                if let task = deletingTask {
                    ReminderService.shared.cancel(for: task)
                    withAnimation(Motion.spring) {
                        task.softDelete()
                        try? modelContext.save()
                    }
                }
                deletingTask = nil
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack(spacing: Spacing.s3) {
            chevronButton(systemImage: "chevron.left") { step(-1) }

            // Tappable month label — expands or collapses the grid.
            // Small chevron next to the name signals the affordance and
            // the current state.
            Button {
                withAnimation(Motion.spring) { monthExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(monthName(for: monthAnchor))
                        .font(.fraunces(size: 22, weight: 600, opsz: 22, soft: 60))
                        .tracking(-0.01 * 22)
                        .foregroundStyle(palette.fg1)
                    Image(systemName: monthExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(palette.fg3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .plootHaptic(.selection, trigger: monthExpanded)

            if !isCurrentRange {
                Button(action: jumpToToday) {
                    Text("Today")
                        .font(.geist(size: 12, weight: 600))
                        .foregroundStyle(palette.fgBrand)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(palette.clay100))
                        .overlay(Capsule().strokeBorder(palette.clay300, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
            chevronButton(systemImage: "chevron.right") { step(1) }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s2)
        .padding(.bottom, Spacing.s3)
    }

    private func chevronButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(palette.fg2)
                .frame(width: 36, height: 36)
                .background(Circle().fill(palette.bgElevated))
                .overlay(Circle().strokeBorder(palette.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .plootHaptic(.selection, trigger: monthAnchor)
    }

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.weekdayLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.jetBrainsMono(size: 11, weight: 600))
                    .foregroundStyle(palette.fg3)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s2)
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        LazyVGrid(columns: Self.columns, spacing: 4) {
            ForEach(visibleDays, id: \.self) { day in
                DayCell(
                    date: day,
                    isInCurrentMonth: isInMonth(day),
                    isToday: Calendar.current.isDateInToday(day),
                    isSelected: Calendar.current.isDate(day, inSameDayAs: selected),
                    openCount: TaskHelpers.openTaskCount(on: day, from: allTasks),
                    onTap: { selectDay(day) }
                )
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s4)
        .animation(Motion.spring, value: monthAnchor)
        .animation(Motion.spring, value: monthExpanded)
    }

    private func selectDay(_ day: Date) {
        withAnimation(Motion.spring) {
            selected = day
            // If the user picked a day from the leading/trailing
            // overflow of the current grid, slide the month anchor too
            // so the next render shows that day's actual month.
            let cal = Calendar.current
            if !cal.isDate(day, equalTo: monthAnchor, toGranularity: .month) {
                let comp = cal.dateComponents([.year, .month], from: day)
                if let newAnchor = cal.date(from: comp) {
                    monthAnchor = newAnchor
                }
            }
        }
    }

    // MARK: - Day section (selected day's task list)

    @ViewBuilder
    private var daySection: some View {
        let dayTasks = TaskHelpers.tasks(on: selected, from: allTasks)
        Section {
            if dayTasks.isEmpty {
                EmptyState(
                    systemImage: "tray",
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
                .padding(.top, Spacing.s2)
            } else {
                ForEach(dayTasks) { task in
                    TaskRow(
                        task: task,
                        project: TaskHelpers.project(id: task.projectId, from: projects),
                        onToggle: { task.setDone($0) },
                        onOpen: { openTask = task },
                        onEdit: { editingTask = task },
                        onDelete: { deletingTask = task },
                        onRescheduleToday: { rescheduleToToday(task) }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
        } header: {
            SectionHeader(title: dayHeaderTitle, count: dayTasks.count)
        }
    }

    // MARK: - Reschedule helper

    /// Mirrors TodayScreen's logic — push forward to today (past-day
    /// overdue) or tomorrow (same-day late) preserving time-of-day.
    private func rescheduleToToday(_ task: PlootTask) {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let isSameDayLate = task.dueDate.map { due in
            cal.isDate(due, inSameDayAs: now) && due < now
        } ?? false
        let targetDay: Date = {
            if isSameDayLate {
                return cal.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
            }
            return startOfToday
        }()
        let newDate: Date
        if let original = task.dueDate {
            let h = cal.component(.hour, from: original)
            let m = cal.component(.minute, from: original)
            newDate = cal.date(bySettingHour: h, minute: m, second: 0, of: targetDay) ?? targetDay
        } else {
            newDate = targetDay
        }
        withAnimation(Motion.spring) {
            task.dueDate = newDate
            task.section = isSameDayLate ? .later : .today
            task.touch()
            try? modelContext.save()
        }
        ReminderService.shared.schedule(for: task)
        SyncService.shared.push(task: task)
    }

    // MARK: - Computed properties

    /// What the grid actually renders — one week (7 cells) when
    /// collapsed, the full 6-week window (42 cells) when expanded.
    private var visibleDays: [Date] {
        monthExpanded ? daysInGrid : weekDays
    }

    /// 42-cell window: starts from the Monday on or before the first of
    /// the visible month, runs forward 6 weeks. Some cells will be in
    /// the previous or next month (rendered dimmed).
    private var daysInGrid: [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        var start = monthAnchor
        while cal.component(.weekday, from: start) != cal.firstWeekday {
            guard let prev = cal.date(byAdding: .day, value: -1, to: start) else { break }
            start = prev
        }
        return (0..<42).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: start)
        }
    }

    /// 7-cell window: the Monday-Sunday week containing the selected
    /// day. Used by the collapsed strip view.
    private var weekDays: [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        var start = selected
        while cal.component(.weekday, from: start) != cal.firstWeekday {
            guard let prev = cal.date(byAdding: .day, value: -1, to: start) else { break }
            start = prev
        }
        return (0..<7).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: start)
        }
    }

    /// "Today" pill is shown when:
    ///   - expanded: viewing a non-current month, OR
    ///   - collapsed: today isn't in the visible week.
    private var isCurrentRange: Bool {
        let cal = Calendar.current
        if monthExpanded {
            return cal.isDate(monthAnchor, equalTo: Date(), toGranularity: .month)
        }
        return weekDays.contains { cal.isDateInToday($0) }
    }

    private func isInMonth(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: monthAnchor, toGranularity: .month)
    }

    private func monthName(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "MMMM"
            : "MMMM yyyy"
        return fmt.string(from: date)
    }

    /// Chevrons step by month when the grid is expanded, by week when
    /// collapsed. Stepping by week without changing the anchor's month
    /// when the new week stays in-month, otherwise sliding the anchor
    /// to follow.
    private func step(_ delta: Int) {
        let cal = Calendar.current
        if monthExpanded {
            guard let newAnchor = cal.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
            withAnimation(Motion.spring) { monthAnchor = newAnchor }
        } else {
            guard let newSelected = cal.date(byAdding: .day, value: delta * 7, to: selected) else { return }
            withAnimation(Motion.spring) {
                selected = newSelected
                if !cal.isDate(newSelected, equalTo: monthAnchor, toGranularity: .month) {
                    let comp = cal.dateComponents([.year, .month], from: newSelected)
                    if let newAnchor = cal.date(from: comp) {
                        monthAnchor = newAnchor
                    }
                }
            }
        }
    }

    private func jumpToToday() {
        let cal = Calendar.current
        let comp = cal.dateComponents([.year, .month], from: Date())
        guard let newAnchor = cal.date(from: comp) else { return }
        withAnimation(Motion.spring) {
            monthAnchor = newAnchor
            selected = Date()
        }
    }

    private var dayHeaderTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selected) { return "Today" }
        if cal.isDateInTomorrow(selected) { return "Tomorrow" }
        if cal.isDateInYesterday(selected) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: selected)
    }

    private var emptyTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selected) { return "Nothing on the list. Suspicious." }
        if selected < cal.startOfDay(for: Date()) { return "Nothing scheduled." }
        return "Wide open."
    }

    private var emptySubtitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selected) {
            return "Take a victory lap — or add the next thing."
        }
        if selected < cal.startOfDay(for: Date()) {
            return "Past days don't haunt you here."
        }
        return "Add a task to fill it in."
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let date: Date
    let isInCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let openCount: Int
    let onTap: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.fraunces(size: 16, weight: weight))
                    .tracking(-0.01 * 16)
                    .foregroundStyle(numberColor)
                densityDots
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(cellBackground)
            .overlay(cellBorder)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .plootHaptic(.selection, trigger: isSelected)
        .animation(Motion.springFast, value: isSelected)
    }

    private var weight: CGFloat {
        if isSelected { return 700 }
        if isToday { return 600 }
        return 500
    }

    private var numberColor: Color {
        if isSelected { return palette.onPrimary }
        if !isInCurrentMonth { return palette.fg3.opacity(0.5) }
        if isToday { return palette.fgBrand }
        return palette.fg1
    }

    @ViewBuilder
    private var cellBackground: some View {
        let radius: CGFloat = 12
        if isSelected {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(palette.primary)
        } else if isToday {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(palette.clay100)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var cellBorder: some View {
        let radius: CGFloat = 12
        if isToday && !isSelected {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(palette.clay300, lineWidth: 1.5)
        }
    }

    /// Up to three small dots reflecting open-task density: 1-2 → 1
    /// dot, 3-5 → 2, 6+ → 3. Done tasks don't count (the goal is
    /// "what's outstanding", not "what was scheduled").
    @ViewBuilder
    private var densityDots: some View {
        if openCount > 0 {
            HStack(spacing: 2) {
                let n = min(3, dotCount(for: openCount))
                ForEach(0..<n, id: \.self) { _ in
                    Circle()
                        .fill(dotColor)
                        .frame(width: 4, height: 4)
                }
            }
        } else {
            Color.clear.frame(height: 4)
        }
    }

    private var dotColor: Color {
        if isSelected { return palette.onPrimary }
        return palette.primary
    }

    private func dotCount(for n: Int) -> Int {
        switch n {
        case 0: return 0
        case 1...2: return 1
        case 3...5: return 2
        default: return 3
        }
    }
}
