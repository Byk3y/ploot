import Foundation
import SwiftData
import SwiftUI

/// Persisted project. `id` is a human-readable slug ("work", "home", etc.)
/// so tasks can reference it via `projectId: String?` without carrying a
/// full PersistentIdentifier through the codebase.
@Model
final class PlootProject {
    @Attribute(.unique) var id: String
    var name: String
    var emoji: String
    var tileColor: ProjectTileColor
    /// Display ordering in the Projects screen list.
    var order: Int
    /// Bumped on every mutation — basis for last-write-wins conflict
    /// resolution once Supabase sync lands. Optional so this column can be
    /// added as a lightweight SwiftData migration without rejecting existing
    /// rows; nil means "never mutated since the column arrived."
    var updatedAt: Date?
    /// Soft-delete tombstone; see PlootTask.deletedAt for rationale.
    var deletedAt: Date?

    init(
        id: String,
        name: String,
        emoji: String,
        tileColor: ProjectTileColor,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.tileColor = tileColor
        self.order = order
        self.updatedAt = Date()
    }

    func touch() {
        updatedAt = Date()
    }

    @MainActor
    func softDelete() {
        deletedAt = Date()
        touch()
        SyncService.shared.push(project: self)
    }

    var isLive: Bool { deletedAt == nil }
}

/// Token-backed color choices for project tiles. Raw-String so SwiftData
/// can persist it directly.
enum ProjectTileColor: String, Codable, CaseIterable {
    case sky, forest, plum, butter, primary, inbox

    func fill(palette: PlootPalette) -> Color {
        switch self {
        case .sky:     return palette.sky500
        case .forest:  return palette.forest500
        case .plum:    return palette.plum500
        case .butter:  return palette.butter300
        case .primary: return palette.primary
        case .inbox:   return palette.fg3
        }
    }

    /// Dot / swatch color for contexts where `fill` would be too bright
    /// (e.g. a 6pt dot next to meta text).
    func dot(palette: PlootPalette) -> Color {
        switch self {
        case .butter: return palette.butter500
        default:      return fill(palette: palette)
        }
    }
}
