import SwiftUI

struct ProgressBar: View {
    var value: Double  // 0…1

    @Environment(\.plootPalette) private var palette

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.bgSunken)

                Capsule()
                    .fill(palette.primary)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .animation(Motion.spring, value: value)
            }
            .overlay(
                Capsule().strokeBorder(palette.borderInk, lineWidth: 1.5)
            )
        }
        .frame(height: 8)
    }
}
