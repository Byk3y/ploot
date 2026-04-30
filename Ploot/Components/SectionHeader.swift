import SwiftUI

struct SectionHeader<Trailing: View>: View {
    var title: String
    var count: Int? = nil
    var trailing: Trailing

    init(title: String, count: Int? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.count = count
        self.trailing = trailing()
    }

    @Environment(\.plootPalette) private var palette

    var body: some View {
        HStack(spacing: Spacing.s2) {
            Text(title)
                .font(.jetBrainsMono(size: 11, weight: 600))
                .tracking(11 * 0.08)
                .textCase(.uppercase)
                .foregroundStyle(palette.fg2)

            if let count {
                Text("\(count)")
                    .font(.jetBrainsMono(size: 11, weight: 700))
                    .foregroundStyle(palette.fg2)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(palette.bgSunken)
                    )
            }

            Spacer(minLength: 0)

            trailing
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s5)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bg)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String, count: Int? = nil) {
        self.init(title: title, count: count, trailing: { EmptyView() })
    }
}
