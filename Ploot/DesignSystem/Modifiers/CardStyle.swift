import SwiftUI

/// Surface style used by every elevated Ploot card: warm fill, 2px dark
/// hairline, stamped shadow. Matches the `Card` primitive from the mobile
/// UI kit (`ui_kits/mobile/Primitives.jsx`).
struct CardStyle: ViewModifier {
    var radius: CGFloat = Radius.lg
    var padding: CGFloat = Spacing.s4
    var borderWidth: CGFloat = 2
    var fill: Color? = nil

    @Environment(\.plootPalette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill ?? palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(palette.borderInk, lineWidth: borderWidth)
            )
            .stampedShadow(radius: radius, offset: 2)
    }
}

extension View {
    func cardStyle(
        radius: CGFloat = Radius.lg,
        padding: CGFloat = Spacing.s4,
        fill: Color? = nil
    ) -> some View {
        modifier(CardStyle(radius: radius, padding: padding, fill: fill))
    }
}
