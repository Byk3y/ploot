import SwiftUI

enum PlootButtonSize {
    case sm, md, lg

    var height: CGFloat {
        switch self {
        case .sm: return 32
        case .md: return 44
        case .lg: return 52
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm: return 12
        case .md: return 18
        case .lg: return 24
        }
    }

    var radius: CGFloat {
        switch self {
        case .sm: return Radius.sm
        case .md: return Radius.md
        case .lg: return 16
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .sm: return 13
        case .md: return 15
        case .lg: return 16
        }
    }

    var gap: CGFloat {
        switch self {
        case .sm: return 6
        case .md: return 8
        case .lg: return 10
        }
    }
}

enum PlootButtonVariant {
    case primary
    case secondary
    case ghost
    case danger
}

struct PlootButtonStyle: ButtonStyle {
    var variant: PlootButtonVariant = .primary
    var size: PlootButtonSize = .md
    var fullWidth: Bool = false

    @Environment(\.plootPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            .font(.geist(size: size.fontSize, weight: 600))
            .tracking(-0.01 * size.fontSize)
            .foregroundStyle(foreground)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .background(
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .fill(stampedColor)
                    .offset(y: pressed ? 0 : stampOffset)
            )
            .offset(y: pressed ? stampOffset : 0)
            .animation(Motion.springFast, value: pressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: pressed)
    }

    private var stampOffset: CGFloat {
        variant == .ghost ? 0 : 2
    }

    private var background: Color {
        switch variant {
        case .primary: return palette.primary
        case .secondary: return palette.bgElevated
        case .ghost: return .clear
        case .danger: return palette.danger
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary, .danger: return palette.onPrimary
        case .secondary: return palette.fg1
        case .ghost: return palette.fg1
        }
    }

    private var borderColor: Color {
        variant == .ghost ? .clear : palette.borderInk
    }

    private var borderWidth: CGFloat {
        variant == .ghost ? 0 : 2
    }

    private var stampedColor: Color {
        variant == .ghost ? .clear : palette.borderInk
    }
}

extension ButtonStyle where Self == PlootButtonStyle {
    static var plootPrimary: PlootButtonStyle { PlootButtonStyle(variant: .primary) }
    static var plootSecondary: PlootButtonStyle { PlootButtonStyle(variant: .secondary) }
    static var plootGhost: PlootButtonStyle { PlootButtonStyle(variant: .ghost) }
    static var plootDanger: PlootButtonStyle { PlootButtonStyle(variant: .danger) }

    static func ploot(
        _ variant: PlootButtonVariant = .primary,
        size: PlootButtonSize = .md,
        fullWidth: Bool = false
    ) -> PlootButtonStyle {
        PlootButtonStyle(variant: variant, size: size, fullWidth: fullWidth)
    }
}
