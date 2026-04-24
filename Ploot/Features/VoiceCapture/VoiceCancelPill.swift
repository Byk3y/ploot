import SwiftUI

/// Cancel affordance that sits directly to the LEFT of the FAB during
/// voice capture. User slides their finger toward this pill to arm
/// cancellation. WhatsApp-style spatial cue — not buried text.
///
/// States:
///   * Neutral (listening, not past threshold): muted capsule with
///     `← slide to cancel` in subdued color. A visual signpost.
///   * Armed (past cancel threshold): red capsule with `release to cancel`
///     and a trash icon. Slight scale bump + heavy haptic — finger has
///     "landed" on the cancel target.
///   * `bounceTrigger` is incremented when a cancel actually fires, which
///     plays a symbolEffect.bounce on the trash icon (the "bin eating
///     the content" cue).
struct VoiceCancelPill: View {
    let cancelPreview: Bool
    var bounceTrigger: Int = 0

    @Environment(\.plootPalette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: cancelPreview ? "trash.fill" : "arrow.left")
                .font(.system(size: cancelPreview ? 13 : 11, weight: .bold))
                .symbolEffect(.bounce.up.byLayer, value: bounceTrigger)
            Text(cancelPreview ? "release to cancel" : "slide to cancel")
                .font(.geist(size: 12, weight: cancelPreview ? 700 : 600))
        }
        .foregroundStyle(cancelPreview ? Color.white : palette.fg2)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(cancelPreview ? Color.red : palette.bgElevated)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    cancelPreview ? Color.red : palette.borderInk,
                    lineWidth: 2
                )
        )
        .stampedShadow(radius: 999, offset: 2, color: cancelPreview ? Color.red.opacity(0.4) : nil)
        .scaleEffect(cancelPreview ? 1.06 : 1)
        .animation(Motion.spring, value: cancelPreview)
        .allowsHitTesting(false)
        .sensoryFeedback(.impact(weight: .heavy), trigger: cancelPreview) { old, new in !old && new }
    }
}

#Preview("Neutral") {
    VoiceCancelPill(cancelPreview: false)
        .padding()
        .plootTheme(.light)
}

#Preview("Armed") {
    VoiceCancelPill(cancelPreview: true)
        .padding()
        .plootTheme(.light)
}
