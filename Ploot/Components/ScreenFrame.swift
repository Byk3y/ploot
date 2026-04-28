import SwiftUI

/// Shared chrome for the main screens: title + subtitle header with optional
/// leading/trailing accessories, plus a scrollable content area.
struct ScreenFrame<Content: View, Leading: View, Trailing: View>: View {
    var title: String? = nil
    var titleSuffix: AnyView? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String? = nil,
        titleSuffix: AnyView? = nil,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.titleSuffix = titleSuffix
        self.subtitle = subtitle
        self.content = content
        self.leading = leading
        self.trailing = trailing
    }

    @Environment(\.plootPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            if title != nil || hasLeading || hasTrailing {
                header
            }
            content()
        }
        .background(palette.bg.ignoresSafeArea())
    }

    private var hasLeading: Bool { !(leading() is EmptyView) }
    private var hasTrailing: Bool { !(trailing() is EmptyView) }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(title)
                            .font(.fraunces(size: 26, weight: 600))
                            .tracking(-0.015 * 26)
                            .foregroundStyle(palette.fg1)
                        if let titleSuffix {
                            titleSuffix
                        }
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.geist(size: 13, weight: 400))
                        .foregroundStyle(palette.fg3)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s3)
        .padding(.bottom, Spacing.s2)
    }
}

// Convenience initializers so callers can omit leading / trailing.
extension ScreenFrame where Leading == EmptyView {
    init(
        title: String? = nil,
        titleSuffix: AnyView? = nil,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.titleSuffix = titleSuffix
        self.subtitle = subtitle
        self.content = content
        self.leading = { EmptyView() }
        self.trailing = trailing
    }
}

extension ScreenFrame where Trailing == EmptyView {
    init(
        title: String? = nil,
        titleSuffix: AnyView? = nil,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.titleSuffix = titleSuffix
        self.subtitle = subtitle
        self.content = content
        self.leading = leading
        self.trailing = { EmptyView() }
    }
}

extension ScreenFrame where Leading == EmptyView, Trailing == EmptyView {
    init(
        title: String? = nil,
        titleSuffix: AnyView? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.titleSuffix = titleSuffix
        self.subtitle = subtitle
        self.content = content
        self.leading = { EmptyView() }
        self.trailing = { EmptyView() }
    }
}

/// Small circular 40pt chrome button used in the header (back, more, add).
struct HeaderButton: View {
    var systemImage: String
    var action: () -> Void

    @Environment(\.plootPalette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.fg1)
                .frame(width: 40, height: 40)
                .background(Circle().fill(palette.bgElevated))
                .overlay(Circle().strokeBorder(palette.borderInk, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .plootHaptic(.selection, trigger: false)
    }
}
