import SwiftUI

// Sub-view computed properties used by BreakdownSheet's content switch:
// header lines, the streaming task list, the completion chip, and the
// terminal-state cards (hint / split / refused / error / rate-limit).
// Pulled out of BreakdownSheet.swift so that file can stay focused on
// state machine + stream lifecycle.

extension BreakdownSheet {

    // MARK: - Header lines

    var projectLine: some View {
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

    var contextPills: some View {
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

    var thinkingShimmer: some View {
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

    // MARK: - Streaming list

    var streamedTaskList: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            if case .reviewing = phase {
                // Review mode: reorderable list
                reviewableList
                reviewFooter
                    .padding(.top, Spacing.s3)
            } else {
                // Legacy / streaming mode: non-reorderable
                ForEach(streamedTasks) { task in
                    SwipeToReveal {
                        streamedRow(task)
                    } onDelete: {
                        removeStreamedTask(task)
                    }
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
                    timelinePicker
                        .padding(.top, Spacing.s3)
                    completionChip
                        .padding(.top, Spacing.s2)
                }
            }
        }
    }

    // MARK: - Reviewable list (drag-to-reorder)

    @ViewBuilder
    var reviewableList: some View {
        ForEach(Array(streamedTasks.enumerated()), id: \.element.id) { index, task in
            reviewRow(task, index: index)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .padding(.bottom, Spacing.s2)
        }
        .onMove(perform: moveStreamedTasks)
        .onDelete(perform: deleteStreamedTasks)
    }

    /// Review-mode row: tap title to inline-rename.
    private func reviewRow(_ task: StreamedTask, index: Int) -> some View {
        HStack(alignment: .center, spacing: Spacing.s2) {
            if editingTaskIndex == index {
                TextField("Step name", text: $editingText)
                    .font(.geist(size: 15, weight: 500))
                    .foregroundStyle(palette.fg1)
                    .submitLabel(.done)
                    .onSubmit {
                        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            streamedTasks[index].title = trimmed
                        }
                        editingTaskIndex = nil
                    }
            } else {
                Text(task.title)
                    .font(.geist(size: 15, weight: 500))
                    .foregroundStyle(palette.fg1)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        editingText = task.title
                        editingTaskIndex = index
                    }
            }

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.fg3)
        }
        .padding(.horizontal, Spacing.s3)
        .padding(.vertical, Spacing.s3)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(editingTaskIndex == index ? palette.primary : palette.borderInk, lineWidth: 2)
        )
        .stampedShadow(radius: Radius.md, offset: 2)
    }

    // MARK: - Review footer (commit / redo)

    var reviewFooter: some View {
        VStack(spacing: Spacing.s3) {
            timelinePicker

            // Task count
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.primary)
                Text("\(streamedTasks.count) steps ready")
                    .font(.geist(size: 13, weight: 500))
                    .foregroundStyle(palette.fg2)
            }

            Text("Drag to reorder · tap to rename")
                .font(.geist(size: 12, weight: 400))
                .foregroundStyle(palette.fg3)

            // Commit button
            Button {
                commitAllTasks()
            } label: {
                Text("Start with step 1")
                    .font(.geist(size: 16, weight: 600))
                    .foregroundStyle(palette.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(palette.primary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .strokeBorder(palette.borderInk, lineWidth: 2)
                    )
                    .stampedShadow(radius: Radius.lg, offset: 3)
            }
            .buttonStyle(.plain)

            // Redo button
            Button {
                redoPlan()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .medium))
                    Text("Try a different plan")
                        .font(.geist(size: 14, weight: 500))
                }
                .foregroundStyle(palette.fg2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Timeline picker

    /// Post-stream pacing picker. Default is `.drip` (no change to the
    /// existing one-at-a-time behavior). Picking anything else re-stamps
    /// every streamed task's dueDate via `applyTimeline(...)`.
    var timelinePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: 6) {
                Text("📅").font(.system(size: 13))
                Text("timeline")
                    .font(.jetBrainsMono(size: 11, weight: 700))
                    .tracking(11 * 0.08)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.fg2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(timelineModeOptions, id: \.self) { mode in
                        timelineChip(for: mode)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var timelineModeOptions: [TimelineMode] {
        [.drip, .thisWeekend, .thisWeek, .nextTwoWeeks]
    }

    private func timelineChip(for mode: TimelineMode) -> some View {
        let isSelected = timelineMode == mode
        return Button {
            withAnimation(Motion.spring) {
                timelineMode = mode
            }
            applyTimeline(mode)
        } label: {
            Text(mode.label)
                .font(.geist(size: 12, weight: 600))
                .foregroundStyle(isSelected ? palette.onPrimary : palette.fg1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isSelected ? palette.primary : palette.bgElevated)
                )
                .overlay(
                    Capsule().strokeBorder(palette.borderInk, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .plootHaptic(.selection, trigger: isSelected)
    }

    func streamedRow(_ task: StreamedTask) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Text(task.title)
                .font(.geist(size: 15, weight: 500))
                .foregroundStyle(palette.fg1)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.s3)
        .padding(.vertical, Spacing.s3)
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

    var completionChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(palette.primary)
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

    func terminalCard(
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

    func splitCard(projects: [String]) -> some View {
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
}
