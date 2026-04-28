import SwiftUI

/// One of the three pills in QuickAddSheet's meta row. Stamp-styled, color
/// fills when the field is set, scale-pulses when its `pulseTrigger`
/// increments — driven by either NLP auto-fill or an explicit pick.
struct MetaPill: View {
    var icon: String
    var label: String
    var emoji: String? = nil
    var highlight: Bool
    var pulseTrigger: Int
    var action: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var pulse: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji).font(.system(size: 12))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(highlight ? palette.onPrimary : palette.fg2)
                }
                Text(label)
                    .font(.geist(size: 13, weight: 600))
                    .foregroundStyle(highlight ? palette.onPrimary : palette.fg1)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(highlight ? palette.primary : palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        highlight ? palette.borderInk : palette.border,
                        lineWidth: highlight ? 2 : 1.5
                    )
            )
            .scaleEffect(pulse ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .plootHaptic(.selection, trigger: pulseTrigger)
        .onChange(of: pulseTrigger) { _, _ in
            withAnimation(Motion.springFast) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(Motion.spring) { pulse = false }
            }
        }
    }
}
