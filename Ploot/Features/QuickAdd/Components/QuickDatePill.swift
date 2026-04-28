import SwiftUI

/// One of the inline date options inside QuickAddSheet's date picker
/// (Today / Tomorrow / Weekend / Next week / Someday). Stamped-pill chrome
/// with an active-state fill that matches the meta-row pills.
struct QuickDatePill: View {
    var icon: String
    var label: String
    var active: Bool
    var onTap: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.geist(size: 13, weight: 600))
            }
            .foregroundStyle(active ? palette.onPrimary : palette.fg1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? palette.primary : palette.bgSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        active ? palette.borderInk : palette.border,
                        lineWidth: active ? 2 : 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .plootHaptic(.selection, trigger: active)
    }
}
