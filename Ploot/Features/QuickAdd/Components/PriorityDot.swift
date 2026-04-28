import SwiftUI

/// Small circular priority swatch used in QuickAddSheet's Tier 2 details
/// card. Renders the priority emoji (⚡ ❗ 🔥) inside a fill-tinted circle
/// when active, or a tiny dot for `.normal`.
struct PriorityDot: View {
    var priority: Priority
    var active: Bool
    var onTap: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle().fill(active ? activeFill : palette.bgSunken)
                Circle()
                    .strokeBorder(
                        active ? palette.borderInk : palette.border,
                        lineWidth: active ? 2 : 1.5
                    )
                if !priority.emoji.isEmpty {
                    Text(priority.emoji).font(.system(size: 12))
                } else if priority == .normal {
                    Circle()
                        .fill(active ? palette.primary : palette.borderStrong)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 28, height: 28)
            .scaleEffect(active ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(Motion.springFast, value: active)
        .plootHaptic(.selection, trigger: active)
    }

    private var activeFill: Color {
        switch priority {
        case .normal: return palette.bgElevated
        case .medium: return palette.butter300
        case .high:   return palette.plum100
        case .urgent: return palette.primary.opacity(0.25)
        }
    }
}
