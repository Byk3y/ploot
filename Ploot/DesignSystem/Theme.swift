import SwiftUI

// MARK: - Theme

enum PlootTheme: String, CaseIterable, Identifiable, Hashable {
    case light
    case cocoa

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .cocoa: return .dark
        }
    }

    var palette: PlootPalette {
        switch self {
        case .light: return .light
        case .cocoa: return .cocoa
        }
    }

    var shadows: PlootShadows {
        switch self {
        case .light: return .light
        case .cocoa: return .cocoa
        }
    }
}

// MARK: - Environment

private struct PlootThemeKey: EnvironmentKey {
    static let defaultValue: PlootTheme = .light
}

extension EnvironmentValues {
    var plootTheme: PlootTheme {
        get { self[PlootThemeKey.self] }
        set { self[PlootThemeKey.self] = newValue }
    }

    var plootPalette: PlootPalette { plootTheme.palette }
    var plootShadows: PlootShadows { plootTheme.shadows }
}

extension View {
    func plootTheme(_ theme: PlootTheme) -> some View {
        environment(\.plootTheme, theme)
            .preferredColorScheme(theme.colorScheme)
    }
}

// MARK: - Palette

struct PlootPalette {
    // Brand — Clay scale
    let clay50: Color
    let clay100: Color
    let clay200: Color
    let clay300: Color
    let clay400: Color
    let clay500: Color
    let clay600: Color
    let clay700: Color
    let clay800: Color
    let clay900: Color

    // Ink — warm near-blacks
    let ink50: Color
    let ink100: Color
    let ink200: Color
    let ink300: Color
    let ink400: Color
    let ink500: Color
    let ink600: Color
    let ink700: Color
    let ink800: Color
    let ink900: Color

    // Accents
    let forest100: Color
    let forest500: Color
    let forest700: Color

    let butter100: Color
    let butter300: Color
    let butter500: Color

    let plum100: Color
    let plum500: Color

    let sky100: Color
    let sky500: Color

    // Surfaces
    let bg: Color
    let bgElevated: Color
    let bgSunken: Color
    let bgInverse: Color

    // Foregrounds
    let fg1: Color
    let fg2: Color
    let fg3: Color
    let fgInverse: Color
    let fgBrand: Color

    // Borders
    let border: Color
    let borderStrong: Color
    let borderInk: Color

    // Semantic roles
    let primary: Color
    let primaryHover: Color
    let primaryPress: Color
    let onPrimary: Color

    let success: Color
    let warning: Color
    let danger: Color
    let info: Color
}

extension PlootPalette {
    // Shared accent scales are identical across themes — only surfaces and
    // semantic roles shift. Mirrors colors_and_type.css exactly.
    private static let clay50  = Color(hex: 0xFFF5ED)
    private static let clay100 = Color(hex: 0xFFE5D1)
    private static let clay200 = Color(hex: 0xFFC9A6)
    private static let clay300 = Color(hex: 0xFFA06F)
    private static let clay400 = Color(hex: 0xFF7A3D)
    private static let clay500 = Color(hex: 0xFF6B35)
    private static let clay600 = Color(hex: 0xE8541F)
    private static let clay700 = Color(hex: 0xB83D14)
    private static let clay800 = Color(hex: 0x8A2D0F)
    private static let clay900 = Color(hex: 0x4A1807)

    private static let ink50  = Color(hex: 0xFAF8F5)
    private static let ink100 = Color(hex: 0xF2EDE5)
    private static let ink200 = Color(hex: 0xE4DDD0)
    private static let ink300 = Color(hex: 0xC9BFAE)
    private static let ink400 = Color(hex: 0x8A8070)
    private static let ink500 = Color(hex: 0x5B5245)
    private static let ink600 = Color(hex: 0x3D3528)
    private static let ink700 = Color(hex: 0x2A2118)
    private static let ink800 = Color(hex: 0x1A1410)
    private static let ink900 = Color(hex: 0x0D0906)

    private static let forest100 = Color(hex: 0xD8E8DD)
    private static let forest500 = Color(hex: 0x2D7A4E)
    private static let forest700 = Color(hex: 0x1A5233)

    private static let butter100 = Color(hex: 0xFFF4C9)
    private static let butter300 = Color(hex: 0xFFD952)
    private static let butter500 = Color(hex: 0xF5B800)

    private static let plum100 = Color(hex: 0xF3D9E8)
    private static let plum500 = Color(hex: 0xB8357A)

    private static let sky100 = Color(hex: 0xD6E9F5)
    private static let sky500 = Color(hex: 0x3C8BC7)

    static let light = PlootPalette(
        clay50: clay50, clay100: clay100, clay200: clay200, clay300: clay300,
        clay400: clay400, clay500: clay500, clay600: clay600, clay700: clay700,
        clay800: clay800, clay900: clay900,
        ink50: ink50, ink100: ink100, ink200: ink200, ink300: ink300,
        ink400: ink400, ink500: ink500, ink600: ink600, ink700: ink700,
        ink800: ink800, ink900: ink900,
        forest100: forest100, forest500: forest500, forest700: forest700,
        butter100: butter100, butter300: butter300, butter500: butter500,
        plum100: plum100, plum500: plum500,
        sky100: sky100, sky500: sky500,
        bg: ink50,
        bgElevated: .white,
        bgSunken: ink100,
        bgInverse: ink800,
        fg1: ink800,
        fg2: ink600,
        fg3: ink400,
        fgInverse: ink50,
        fgBrand: clay600,
        border: ink200,
        borderStrong: ink300,
        borderInk: ink800,
        primary: clay500,
        primaryHover: clay600,
        primaryPress: clay700,
        onPrimary: .white,
        success: forest500,
        warning: butter500,
        danger: plum500,
        info: sky500
    )

