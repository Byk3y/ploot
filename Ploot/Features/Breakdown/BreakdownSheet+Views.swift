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

    func streamedRow(_ task: StreamedTask) -> some View {
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

    var completionChip: some View {
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
