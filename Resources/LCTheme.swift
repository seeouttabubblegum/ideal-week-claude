//
//  LCTheme.swift
//  The Ideal Week
//
//  Single source of truth for the Love & Chaos visual system — updated to the
//  2026-07 neumorphic ("soft UI") redesign handoff
//  (HANDOFF/design_handoff_ideal_week_neumorphic/README.md).
//  Colours, typography, radii, the neumorphic shadow recipe and the 4 preset
//  colour themes all live here.
//

import SwiftUI

// MARK: - Brand palette (exact values from the handoff README)

enum LCColor {
    /// Every screen background AND card — cards ARE the surface, differentiated
    /// only by shadow. The app never uses pure white cards.
    static let surface = Color(hex: 0xF0F0F5)

    static let pink     = Color(hex: 0xDD4298) // primary accent, values, selected states, links
    static let deepPink = Color(hex: 0xE5197F) // HH Samuel headings, book-title pink
    static let blue     = Color(hex: 0x37C1F1) // secondary accent, "NEXT:", info, save-check
    static let yellow   = Color(hex: 0xE4E80F) // key CTA fills, bell/plus highlights
    static let yellowAlt = Color(hex: 0xE4C400) // occasional star/warm accent

    static let ink           = Color(hex: 0x2B2B31) // labels, ideal titles
    static let textSecondary = Color(hex: 0x6B6B74) // subtitles, helper copy
    static let textMuted     = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.55) // stats, inactive

    /// Neumorphic shadow pair.
    static let shadowDark  = Color(hex: 0xCBCCD4)
    static let shadowLight = Color.white

    /// Feathered divider base grey (used at 0.4 opacity mid-stop).
    static let dividerGrey = Color(hex: 0xA0A2B2)

    // Legacy dot tokens (kept for call-site compatibility; dots are now SUNKEN
    // pink/blue per the handoff).
    static let dotPink        = pink
    static let dotPinkDark    = Color(hex: 0xCE3D8D)
    static let dotPinkLight   = Color(hex: 0xEC47A3)
    static let dotEmptyShadow = shadowDark
    static let buttonShadow   = shadowDark
}

// MARK: - Radii & layout metrics (handoff "Design Tokens")

enum LCRadius {
    static let card: CGFloat = 18      // card / grouped-list container
    static let field: CGFloat = 15     // inset field 14–16
    static let chip: CGFloat = 12      // small chip
    static let sheetTop: CGFloat = 34  // sheet top corners
    static let pill: CGFloat = 999     // pill buttons
}

enum LCMetrics {
    /// Minimum height for any tappable grouped row (finger-friendly hard rule).
    static let rowHeight: CGFloat = 56
    /// Screen horizontal margin to card edge.
    static let screenMargin: CGFloat = 16
    /// Card interior padding (18–24).
    static let cardPadding: CGFloat = 20
    /// Legacy 77-pt rhythm (older layouts still reference it).
    static let rhythm: CGFloat = 77
    static func r(_ multiple: CGFloat) -> CGFloat { rhythm * multiple }
}

// MARK: - Neumorphism shadow recipe (handoff exact)
//
// RAISED  (anything you press):  5px 5px 12px #CBCCD4, -5px -5px 12px #FFFFFF
//   scaled down for small controls: 4/9 for ~36px, 3/7 for 30–34px chips.
// SUNKEN  (anything you fill in / progress): inset 3px 3px 6px #CBCCD4,
//   inset -3px -3px 6px #FFFFFF  (big wells: inset 6px 6px 14px).
// CSS blur ≈ 2 × SwiftUI shadow radius — the helpers below take CSS values
// and halve the blur internally.

enum LCNeumorphism {
    static let raisedOffset: CGFloat = 5, raisedBlur: CGFloat = 12
    static let raisedOffsetMedium: CGFloat = 4, raisedBlurMedium: CGFloat = 9   // ~36px control
    static let raisedOffsetSmall: CGFloat = 3, raisedBlurSmall: CGFloat = 7     // 30–34px chip
    static let sunkenOffset: CGFloat = 3, sunkenBlur: CGFloat = 6
    static let sunkenOffsetLarge: CGFloat = 6, sunkenBlurLarge: CGFloat = 14    // big wells
}

// MARK: - Typography (handoff exact)

extension Font {
    /// H.H. Samuel — ALL display headings & category titles, uppercase.
    static func hhSamuel(_ size: CGFloat) -> Font {
        .custom("H.H.Samuel-Regular", size: size)
    }

    /// H.H. Samuel Small Caps variant.
    static func hhSamuelSC(_ size: CGFloat) -> Font {
        .custom("H.H.SamuelSC", size: size)
    }

