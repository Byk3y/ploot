import Foundation
import SwiftUI

struct PlootProject: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let tileColor: ProjectTileColor
    var openCount: Int
    var doneCount: Int
}

/// Token-backed color choices for project tiles. Resolved against the current
/// palette so the same project shifts appropriately between light and cocoa.
enum ProjectTileColor: Hashable {
    case sky
    case forest
    case plum
    case butter
    case primary
    case inbox

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

    /// Dot / swatch color for contexts where tileColor would be too bright
    /// (e.g. a 6px dot next to meta text).
    func dot(palette: PlootPalette) -> Color {
        switch self {
        case .butter: return palette.butter500
        default:      return fill(palette: palette)
        }
    }
}
