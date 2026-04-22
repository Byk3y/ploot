import Foundation
import SwiftData

/// Namespace for the app-wide placeholder project used by QuickAdd's
/// picker when the user hasn't selected anything yet. Historically this
/// file also held the UI-stage demo seed; that shipped with Phase 4c
/// when real data via Supabase sync took over.
enum DemoData {
    /// The Inbox sentinel — not persisted to SwiftData or Supabase.
    /// QuickAdd's project picker shows this as the default "unassigned"
    /// option. Selecting it stores `projectId = nil` on the saved task.
    static let inboxProject = PlootProject(
        id: "inbox",
        name: "Inbox",
        emoji: "📮",
        tileColor: .inbox,
        order: 0
    )
}
