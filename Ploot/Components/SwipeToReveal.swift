import SwiftUI

/// Mail-style swipe-to-reveal-Delete pattern for views that aren't inside
/// a `List` (where `.swipeActions` would do this for free). The wrapped
/// content sits over a trailing Delete button; dragging left past a small
/// threshold snaps the row open so the user has to *tap* Delete — no
/// accidental deletion from a stray swipe.
///
/// Shape contract: the wrapped content should already paint its own
/// opaque background, otherwise the Delete button shows through when the
/// row is at rest.
struct SwipeToReveal<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var onDelete: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var offset: CGFloat = 0
    @State private var revealed: Bool = false

    /// Distance the row pulls back when fully revealed. Sized to fit the
    /// 56×44 Delete chip + trailing breathing room.
    private let revealedOffset: CGFloat = -76
    /// Drag distance past which `onEnded` commits the open state. Below
    /// this the row springs back to closed.
    private let commitThreshold: CGFloat = 50

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteButton
                .opacity(offset < -10 ? 1 : 0)
                .padding(.trailing, 8)

            content()
                .offset(x: offset)
                .gesture(swipe)
                .simultaneousGesture(
                    // Tap anywhere on the row while revealed → snap shut.
                    // Doesn't fire when the user taps the Delete button
                    // because that lives outside this content() closure.
                    TapGesture().onEnded {
                        if revealed { snapClosed() }
                    }
                )
        }
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.red)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .stampedShadow(radius: Radius.md, offset: 2)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: revealed) { _, isRevealed in
            isRevealed
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { v in
                let dx = v.translation.width
                if revealed {
                    offset = min(0, revealedOffset + dx)
                } else {
                    offset = min(0, dx)
                }
            }
            .onEnded { v in
                let total = revealed ? revealedOffset + v.translation.width : v.translation.width
                let shouldReveal = total < -commitThreshold
                withAnimation(Motion.spring) {
                    offset = shouldReveal ? revealedOffset : 0
                    revealed = shouldReveal
                }
            }
    }

    private func snapClosed() {
        withAnimation(Motion.spring) {
            offset = 0
            revealed = false
        }
    }
}
