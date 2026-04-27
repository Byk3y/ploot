import SwiftUI
import SwiftData

/// Bottom sheet for creating a new project. Three inputs — name, emoji,
/// tile color — plus a live preview of the resulting Projects card so
/// the user can see what they're about to make.
///
/// Section views (preview, name, emoji grid, color swatches) live in
/// NewProjectSheet+Inputs.swift. State below is internal-access (no
/// `private`) so the cross-file extension can read/write it.
struct NewProjectSheet: View {
    /// When non-nil, the sheet is in edit mode: fields prefill from this
    /// project and Save mutates it in place instead of inserting. The slug
    /// `id` stays locked — changing it would orphan every task that
    /// references the project via `projectId`.
    let existingProject: PlootProject?
    var onClose: () -> Void

    @Environment(\.plootPalette) var palette
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PlootProject.order) var projects: [PlootProject]

    @State var name: String
    @State var emoji: String
    @State var tileColor: ProjectTileColor
    @FocusState var nameFocused: Bool

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
    let emojiSuggestions = ["💼", "🏡", "🚀", "🛒", "📚", "🎯", "🎨", "🌱", "💪"]
    let colorOptions: [ProjectTileColor] = [.sky, .forest, .plum, .butter, .primary, .inbox]

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

    // MARK: - Submit

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !emoji.isEmpty
    }

    func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !emoji.isEmpty else { return }

        let savedProject: PlootProject
        if let existing = existingProject {
            // In-place update. id + order stay as they were.
            existing.name = trimmed
            existing.emoji = emoji
            existing.tileColor = tileColor
            existing.touch()
            try? modelContext.save()
            savedProject = existing
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
            // Animate insertion so the new card slides into the Projects list
            // instead of popping when the user returns from the sheet.
            withAnimation(Motion.spring) {
                modelContext.insert(project)
                try? modelContext.save()
            }
            savedProject = project
        }
        SyncService.shared.push(project: savedProject)
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
