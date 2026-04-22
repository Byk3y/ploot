import SwiftUI
import SwiftData

/// Bottom sheet for creating a new project. Three inputs — name, emoji,
/// tile color — plus a live preview of the resulting Projects card so the
/// user can see what they're about to make.
struct NewProjectSheet: View {
    var onClose: () -> Void

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlootProject.order) private var projects: [PlootProject]

    @State private var name: String = ""
    @State private var emoji: String = "💼"
    @State private var tileColor: ProjectTileColor = .sky
    @FocusState private var nameFocused: Bool

    /// Curated starters drawn from the brief ("Projects use emoji 💼🏡🚀🛒📚")
    /// plus a few more in the same register. User can type any emoji via the
    /// iOS keyboard's globe key in the custom-emoji field below the grid.
    private let emojiSuggestions = ["💼", "🏡", "🚀", "🛒", "📚", "🎯", "🎨", "🌱", "💪", "🍳"]
    private let colorOptions: [ProjectTileColor] = [.sky, .forest, .plum, .butter, .primary, .inbox]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    previewCard
                    nameField
                    emojiSection
                    colorSection
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s2)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(palette.bg.ignoresSafeArea())
        .onAppear { nameFocused = true }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button("Cancel", action: onClose)
                .font(.geist(size: 15, weight: 500))
                .foregroundStyle(palette.fg2)

            Spacer()

            Text("New project")
                .font(.fraunces(size: 20, weight: 600, opsz: 20, soft: 80))
                .foregroundStyle(palette.fg1)

            Spacer()

            Button("Save", action: submit)
                .buttonStyle(.ploot(.primary, size: .sm))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
    }

    // MARK: - Live preview

    private var previewCard: some View {
        HStack(spacing: Spacing.s3) {
            Text(emoji)
                .font(.system(size: 26))
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tileColor.fill(palette: palette))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Your project" : name)
                    .font(.geist(size: 16, weight: 600))
                    .tracking(-0.005 * 16)
                    .foregroundStyle(name.isEmpty ? palette.fg3 : palette.fg1)
                Text("0 open · 0 done")
                    .font(.geist(size: 13, weight: 400))
                    .foregroundStyle(palette.fg3)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(radius: Radius.lg, padding: 14)
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("name")
                .eyebrow()
                .foregroundStyle(palette.fg3)

            TextField("What's it called?", text: $name)
                .font(.fraunces(size: 22, weight: 500, opsz: 22, soft: 50))
                .foregroundStyle(palette.fg1)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit(submit)
                .padding(.vertical, Spacing.s3)
                .padding(.horizontal, Spacing.s3)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(nameFocused ? palette.borderInk : palette.border, lineWidth: 2)
                )
        }
    }

    // MARK: - Emoji

    private var emojiSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("emoji")
                .eyebrow()
                .foregroundStyle(palette.fg3)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s2), count: 5),
                spacing: Spacing.s2
            ) {
                ForEach(emojiSuggestions, id: \.self) { candidate in
                    emojiTile(candidate)
                }
            }

            customEmojiField
        }
    }

    private func emojiTile(_ candidate: String) -> some View {
        let selected = emoji == candidate
        return Button {
            withAnimation(Motion.springFast) { emoji = candidate }
        } label: {
            Text(candidate)
                .font(.system(size: 24))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(selected ? palette.primary.opacity(0.18) : palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(selected ? palette.primary : palette.border, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var customEmojiField: some View {
        // SwiftUI TextField accepts any emoji the user types via the globe
        // key. We truncate to the last grapheme so re-editing just swaps
        // the character instead of accumulating a string.
        HStack(spacing: Spacing.s2) {
            Image(systemName: "face.smiling")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.fg3)
            TextField("or type any emoji", text: $emoji)
                .font(.system(size: 18))
                .foregroundStyle(palette.fg1)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: emoji) { _, new in
                    if new.count > 1, let last = new.last {
                        emoji = String(last)
                    }
                }
        }
        .padding(.horizontal, Spacing.s3)
        .padding(.vertical, Spacing.s2)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(palette.bgSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        )
    }

    // MARK: - Color

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("tile color")
                .eyebrow()
                .foregroundStyle(palette.fg3)

            HStack(spacing: Spacing.s2) {
                ForEach(colorOptions, id: \.self) { candidate in
                    colorSwatch(candidate)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func colorSwatch(_ candidate: ProjectTileColor) -> some View {
        let selected = tileColor == candidate
        return Button {
            withAnimation(Motion.springFast) { tileColor = candidate }
        } label: {
            Circle()
                .fill(candidate.fill(palette: palette))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle().strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .background(
                    Circle()
                        .fill(palette.borderInk)
                        .offset(y: selected ? 0 : 2)
                )
                .offset(y: selected ? 2 : 0)
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(palette.borderInk)
                    }
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }

    // MARK: - Submit

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !emoji.isEmpty
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !emoji.isEmpty else { return }

        let existingIds = Set(projects.map(\.id))
        let slug = Self.generateSlug(from: trimmed, existing: existingIds)
        let nextOrder = (projects.map(\.order).max() ?? 0) + 1

        let project = PlootProject(
            id: slug,
            name: trimmed,
            emoji: emoji,
            tileColor: tileColor,
            order: nextOrder
        )
        modelContext.insert(project)
        try? modelContext.save()
        onClose()
    }

    /// Derive a URL-safe slug from a display name. "Side quest" → "side-quest".
    /// If the slug clashes with an existing id or the reserved "inbox"
    /// sentinel, disambiguate by appending -2, -3, etc.
    private static func generateSlug(from name: String, existing: Set<String>) -> String {
        let cleaned = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 -]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " +", with: "-", options: .regularExpression)

        let base = cleaned.isEmpty ? "project" : cleaned
        let reserved: Set<String> = ["inbox"]
        if !reserved.contains(base) && !existing.contains(base) { return base }

        var n = 2
        while true {
            let candidate = "\(base)-\(n)"
            if !reserved.contains(candidate) && !existing.contains(candidate) {
                return candidate
            }
            n += 1
        }
    }
}
