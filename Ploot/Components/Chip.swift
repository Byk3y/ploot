import SwiftUI

enum ChipColor: String, CaseIterable {
    case ink, clay, forest, butter, plum, sky
}

struct Chip: View {
    var text: String
    var color: ChipColor = .ink
    var icon: String? = nil     // SF Symbol name, optional
    var leadingEmoji: String? = nil
    var selected: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(\.plootPalette) private var palette
    @Environment(\.plootTheme) private var theme

    var body: some View {
        let (bg, fg) = resolvedPalette()

        Button(action: { onTap?() }) {
            HStack(spacing: 5) {
                if let leadingEmoji {
                    Text(leadingEmoji)
                }
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(text)
                    .font(.geist(size: 12, weight: 600))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(selected ? palette.fgInverse : fg)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? palette.borderInk : bg)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func resolvedPalette() -> (Color, Color) {
        // On cocoa, the light-mode pastel tints disappear into the chocolate
        // canvas. Swap to a semi-opaque accent wash with the lighter shade of
        // the scale as foreground — keeps the color signal while staying
        // legible against the warm dark ground.
        switch (color, theme) {
        case (.ink, _):
            return (palette.bgSunken, palette.fg2)
        case (.clay, .light):
            return (palette.clay100, palette.clay700)
        case (.clay, .cocoa):
            return (palette.clay500.opacity(0.18), palette.clay300)
        case (.forest, .light):
            return (palette.forest100, palette.forest700)
        case (.forest, .cocoa):
            return (palette.forest500.opacity(0.25), palette.forest100)
        case (.butter, .light):
            return (palette.butter100, Color(hex: 0x7A5A00))
        case (.butter, .cocoa):
            return (palette.butter500.opacity(0.22), palette.butter300)
        case (.plum, .light):
            return (palette.plum100, palette.plum500)
        case (.plum, .cocoa):
            return (palette.plum500.opacity(0.25), palette.plum100)
        case (.sky, .light):
            return (palette.sky100, palette.sky500)
        case (.sky, .cocoa):
            return (palette.sky500.opacity(0.25), palette.sky100)
        }
    }
}
