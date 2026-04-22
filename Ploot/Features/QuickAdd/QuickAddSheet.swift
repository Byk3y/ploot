import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    var onClose: () -> Void

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var note: String = ""
    @State private var projectId: String = "inbox"
    @State private var priority: Priority = .normal
    @State private var due: DueOption = .today
    @State private var time: String? = nil
    @State private var remindMe: Bool = false
    @State private var repeats: RepeatOption = .never
    @State private var subtasks: [Subtask] = []
    @State private var subInput: String = ""
    @State private var focusedSection: FocusedSection? = nil
    @State private var placeholderIndex: Int = Int.random(in: 0..<placeholders.count)
    @FocusState private var titleFocused: Bool

    private static let placeholders = [
        "Water the mysterious plant",
        "Finally reply to that email",
        "Outline the Q3 pitch deck",
        "Touch grass",
        "Fold the laundry (yes, today)",
        "Call mom — she misses you"
    ]

    private let timeSlots = ["8:00 AM", "9:00 AM", "10:00 AM", "12:00 PM", "2:00 PM", "5:00 PM"]

    var body: some View {
        VStack(spacing: 0) {
            grabber
            topBar
            ScrollView {
                VStack(spacing: Spacing.s3) {
                    titleCard
                    SettingBlock(icon: "calendar", label: "When", value: dueValueText) {
                        dueButtons
                        Divider().background(palette.border).padding(.vertical, Spacing.s3)
                        timeSlotsRow
                    }
                    projectPicker
                    SettingBlock(icon: "flag", label: "Priority", value: priorityValueText) {
                        priorityButtons
                    }
                    reminderRepeatCard
                    subtasksCard
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s1)
                .padding(.bottom, Spacing.s6)
            }
        }
        .background(palette.bg)
        .overlay(alignment: .top) {
            RoundedCornersTopBorder()
                .stroke(palette.borderInk, lineWidth: 2)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedCornersTopShape())
        .onAppear { titleFocused = true }
    }

    // MARK: - Header

    private var grabber: some View {
        Capsule()
            .fill(palette.borderStrong)
            .frame(width: 44, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 10)
    }

    private var topBar: some View {
        HStack {
            Button("Cancel", action: onClose)
                .font(.geist(size: 15, weight: 500))
                .foregroundStyle(palette.fg2)

            Spacer()

            Text("New task")
                .font(.fraunces(size: 20, weight: 600, soft: 80))
                .tracking(-0.015 * 20)
                .foregroundStyle(palette.fg1)

            Spacer()

            Button("Save", action: submit)
                .buttonStyle(PlootButtonStyle(variant: .primary, size: .sm))
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s3)
    }

    // MARK: - Title + note card

    private var titleCard: some View {
        let focused = focusedSection == .title || titleFocused
        return VStack(alignment: .leading, spacing: Spacing.s2) {
            TextField(
                Self.placeholders[placeholderIndex],
                text: $title,
                axis: .vertical
            )
            .focused($titleFocused)
            .font(.fraunces(size: 24, weight: 500, soft: 50))
            .tracking(-0.015 * 24)
            .foregroundStyle(palette.fg1)
            .lineLimit(1...4)

            TextField("Add a note...", text: $note, axis: .vertical)
                .font(.geist(size: 14, weight: 400))
                .foregroundStyle(palette.fg2)
                .lineLimit(1...3)
                .padding(.top, Spacing.s1)

            if !nlpHints.isEmpty {
                Divider().background(palette.border).padding(.vertical, Spacing.s2)
                HStack(spacing: 6) {
                    Text("I picked up:")
                        .font(.jetBrainsMono(size: 10, weight: 600))
                        .tracking(10 * 0.08)
                        .textCase(.uppercase)
                        .foregroundStyle(palette.fg3)
                    ForEach(nlpHints) { hint in
                        Chip(text: hint.label, color: hint.chipColor, icon: hint.icon)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(focused ? palette.borderInk : palette.border, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.borderInk)
                .offset(y: focused ? 2 : 0)
                .opacity(focused ? 1 : 0)
        )
        .offset(y: focused ? -1 : 0)
        .animation(Motion.easeOut(duration: 0.14), value: focused)
        .onTapGesture { titleFocused = true }
    }

    // MARK: - Date picker

    private var dueButtons: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(DueOption.allCases) { option in
                StampPillButton(
                    systemImage: option.icon,
                    label: option.label,
                    active: due == option
                ) {
                    due = option
                }
            }
        }
    }

    private var timeSlotsRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: 4) {
                Text("Pick a time")
                    .font(.jetBrainsMono(size: 10, weight: 600))
                    .tracking(10 * 0.08)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.fg3)
                Text("· optional")
                    .font(.jetBrainsMono(size: 10, weight: 500))
                    .foregroundStyle(palette.fg3.opacity(0.7))
            }
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(timeSlots, id: \.self) { slot in
                    TimePillButton(
                        label: slot,
                        active: time == slot
                    ) {
                        time = (time == slot) ? nil : slot
                    }
                }
            }
        }
    }

    // MARK: - Project picker

    private var projectPicker: some View {
        ProjectPicker(
            selection: $projectId,
            isOpen: Binding(
                get: { focusedSection == .project },
                set: { focusedSection = $0 ? .project : nil }
            )
        )
    }

    // MARK: - Priority picker

    private var priorityButtons: some View {
        HStack(spacing: Spacing.s2) {
            ForEach(Priority.allCases) { p in
                PriorityTile(priority: p, active: priority == p) {
                    priority = p
                }
            }
        }
    }

    // MARK: - Reminder + repeat

    private var reminderRepeatCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.fg2)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me")
                        .font(.geist(size: 14, weight: 600))
                        .foregroundStyle(palette.fg1)
                    Text(remindMe ? "\(time ?? "9:00 AM"), day-of" : "We won't nag you")
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                }
                Spacer()
                PlootToggle(isOn: $remindMe)
            }

            Divider().background(palette.border).padding(.vertical, Spacing.s3)

            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.fg2)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Repeats")
                        .font(.geist(size: 14, weight: 600))
                        .foregroundStyle(palette.fg1)
                    Text(repeats == .never ? "Just this once" : repeats.rawValue.capitalized)
                        .font(.geist(size: 12, weight: 400))
                        .foregroundStyle(palette.fg3)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(RepeatOption.allCases) { opt in
                    Button {
                        repeats = opt
                    } label: {
                        Text(opt.rawValue.capitalized)
                            .font(.geist(size: 12, weight: 600))
                            .foregroundStyle(repeats == opt ? palette.fgInverse : palette.fg2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(repeats == opt ? palette.borderInk : palette.bgSunken)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Spacing.s2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 2)
        )
    }

    // MARK: - Subtasks

    private var subtasksCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "checklist")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.fg2)
                    .frame(width: 18)
                Text("Break it down")
                    .font(.geist(size: 14, weight: 600))
                    .foregroundStyle(palette.fg1)
                Spacer()
                if !subtasks.isEmpty {
                    Text("\(subtasks.count) step\(subtasks.count == 1 ? "" : "s")")
                        .font(.jetBrainsMono(size: 11, weight: 600))
                        .foregroundStyle(palette.fg3)
                }
            }
            .padding(.bottom, subtasks.isEmpty ? 0 : Spacing.s2)

            ForEach(subtasks) { sub in
                HStack(spacing: 10) {
                    Circle()
                        .strokeBorder(palette.borderStrong, lineWidth: 2)
                        .frame(width: 16, height: 16)
                    Text(sub.title)
                        .font(.geist(size: 14, weight: 400))
                        .foregroundStyle(palette.fg1)
                    Spacer()
                    Button {
                        withAnimation(Motion.springFast) {
                            subtasks.removeAll { $0.id == sub.id }
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(palette.fg3)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(palette.bgSunken))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, Spacing.s2)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(palette.border).frame(height: 1)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.fg3)
                TextField("Add a step", text: $subInput)
                    .font(.geist(size: 14, weight: 400))
                    .foregroundStyle(palette.fg1)
                    .onSubmit { addSubtask() }
                if !subInput.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: addSubtask)
                        .font(.geist(size: 11, weight: 700))
                        .tracking(11 * 0.04)
                        .textCase(.uppercase)
                        .foregroundStyle(palette.onPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(palette.primary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(palette.borderInk, lineWidth: 1.5)
                        )
                        .buttonStyle(.plain)
                }
            }
            .padding(.top, subtasks.isEmpty ? Spacing.s2 : Spacing.s1)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 2)
        )
    }

    // MARK: - Actions

    private func addSubtask() {
        let trimmed = subInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation(Motion.springFast) {
            subtasks.append(Subtask(title: trimmed, order: subtasks.count))
        }
        subInput = ""
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let dueLabel: String? = {
            var label = due.label
            if let time { label += ", \(time)" }
            return label
        }()
        let task = PlootTask(
            title: trimmed,
            note: note.isEmpty ? nil : note,
            due: dueLabel,
            projectId: projectId == "inbox" ? nil : projectId,
            priority: priority,
            subtasks: subtasks,
            section: .today,
            repeats: repeats == .never ? nil : repeats.rawValue
        )
        modelContext.insert(task)
        try? modelContext.save()
        onClose()
    }

    // MARK: - Computed display values

    private var dueValueText: String {
        due.label + (time.map { " · \($0)" } ?? "")
    }

    private var priorityValueText: String {
        priority.label + (priority.emoji.isEmpty ? "" : " \(priority.emoji)")
    }

    private var nlpHints: [NLPHint] {
        var hints: [NLPHint] = []
        let lower = title.lowercased()
        if lower.range(of: "\\btomorrow\\b", options: .regularExpression) != nil {
            hints.append(NLPHint(label: "tomorrow", icon: "calendar", chipColor: .clay))
        } else if lower.range(of: "\\btoday\\b", options: .regularExpression) != nil {
            hints.append(NLPHint(label: "today", icon: "calendar", chipColor: .clay))
        } else if lower.range(of: "\\b(mon|tue|wed|thu|fri|sat|sun)", options: .regularExpression) != nil {
            hints.append(NLPHint(label: "day", icon: "calendar", chipColor: .clay))
        }
        if lower.range(of: "\\burgent\\b|!!!", options: .regularExpression) != nil {
            hints.append(NLPHint(label: "urgent", icon: "flame", chipColor: .plum))
        }
        if lower.contains("@work") {
            hints.append(NLPHint(label: "Work", icon: "folder", chipColor: .sky))
        }
        if lower.contains("@home") {
            hints.append(NLPHint(label: "Home", icon: "folder", chipColor: .sky))
        }
        return hints
    }

    // MARK: - Types

    private enum FocusedSection: Hashable { case title, project }
}