    /// Newsreader italic (500) — Ideal titles ONLY ("Walk The Dog"), with the
    /// imprinted letterpress shadow (`.imprinted()`).
    static func idealTitle(_ size: CGFloat) -> Font {
        .custom("Newsreader-MediumItalic", size: size)
    }

    /// Manrope — all UI text. Weights: 400/500/600/700/800.
    static func manrope(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium:   name = "Manrope-Medium"
        case .semibold: name = "Manrope-SemiBold"
        case .bold:     name = "Manrope-Bold"
        case .heavy, .black: name = "Manrope-ExtraBold"
        default:        name = "Manrope-Regular"
        }
        return .custom(name, size: size)
    }

    /// Open Sans Condensed Bold — auth/cover subtitle treatment.
    static func coverSubtitle(_ size: CGFloat) -> Font {
        .custom("OpenSansCondensed-Bold", size: size)
    }

    // Legacy aliases still referenced by older call sites.
    static func ebGaramondItalic(_ size: CGFloat) -> Font {
        .custom("EBGaramond-BoldItalic", size: size)
    }
    static func ebGaramondItalicRegular(_ size: CGFloat) -> Font {
        .custom("EBGaramond-Italic", size: size)
    }
    /// Oswald Bold — occasional bold display ("How You Doin'?").
    static func lcTitle(_ size: CGFloat) -> Font {
        .custom("Oswald-Bold", size: size)
    }
    /// Source Sans 3 — mood-review body copy.
    static func lcBody(_ size: CGFloat) -> Font {
        .custom("SourceSans3-Regular", size: size)
    }
}

// MARK: - Imprinted / letterpress text (handoff exact)
// CSS: text-shadow: 0 1.5px 0.5px rgba(255,255,255,0.95), 0 -1px 1.2px rgba(0,0,0,0.4)

extension View {
    /// Letterpress effect used on all Ideal titles so they read pressed into
    /// the surface.
    func imprinted() -> some View {
        self
            .shadow(color: .white.opacity(0.95), radius: 0.25, x: 0, y: 1.5)
            .shadow(color: .black.opacity(0.4), radius: 0.6, x: 0, y: -1)
    }
}

// MARK: - Preset themes (4 to start; client moves to custom later)

/// One preset colour theme. A theme is a single value (palette roles), not loose RGB —
/// so adding a "Custom" theme later is just another `LCThemePreset`.
struct LCThemePreset: Identifiable, Equatable {
    let id: String
    let name: String
    /// Primary brand colour (pink role in Theme 1) — titles, filled dots, NEXT.
    let primary: Color
    /// Secondary accent (yellow role) — "+" add buttons, key CTAs.
    let secondary: Color
    /// Tertiary accent (blue role) — category icons, toggles.
    let tertiary: Color
    let ink: Color
    let surface: Color
}

enum LCThemes {
    /// Theme 1 — the official LC brand palette (source of truth).
    static let lc = LCThemePreset(
        id: "lc",
        name: "Love & Chaos",
        primary: LCColor.pink,
        secondary: LCColor.yellow,
        tertiary: LCColor.blue,
        ink: LCColor.ink,
        surface: LCColor.surface
    )

    // Themes 2–4: placeholders (variations off Theme 1). Exact colours TBD from client —
    // swap the hex values when provided. The architecture/picker works today.
    static let two = LCThemePreset(
        id: "preset2", name: "Preset 2 (TBD)",
        primary: Color(hex: 0x7C4DFF), secondary: Color(hex: 0xFFC400),
        tertiary: Color(hex: 0x26C6DA), ink: LCColor.ink, surface: LCColor.surface
    )
    static let three = LCThemePreset(
        id: "preset3", name: "Preset 3 (TBD)",
        primary: Color(hex: 0xFF6F61), secondary: Color(hex: 0xFFD54F),
        tertiary: Color(hex: 0x4DB6AC), ink: LCColor.ink, surface: LCColor.surface
    )
    static let four = LCThemePreset(
        id: "preset4", name: "Preset 4 (TBD)",
        primary: Color(hex: 0x2E7D32), secondary: Color(hex: 0xC0CA33),
        tertiary: Color(hex: 0x29B6F6), ink: LCColor.ink, surface: LCColor.surface
    )

    /// All presets, in picker order. Theme 1 first.
    static let all: [LCThemePreset] = [lc, two, three, four]

    static func preset(id: String) -> LCThemePreset { all.first { $0.id == id } ?? lc }
}

// Note: `Color(hex: Int, opacity:)` already exists in Other/Extensions.swift —
// the `Color(hex: 0x…)` literals above resolve to that initializer.
