import SwiftUI
import UIKit
import CoreText

// MARK: - Font registration

enum PlootFonts {
    private static let familyNames: [String] = [
        "Fraunces-Variable",
        "Geist-Variable",
        "JetBrainsMono-Variable"
    ]

    private static var didRegister = false

    /// Call once on app launch to ensure fonts are available even if UIAppFonts
    /// isn't picking them up (e.g. in previews, snapshot tests, SwiftUI Playgrounds).
    static func register() {
        guard !didRegister else { return }
        didRegister = true

        for name in familyNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                #if DEBUG
                print("[Ploot] Missing font file: \(name).ttf")
                #endif
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                #if DEBUG
                if let err = error?.takeRetainedValue() {
                    let code = CFErrorGetCode(err)
                    // 105 = kCTFontManagerErrorAlreadyRegistered — fine.
                    if code != 105 {
                        print("[Ploot] Font registration failed for \(name): \(err)")
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Variable axis helpers

private enum FontAxis {
    // CoreText identifies axes by a 4-byte FourCharCode interpreted as an Int.
    static let wght = fourCC("wght")  // weight
    static let opsz = fourCC("opsz")  // optical size
    static let soft = fourCC("SOFT")  // Fraunces softness (may be absent in subsetted builds)

    static func fourCC(_ s: String) -> Int {
        var code = 0
        for byte in s.utf8 { code = (code << 8) | Int(byte) }
        return code
    }
}

private enum VariableFont {
    /// Build a UIFont with explicit variable-font axis values. Unsupported axes
    /// are silently ignored by CoreText, so passing SOFT to a build without
    /// that axis is harmless.
    static func make(
        family: String,
        size: CGFloat,
        weight: CGFloat,
        opsz: CGFloat? = nil,
        soft: CGFloat? = nil
    ) -> UIFont {
        var variations: [Int: CGFloat] = [FontAxis.wght: weight]
        if let opsz { variations[FontAxis.opsz] = opsz }
        if let soft { variations[FontAxis.soft] = soft }

        let attrs: [UIFontDescriptor.AttributeName: Any] = [
            .family: family,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations
        ]
        let descriptor = UIFontDescriptor(fontAttributes: attrs)
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Public font builders

extension Font {
    /// Fraunces — variable serif. Used for display, headings, italic flourishes.
    static func fraunces(
        size: CGFloat,
        weight: CGFloat = 500,
        opsz: CGFloat? = nil,
        soft: CGFloat? = nil,
        italic: Bool = false
    ) -> Font {
        let ui = VariableFont.make(
            family: "Fraunces",
            size: size,
            weight: weight,
            opsz: opsz ?? size,
            soft: soft
        )
        var font = Font(ui)
        if italic { font = font.italic() }
        return font
    }

    /// Geist — variable geometric sans. UI, body, buttons, task titles.
    static func geist(size: CGFloat, weight: CGFloat = 400) -> Font {
        let ui = VariableFont.make(family: "Geist", size: size, weight: weight)
        return Font(ui)
    }

    /// JetBrains Mono — eyebrows, meta counts, timestamps. Always uppercase in UI.
    static func jetBrainsMono(size: CGFloat, weight: CGFloat = 400) -> Font {
        let ui = VariableFont.make(family: "JetBrains Mono", size: size, weight: weight)
        return Font(ui)
    }
}

// MARK: - Semantic text styles

/// Matches the CSS scale in colors_and_type.css. Line heights are encoded as
/// explicit `lineSpacing` so SwiftUI text actually lays out the way the HTML
/// preview does — SwiftUI's default leading is tighter than CSS line-height.
struct PlootTextStyle {
    let font: Font
    let lineHeight: CGFloat    // effective line-height in points
    let tracking: CGFloat      // letter-spacing in points (CSS em * size)
    let defaultSize: CGFloat   // used to derive lineSpacing offset
}

enum TextStyles {
    // display: Fraunces 56/1.02, letter-spacing -0.02em, weight 500, SOFT 50, opsz 144
    static let display = PlootTextStyle(
        font: .fraunces(size: 56, weight: 500, opsz: 144, soft: 50),
        lineHeight: 56 * 1.02,
        tracking: 56 * -0.02,
        defaultSize: 56
    )
    // h1: Fraunces 40/1.08, -0.015em, SOFT 40, opsz 100
    static let h1 = PlootTextStyle(
        font: .fraunces(size: 40, weight: 500, opsz: 100, soft: 40),
        lineHeight: 40 * 1.08,
        tracking: 40 * -0.015,
        defaultSize: 40
    )
    // h2: Fraunces 28/1.18, -0.01em
    static let h2 = PlootTextStyle(
        font: .fraunces(size: 28, weight: 500),
        lineHeight: 28 * 1.18,
        tracking: 28 * -0.01,
        defaultSize: 28
    )
    // h3: Geist 20/1.3, weight 600, -0.005em
    static let h3 = PlootTextStyle(
        font: .geist(size: 20, weight: 600),
        lineHeight: 20 * 1.3,
        tracking: 20 * -0.005,
        defaultSize: 20
    )
    // title: Geist 17/1.35, weight 600
    static let title = PlootTextStyle(
        font: .geist(size: 17, weight: 600),
        lineHeight: 17 * 1.35,
        tracking: 0,
        defaultSize: 17
    )
    // body: Geist 15/1.5
    static let body = PlootTextStyle(
        font: .geist(size: 15, weight: 400),
        lineHeight: 15 * 1.5,
        tracking: 0,
        defaultSize: 15
    )
    static let bodySmall = PlootTextStyle(
        font: .geist(size: 13, weight: 400),
        lineHeight: 13 * 1.45,
        tracking: 0,
        defaultSize: 13
    )
    // caption: Geist 12/1.35, weight 500 (fg3)
    static let caption = PlootTextStyle(
        font: .geist(size: 12, weight: 500),
        lineHeight: 12 * 1.35,
        tracking: 0,
        defaultSize: 12
    )
    // eyebrow: JetBrains Mono 11/1.2, weight 500, +0.08em, uppercase
    static let eyebrow = PlootTextStyle(
        font: .jetBrainsMono(size: 11, weight: 500),
        lineHeight: 11 * 1.2,
        tracking: 11 * 0.08,
        defaultSize: 11
    )
    // mono: JetBrains Mono 13/1.4
    static let mono = PlootTextStyle(
        font: .jetBrainsMono(size: 13, weight: 400),
        lineHeight: 13 * 1.4,
        tracking: 0,
        defaultSize: 13
    )
    // serif italic — matches .t-serif-italic (Fraunces italic, SOFT 100)
    static func serifItalic(size: CGFloat) -> PlootTextStyle {
        PlootTextStyle(
            font: .fraunces(size: size, weight: 500, opsz: size, soft: 100, italic: true),
            lineHeight: size * 1.25,
            tracking: 0,
            defaultSize: size
        )
    }
}

// MARK: - View modifier

extension View {
    func textStyle(_ style: PlootTextStyle) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(max(0, style.lineHeight - style.defaultSize))
    }
}

// MARK: - Text convenience

extension Text {
    /// Applies text-transform: uppercase + eyebrow styling. Use for meta chips,
    /// section labels, timestamp eyebrows.
    func eyebrow() -> some View {
        self
            .textCase(.uppercase)
            .textStyle(TextStyles.eyebrow)
    }
}