    static let cocoa = PlootPalette(
        clay50: clay50, clay100: clay100, clay200: clay200, clay300: clay300,
        clay400: clay400, clay500: clay500, clay600: clay600, clay700: clay700,
        clay800: clay800, clay900: clay900,
        ink50: ink50, ink100: ink100, ink200: ink200, ink300: ink300,
        ink400: ink400, ink500: ink500, ink600: ink600, ink700: ink700,
        ink800: ink800, ink900: ink900,
        forest100: forest100, forest500: forest500, forest700: forest700,
        butter100: butter100, butter300: butter300, butter500: butter500,
        plum100: plum100, plum500: plum500,
        sky100: sky100, sky500: sky500,
        bg: Color(hex: 0x3A2A20),
        bgElevated: Color(hex: 0x4A3626),
        bgSunken: Color(hex: 0x2E2018),
        bgInverse: ink50,
        fg1: Color(hex: 0xFBF1E2),
        fg2: Color(hex: 0xD9C9B3),
        fg3: Color(hex: 0x9D8972),
        fgInverse: ink800,
        fgBrand: clay300,
        border: Color(hex: 0x5C4532),
        borderStrong: Color(hex: 0x78593F),
        borderInk: Color(hex: 0x1A1008),
        primary: clay400,
        primaryHover: clay300,
        primaryPress: clay500,
        onPrimary: .white,
        success: forest500,
        warning: butter500,
        danger: plum500,
        info: sky500
    )
}

// MARK: - Radii

enum Radius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let full: CGFloat = 9999
}

// MARK: - Spacing (4px base)

enum Spacing {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
    static let s10: CGFloat = 40
    static let s12: CGFloat = 48
    static let s16: CGFloat = 64
}

// MARK: - Shadows

struct PlootShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct PlootShadows {
    let xs: [PlootShadow]
    let sm: [PlootShadow]
    let md: [PlootShadow]
    let lg: [PlootShadow]
    // The "pop" shadow is NOT a blurred shadow — it is a hard-edge offset of
    // the border-ink color. Implemented by StampedShadow, not by .shadow().
    let popOffset: CGFloat
    let popOffsetLarge: CGFloat
}

extension PlootShadows {
    static let light = PlootShadows(
        xs: [PlootShadow(color: Color(hex: 0x1A1410, alpha: 0.05), radius: 2, x: 0, y: 1)],
        sm: [
            PlootShadow(color: Color(hex: 0x1A1410, alpha: 0.06), radius: 6, x: 0, y: 2),
            PlootShadow(color: Color(hex: 0x1A1410, alpha: 0.04), radius: 2, x: 0, y: 1)
        ],
        md: [
            PlootShadow(color: Color(hex: 0x1A1410, alpha: 0.08), radius: 16, x: 0, y: 6),
            PlootShadow(color: Color(hex: 0x1A1410, alpha: 0.04), radius: 4, x: 0, y: 2)
        ],
        lg: [
            PlootShadow(color: Color(hex: 0x1A1410, alpha: 0.12), radius: 36, x: 0, y: 16),
            PlootShadow(color: Color(hex: 0x1A1410, alpha: 0.06), radius: 8, x: 0, y: 4)
        ],
        popOffset: 2,
        popOffsetLarge: 4
    )

    static let cocoa = PlootShadows(
        xs: [PlootShadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)],
        sm: [PlootShadow(color: Color.black.opacity(0.40), radius: 6, x: 0, y: 2)],
        md: [PlootShadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 6)],
        lg: [PlootShadow(color: Color.black.opacity(0.50), radius: 36, x: 0, y: 16)],
        popOffset: 2,
        popOffsetLarge: 4
    )
}

// MARK: - Motion

enum Motion {
    static let durFast: Double = 0.14
    static let durBase: Double = 0.22
    static let durSlow: Double = 0.38

    // cubic-bezier(0.22, 1, 0.36, 1) — "ease-out" from the CSS tokens.
    static func easeOut(duration: Double = durBase) -> Animation {
        .timingCurve(0.22, 1.0, 0.36, 1.0, duration: duration)
    }

    // cubic-bezier(0.65, 0, 0.35, 1) — "ease-in-out".
    static func easeInOut(duration: Double = durBase) -> Animation {
        .timingCurve(0.65, 0.0, 0.35, 1.0, duration: duration)
    }

    // The brand is playful — these springs overshoot, they do not glide.
    // Tuned to feel like the CSS ease-spring (0.34, 1.56, 0.64, 1): a visible
    // bounce, not a damped ramp.
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.62, blendDuration: 0.1)
    static let springFast = Animation.spring(response: 0.28, dampingFraction: 0.58, blendDuration: 0.05)
    static let springSoft = Animation.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0.15)
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
