import SwiftUI
import UIKit

/// Floating action button — 60pt clay circle with the signature stamped shadow.
///
/// Two gestures composed with the iOS 17+ sequenced pattern:
///   * Quick tap → `action`. Tap-down then tap-up within the long-press
///     threshold fires only `action`.
///   * Hold for 250ms+ → `onLongPressStart` fires, then the drag
///     translation is streamed via `onLongPressChanged` (for the slide-
///     left-to-cancel preview), and `onLongPressEnd(cancelled:)` fires
///     on release.
///
/// `LongPressGesture.sequenced(before: DragGesture)` handles the tap vs
/// hold discrimination natively — no manual Date() timing, no gesture
/// arbitration bugs. `@GestureState` auto-resets on finger-up.
struct FAB: View {
    var systemImage: String = "plus"
    var action: () -> Void
    var onLongPressStart: (() -> Void)? = nil
    /// Bool is `cancelPreview` — true when finger is past the cancel threshold.
    var onLongPressChanged: ((Bool) -> Void)? = nil
    /// Bool is `cancelled` — true if the user slid past the cancel threshold.
    var onLongPressEnd: ((Bool) -> Void)? = nil

    @Environment(\.plootPalette) private var palette

    private enum DragPhase { case inactive, pressing, recording }

    @GestureState private var dragPhase: DragPhase = .inactive
    @State private var wasRecording: Bool = false

    private let longPressThreshold: TimeInterval = 0.25
    private let cancelDistance: CGFloat = 50

    var body: some View {
        circle
            .contentShape(Circle())
            .gesture(TapGesture().onEnded { action() }.exclusively(before: composedGesture))
            .onChange(of: dragPhase, handlePhaseChange)
            .animation(Motion.springFast, value: dragPhase)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Add task")
            .accessibilityHint(onLongPressStart != nil ? "Hold to dictate." : "")
    }

    // MARK: - Visuals

    private var circle: some View {
        let pressed = dragPhase != .inactive
        // Swap the + glyph for a mic once the long-press threshold fires.
        // .symbolEffect(.replace) cross-fades the two glyphs smoothly,
        // which feels like the button is becoming a mic rather than
        // showing a second overlaid icon.
        let iconName = dragPhase == .recording ? "mic.fill" : systemImage

        return Image(systemName: iconName)
            .font(.system(size: 26, weight: .heavy))
            .foregroundStyle(palette.onPrimary)
            .contentTransition(.symbolEffect(.replace.downUp))
            .frame(width: 60, height: 60)
            .background(Circle().fill(palette.primary))
            .overlay(Circle().strokeBorder(palette.borderInk, lineWidth: 2.5))
            .background(
                Circle()
                    .fill(palette.borderInk)
                    .offset(y: pressed ? 0 : 4)
            )
            .offset(y: pressed ? 4 : 0)
    }

    // MARK: - Gesture

    private var composedGesture: some Gesture {
        // LongPressGesture.sequenced(before: DragGesture) is the canonical
        // iOS 17+ pattern for "press-and-hold then drag" interactions.
        // `.first(true)` fires when the hold threshold is crossed (and we're
        // about to transition into the drag); `.second(true, drag)` fires
        // for each drag update after that.
        LongPressGesture(minimumDuration: longPressThreshold)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($dragPhase) { value, state, _ in
                switch value {
                case .first(true):
                    // Long press completed, waiting for drag to start.
                    state = .pressing
                case .second(true, let drag):
                    state = .recording
                    if onLongPressStart != nil, let drag {
                        let cancel = drag.translation.width < -cancelDistance
                        Task { @MainActor in onLongPressChanged?(cancel) }
                    }
                default:
                    state = .inactive
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let drag):
                    let cancel = (drag?.translation.width ?? 0) < -cancelDistance
                    onLongPressEnd?(cancel)
                    wasRecording = false
                case .first(true):
                    // Long-press completed but the drag phase never
                    // registered (rare — usually DragGesture takes over
                    // immediately at minimumDistance: 0). Treat as a
                    // committed release.
                    onLongPressEnd?(false)
                    wasRecording = false
                default:
                    // Tap path is handled by the exclusive TapGesture;
                    // the sequenced gesture cancels (no .onEnded) on a
                    // sub-threshold release.
                    break
                }
            }
    }

    // MARK: - Phase bridging

    private func handlePhaseChange(_ oldPhase: DragPhase, _ newPhase: DragPhase) {
        if newPhase == .recording && !wasRecording {
            wasRecording = true
            if UserPrefs.hapticsEnabled {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            onLongPressStart?()
        }
    }
}
