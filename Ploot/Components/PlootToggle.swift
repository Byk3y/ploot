import SwiftUI

/// Pill-shaped toggle with the dark hairline and spring knob motion.
struct PlootToggle: View {
    @Binding var isOn: Bool

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button {
            withAnimation(Motion.spring) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? palette.primary : palette.borderStrong)
                    .frame(width: 44, height: 26)
                    .overlay(
                        Capsule().strokeBorder(palette.borderInk, lineWidth: 2)
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle().strokeBorder(palette.borderInk, lineWidth: 1.5)
                    )
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isOn)
    }
}