// MARK: - Due & repeat enums

enum DueOption: String, CaseIterable, Identifiable {
    case today, tomorrow, weekend, nextweek, someday

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:    return "Today"
        case .tomorrow: return "Tomorrow"
        case .weekend:  return "Weekend"
        case .nextweek: return "Next week"
        case .someday:  return "Someday"
        }
    }

    var icon: String {
        switch self {
        case .today:    return "sun.max"
        case .tomorrow: return "sunrise"
        case .weekend:  return "cup.and.saucer"
        case .nextweek: return "calendar.badge.clock"
        case .someday:  return "infinity"
        }
    }
}

enum RepeatOption: String, CaseIterable, Identifiable {
    case never, daily, weekly, monthly
    var id: String { rawValue }
}

// MARK: - Subviews

private struct NLPHint: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let chipColor: ChipColor
}

private struct StampPillButton: View {
    var systemImage: String
    var label: String
    var active: Bool
    var onTap: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.geist(size: 13, weight: 600))
            }
            .foregroundStyle(active ? palette.onPrimary : palette.fg1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? palette.primary : palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        active ? palette.borderInk : palette.border,
                        lineWidth: 2
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.borderInk)
                    .offset(y: active ? 2 : 0)
                    .opacity(active ? 1 : 0)
            )
            .offset(y: active ? -1 : 0)
        }
        .buttonStyle(.plain)
        .animation(Motion.springFast, value: active)
    }
}

