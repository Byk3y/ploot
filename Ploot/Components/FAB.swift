import SwiftUI

/// Floating action button — 60pt clay circle with the signature stamped shadow.
/// Press collapses the stamp and pushes the button down 4pt, like a physical
/// button being mashed.
struct FAB: View {
    var systemImage: String = "plus"
    var action: () -> Void

    @Environment(\.plootPalette) private var palette
    @State private var pressed: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(palette.onPrimary)
                .frame(width: 60, height: 60)
                .background(
                    Circle().fill(palette.primary)
                )
                .overlay(
                    Circle().strokeBorder(palette.borderInk, lineWidth: 2.5)
                )
                .background(
                    Circle()
                        .fill(palette.borderInk)
                        .offset(y: pressed ? 0 : 4)
                )
                .offset(y: pressed ? 4 : 0)
        }
        .buttonStyle(PressedButtonStyle(pressed: $pressed))
        .animation(Motion.springFast, value: pressed)
        .sensoryFeedback(.impact(weight: .medium), trigger: pressed) { old, new in !old && new }
    }
}

/// ButtonStyle that reports press state upward via a binding.
struct PressedButtonStyle: ButtonStyle {
    @Binding var pressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, new in
                pressed = new
            }
    }
}
