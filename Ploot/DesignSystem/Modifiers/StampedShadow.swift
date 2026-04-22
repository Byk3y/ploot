import SwiftUI

/// The signature Ploot "stamped" shadow: `box-shadow: 0 2px 0 var(--border-ink)`.
///
/// This is *not* a blurred shadow. It is a hard-edged block of the border-ink
/// color peeking out below the element, as if the surface were stamped down
/// onto the page. SwiftUI's `.shadow(...)` blurs — we never want that here.
///
/// Press states should collapse the offset to zero and translate the element
/// down by the same amount, so the lip disappears underneath.
struct StampedShadow: ViewModifier {
    var radius: CGFloat = Radius.md
    var offset: CGFloat = 2
    var color: Color? = nil

    @Environment(\.plootPalette) private var palette

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(color ?? palette.borderInk)
                .offset(y: offset)
        )
    }
}

extension View {
    /// Apply the signature hard-offset stamped shadow. Pass `offset: 0` to
    /// collapse it during press states.
    func stampedShadow(
        radius: CGFloat = Radius.md,
        offset: CGFloat = 2,
        color: Color? = nil
    ) -> some View {
        modifier(StampedShadow(radius: radius, offset: offset, color: color))
    }
}