private struct TimePillButton: View {
    var label: String
    var active: Bool
    var onTap: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.jetBrainsMono(size: 12, weight: 600))
                .foregroundStyle(active ? palette.fgInverse : palette.fg1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(active ? palette.borderInk : palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(
                            active ? palette.borderInk : palette.border,
                            lineWidth: 1.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PriorityTile: View {
    var priority: Priority
    var active: Bool
    var onTap: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .strokeBorder(ringColor, lineWidth: 2.5)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(priority == .urgent && active ? palette.primary : .clear)
                        )
                    if !priority.emoji.isEmpty {
                        Text(priority.emoji)
                            .font(.system(size: 12))
                            .offset(x: 10, y: -10)
                    }
                }
                Text(priority.label)
                    .font(.geist(size: 11, weight: 600))
                    .foregroundStyle(active ? palette.fg1 : palette.fg2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        active ? palette.borderInk : palette.border,
                        lineWidth: 2
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.borderInk)
                    .offset(y: active ? 2 : 0)
                    .opacity(active ? 1 : 0)
            )
            .offset(y: active ? -1 : 0)
        }
        .buttonStyle(.plain)
        .animation(Motion.springFast, value: active)
    }

    private var ringColor: Color {
        switch priority {
        case .normal: return palette.borderStrong
        case .medium: return palette.butter500
        case .high:   return palette.plum500
        case .urgent: return palette.primary
        }
    }
}

