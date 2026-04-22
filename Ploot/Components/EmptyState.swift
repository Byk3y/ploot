import SwiftUI

struct EmptyState<Action: View>: View {
    var systemImage: String?
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var action: () -> Action

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(spacing: Spacing.s3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(palette.primary.opacity(0.85))
                    .padding(.bottom, 4)
            }
            Text(title)
                .font(.fraunces(size: 24, weight: 600))
                .tracking(-0.015 * 24)
                .foregroundStyle(palette.fg1)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.geist(size: 14, weight: 400))
                    .foregroundStyle(palette.fg2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .lineSpacing(4)
            }
            action()
        }
        .padding(.horizontal, Spacing.s6)
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }
}

extension EmptyState where Action == EmptyView {
    init(systemImage: String? = nil, title: String, subtitle: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.action = { EmptyView() }
    }
}
