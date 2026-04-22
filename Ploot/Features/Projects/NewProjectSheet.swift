import SwiftUI
import SwiftData

/// Bottom sheet for creating a new project. Three inputs — name, emoji,
/// tile color — plus a live preview of the resulting Projects card so the
/// user can see what they're about to make.
struct NewProjectSheet: View {
    /// When non-nil, the sheet is in edit mode: fields prefill from this
    /// project and Save mutates it in place instead of inserting. The slug
    /// `id` stays locked — changing it would orphan every task that
    /// references the project via `projectId`.
    let existingProject: PlootProject?
    var onClose: () -> Void

    @Environment(\.plootPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlootProject.order) private var projects: [PlootProject]

    @State private var name: String
    @State private var emoji: String
    @State private var tileColor: ProjectTileColor
    @FocusState private var nameFocused: Bool

    init(existingProject: PlootProject? = nil, onClose: @escaping () -> Void) {
        self.existingProject = existingProject
        self.onClose = onClose
        _name = State(initialValue: existingProject?.name ?? "")
        _emoji = State(initialValue: existingProject?.emoji ?? "💼")
        _tileColor = State(initialValue: existingProject?.tileColor ?? .sky)
    }

    /// Curated starters drawn from the brief ("Projects use emoji 💼🏡🚀🛒📚")
    /// plus a few more in the same register. Nine tiles — the tenth slot in
    /// the 5×2 grid is the "pick any emoji" tile that invokes the native
    /// emoji keyboard.
    private let emojiSuggestions = ["💼", "🏡", "🚀", "🛒", "📚", "🎯", "🎨", "🌱", "💪"]
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
        .onAppear {
            // Only autofocus in create mode — edit mode leaves focus off so
            // the user can tweak any field without dismissing the keyboard.
            if existingProject == nil { nameFocused = true }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button("Cancel", action: onClose)
                .font(.geist(size: 15, weight: 500))
                .foregroundStyle(palette.fg2)

            Spacer()

            Text(existingProject == nil ? "New project" : "Edit project")
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
                moreEmojiTile
            }
        }
    }

    /// The tenth tile. If the user has picked a custom emoji (one not in
    /// `emojiSuggestions`) it's shown here with selected-tile styling;
    /// otherwise a face.smiling icon hints that tapping opens the emoji
    /// keyboard. The EmojiTextField sits invisibly on top and catches
    /// taps — becoming first responder triggers the native picker.
    private var moreEmojiTile: some View {
        let isCustom = !emojiSuggestions.contains(emoji) && !emoji.isEmpty
        return ZStack {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(isCustom ? palette.primary.opacity(0.18) : palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(isCustom ? palette.primary : palette.border, lineWidth: 2)
                )

            EmojiTextField(text: $emoji, hidesCursor: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Group {
                if isCustom {
                    Text(emoji).font(.system(size: 24))
                } else {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(palette.fg3)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .sensoryFeedback(.selection, trigger: emoji)
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

        if let existing = existingProject {
            // In-place update. id + order stay as they were.
            existing.name = trimmed
            existing.emoji = emoji
            existing.tileColor = tileColor
            existing.touch()
        } else {
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
        }
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