private struct SettingBlock<Content: View>: View {
    var icon: String
    var label: String
    var value: String
    @ViewBuilder var content: () -> Content

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.fg2)
                    .frame(width: 18)
                Text(label)
                    .font(.geist(size: 14, weight: 600))
                    .foregroundStyle(palette.fg1)
                Spacer()
                Text(value)
                    .font(.geist(size: 13, weight: 500))
                    .foregroundStyle(palette.fg2)
            }
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 2)
        )
    }
}

/// Compact inline project picker: header shows current selection, tapping
/// expands a searchable vertical list. Scales cleanly from 3 to 30 projects.
private struct ProjectPicker: View {
    @Binding var selection: String
    @Binding var isOpen: Bool

    @Query(sort: \PlootProject.order) private var projects: [PlootProject]
    @State private var query: String = ""
    @Environment(\.plootPalette) private var palette

    private var allOptions: [PlootProject] {
        [DemoData.inboxProject] + projects
    }

    private var current: PlootProject {
        allOptions.first { $0.id == selection } ?? DemoData.inboxProject
    }

    private var filtered: [PlootProject] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? allOptions : allOptions.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isOpen {
                expanded
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(isOpen ? palette.borderInk : palette.border, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.borderInk)
                .offset(y: isOpen ? 2 : 0)
                .opacity(isOpen ? 1 : 0)
        )
        .offset(y: isOpen ? -1 : 0)
        .animation(Motion.easeOut(duration: 0.14), value: isOpen)
        .clipped()
    }

    private var header: some View {
        Button {
            isOpen.toggle()
            if !isOpen { query = "" }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.fg2)
                    .frame(width: 18)
                Text("Project")
                    .font(.geist(size: 14, weight: 600))
                    .foregroundStyle(palette.fg1)
                Spacer()
                HStack(spacing: 6) {
                    Text(current.emoji)
                        .font(.system(size: 11))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(current.tileColor.fill(palette: palette)))
                    Text(current.name)
                        .font(.geist(size: 13, weight: 500))
                        .foregroundStyle(palette.fg1)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
                .padding(.trailing, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(palette.bgSunken)
                )
                .overlay(
                    Capsule().strokeBorder(palette.border, lineWidth: 1.5)
                )

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.fg3)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .animation(Motion.spring, value: isOpen)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var expanded: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.fg3)
                TextField("Search or type to create", text: $query)
                    .font(.geist(size: 13, weight: 400))
                    .foregroundStyle(palette.fg1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(palette.bgSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 1.5)
            )

            VStack(spacing: 2) {
                ForEach(filtered) { project in
                    Button {
                        selection = project.id
                        isOpen = false
                        query = ""
                    } label: {
                        HStack(spacing: 10) {
                            Text(project.emoji)
                                .font(.system(size: 13))
                                .frame(width: 26, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(project.tileColor.fill(palette: palette))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(palette.borderInk, lineWidth: 1.5)
                                )
                            Text(project.name)
                                .font(.geist(size: 14, weight: selection == project.id ? 600 : 500))
                                .foregroundStyle(selection == project.id ? palette.clay700 : palette.fg1)
                            Spacer()
                            if selection == project.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(palette.clay700)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(selection == project.id ? palette.clay100 : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if filtered.isEmpty && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Create \"\(query)\"")
                            .font(.geist(size: 13, weight: 500))
                            .foregroundStyle(palette.fg2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(palette.bgSunken)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .strokeBorder(
                                palette.borderStrong,
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                            )
                    )
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(10)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.border).frame(height: 1.5)
        }
    }
}

// MARK: - Top-rounded sheet shape

private struct RoundedCornersTopShape: Shape {
    var radius: CGFloat = 28
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct RoundedCornersTopBorder: Shape {
    var radius: CGFloat = 28
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}
