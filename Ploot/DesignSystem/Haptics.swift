import SwiftUI

/// `.sensoryFeedback` wrapper that respects the user's
/// `Settings → Reminders → Haptics` toggle. Reads `UserPrefs` at trigger
/// time so toggling on/off in Settings takes effect immediately without
/// rebuilding the view.
///
/// Drop-in replacement for `.sensoryFeedback(_:trigger:)` — call
/// `.plootHaptic(_:trigger:)` instead and the rest is the same.
extension View {
    func plootHaptic<V: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: V
    ) -> some View {
        self.sensoryFeedback(trigger: trigger) { _, _ in
            UserPrefs.hapticsEnabled ? feedback : nil
        }
    }

    /// Closure-form variant for cases where the caller wants conditional
    /// haptics based on the new value (e.g. only fire when `isOn` flips
    /// to true). Mirrors the upstream `.sensoryFeedback(_:trigger:_:)`
    /// signature, with the user's toggle gating the result.
    func plootHaptic<V: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: V,
        condition: @escaping (V, V) -> Bool
    ) -> some View {
        self.sensoryFeedback(trigger: trigger) { old, new in
            guard UserPrefs.hapticsEnabled else { return nil }
            return condition(old, new) ? feedback : nil
        }
    }
}
