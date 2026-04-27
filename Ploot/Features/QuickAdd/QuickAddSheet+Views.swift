import SwiftUI
import SwiftData

// All the section views QuickAddSheet's body composes — title + meta
// row pills + inline pickers + subtask area + Tier 2 details. Pulled
// out of QuickAddSheet.swift so the main file can stay focused on the
// state model, init, and body wiring.

extension QuickAddSheet {

    // MARK: - Title + note

    var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            TextField(
                Self.placeholders[placeholderIndex],
                text: $title,
                axis: .vertical
            )
            .focused($titleFocused)
            .font(.fraunces(size: 26, weight: 500, soft: 50))
            .tracking(-0.015 * 26)
            .foregroundStyle(palette.fg1)
            .lineLimit(1...4)
            .submitLabel(.done)

            if showNote {
                TextField("Note", text: $note, axis: .vertical)
                    .focused($noteFocused)
                    .font(.geist(size: 14, weight: 400))
                    .foregroundStyle(palette.fg2)
                    .lineLimit(1...4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button {
                    showNote = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        noteFocused = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .heavy))
                        Text("note")
                            .font(.geist(size: 12, weight: 600))
                    }
                    .foregroundStyle(palette.fg3)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: showNote)
            }
        }
        .padding(.top, Spacing.s2)
    }

    // MARK: - Meta row

    var metaRow: some View {
        HStack(spacing: Spacing.s2) {
            datePill
            projectPill
            morePill
            Spacer(minLength: 0)
        }
    }

    var datePill: some View {
        let isSet = customDate != nil || due != .someday
        return MetaPill(
            icon: customDate != nil ? "calendar" : (isSet ? due.icon : "calendar"),
            label: dateLabelText,
            highlight: isSet,
            pulseTrigger: datePulse
        ) {
            withAnimation(Motion.spring) {
                if datePickerOpen {
                    datePickerOpen = false
                } else {
                    projectPickerOpen = false
                    datePickerOpen = true
                }
            }
        }
    }

    var projectPill: some View {
        let isUnassigned = projectId == "inbox"
        return MetaPill(
            icon: "folder",
            label: isUnassigned ? "Project" : currentProject.name,
            emoji: isUnassigned ? nil : currentProject.emoji,
            highlight: !isUnassigned,
            pulseTrigger: projectPulse
        ) {
            withAnimation(Motion.spring) {
                if projectPickerOpen {
                    projectPickerOpen = false
                } else {
                    datePickerOpen = false
                    projectPickerOpen = true
                }
            }
        }
    }

    /// Toggles between Tier 1 (compact) and Tier 2 (large). Chevron points
    /// in the direction the sheet will travel: up to expand, down to
    /// collapse. Reads as a directional affordance rather than a generic
    /// "more" menu.
    var morePill: some View {
        Button {
            withAnimation(Motion.spring) {
                detent = detent == .large ? .height(Self.compactDetentHeight) : .large
            }
        } label: {
            Image(systemName: detent == .large ? "chevron.down" : "chevron.up")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(palette.fg2)
                .frame(width: 38, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: detent)
    }

    var dateLabelText: String {
        if let customDate {
            let fmt = DateFormatter()
            fmt.dateFormat = Calendar.current.isDate(customDate, equalTo: Date(), toGranularity: .year)
                ? "EEE, MMM d"
                : "MMM d, yyyy"
            var label = fmt.string(from: customDate)
            if let time { label += " · \(time)" }
            return label
        }
        guard due != .someday else { return "Anytime" }
        if let time { return "\(due.label.lowercased()) · \(time)" }
        return due.label
    }

    var currentProject: PlootProject {
        ([DemoData.inboxProject] + allProjects).first { $0.id == projectId } ?? DemoData.inboxProject
    }

    // MARK: - Inline picker area

    @ViewBuilder
    var inlinePickerArea: some View {
        if datePickerOpen {
            datePickerInline
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
        if projectPickerOpen {
            InlineProjectList(
                selection: projectId,
                onSelect: { id in setProject(id) }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    var datePickerInline: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(DueOption.allCases) { option in
                    QuickDatePill(
                        icon: option.icon,
                        label: option.label,
                        active: customDate == nil && due == option
                    ) {
                        setDue(option)
                    }
                }
                Button {
                    fullCalendarOpen = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Pick a date")
                            .font(.geist(size: 13, weight: 600))
                    }
                    .foregroundStyle(customDate != nil ? palette.onPrimary : palette.fg1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(customDate != nil ? palette.primary : palette.bgSunken)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                customDate != nil ? palette.borderInk : palette.border,
                                style: customDate != nil
                                    ? StrokeStyle(lineWidth: 2)
                                    : StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                            )
                    )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: customDate)
            }

            if customDate != nil || due != .someday {
                Divider().background(palette.border)
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.fg2)
                    Text("Time")
                        .font(.geist(size: 13, weight: 600))
                        .foregroundStyle(palette.fg1)
                    Spacer()
                    if let current = time {
                        Button {
                            withAnimation(Motion.springFast) { time = nil }
                        } label: {
                            HStack(spacing: 4) {
                                Text(current)
                                    .font(.jetBrainsMono(size: 12, weight: 600))
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(palette.onPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(palette.primary)
                            )
                            .overlay(
                                Capsule().strokeBorder(palette.borderInk, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    InlineTimePicker(time: $time)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(palette.borderInk, lineWidth: 2)
        )
        .stampedShadow(radius: Radius.lg, offset: 2)
    }

    // MARK: - Subtasks

    @ViewBuilder
    var subtaskArea: some View {
        if showSubtasks {
            subtaskCard
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            Button {
                showSubtasks = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Break it down")
                        .font(.geist(size: 13, weight: 600))
                }
                .foregroundStyle(palette.fg2)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(palette.bgSunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            palette.border,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                        )
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: showSubtasks)
        }
    }

    var subtaskCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.fg2)
                Text("Steps")
                    .font(.geist(size: 13, weight: 600))
                    .foregroundStyle(palette.fg1)
                Spacer()
                if !subtasks.isEmpty {
                    Text("\(subtasks.count)")
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
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
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
            .padding(.top, Spacing.s1)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1.5)
        )
    }

    // MARK: - Tier 2 details

    var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Details")
                .font(.jetBrainsMono(size: 10, weight: 700))
                .tracking(10 * 0.08)
                .textCase(.uppercase)
                .foregroundStyle(palette.fg3)
                .padding(.bottom, Spacing.s2)

            // Priority
            HStack(spacing: Spacing.s3) {
                Image(systemName: "flag")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.fg2)
                    .frame(width: 18)
                Text("Priority")
                    .font(.geist(size: 14, weight: 600))
                    .foregroundStyle(palette.fg1)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Priority.allCases) { p in
                        PriorityDot(priority: p, active: priority == p) {
                            withAnimation(Motion.springFast) {
                                priority = p
                                priorityUserSet = true
                            }
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.s3)

            Divider().background(palette.border)

            // Repeat
            HStack(spacing: Spacing.s3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.fg2)
                    .frame(width: 18)
                Text("Repeat")
                    .font(.geist(size: 14, weight: 600))
                    .foregroundStyle(palette.fg1)
                Spacer()
                Menu {
                    ForEach(RepeatOption.allCases) { opt in
                        Button(opt.rawValue.capitalized) { repeats = opt }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(repeats == .never ? "Never" : repeats.rawValue.capitalized)
                            .font(.geist(size: 13, weight: 500))
                            .foregroundStyle(palette.fg1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(palette.fg3)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(palette.bgSunken))
                    .overlay(Capsule().strokeBorder(palette.border, lineWidth: 1.5))
                }
                .sensoryFeedback(.selection, trigger: repeats)
            }
            .padding(.vertical, Spacing.s3)

            Divider().background(palette.border)

            // Remind me
            let canRemind = customDate != nil || due != .someday
            HStack(spacing: Spacing.s3) {
                Image(systemName: "bell")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.fg2)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me")
                        .font(.geist(size: 14, weight: 600))
                        .foregroundStyle(palette.fg1)
                    Text(canRemind
                         ? (remindMe ? "We'll ping you" : "We won't nag you")
                         : "Set a date first")
                        .font(.geist(size: 11, weight: 400))
                        .foregroundStyle(palette.fg3)
                }
                Spacer()
                PlootToggle(isOn: $remindMe)
                    .disabled(!canRemind)
                    .opacity(canRemind ? 1 : 0.5)
            }
            .padding(.vertical, Spacing.s3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Spacing.s2)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1.5)
        )
    }
}
