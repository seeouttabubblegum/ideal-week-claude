//
//  LCPalette.swift
//  The Ideal Week
//
//  The four colour schemes agreed in the Bubblegum huddle of 2026-08-31:
//
//    "Color Themes: Implementing four schemes: Present (current),
//     Past (pink → blue, blue → yellow, yellow → pink),
//     Future (pink → yellow, blue → pink, yellow → blue), and 50s (grayscale)."
//
//  Past and Future are the two directions of the same three-colour cycle, which
//  is why the book covers read pink/blue, then blue/yellow, then yellow/pink.
//  Nothing here invents a colour: the three hue families are the app's own
//  brand colours, and a palette only decides which family fills which role.
//

import SwiftUI

/// A colour ROLE in the design system. `pink` is the primary accent, `blue` the
/// secondary, `yellow` the CTA fill — whatever hue a palette maps them to.
enum LCHue: String, CaseIterable {
    case pink, blue, yellow
}

/// The shades each hue family ships. The pink family's four values come from the
/// handoff; blue and yellow use the same saturation/brightness offsets from
/// their own base, so a rotated palette keeps identical internal relationships.
enum LCColorVariant: String, CaseIterable {
    case base    // the accent itself
    case deep    // headings / stronger emphasis (pink's is `deepPink`)
    case dark    // pressed and shadowed variants
    case light   // raised and highlighted variants
    case alt     // the warm sibling (pink's rose, yellow's amber) — `yellowAlt`
}

enum LCPalette: String, CaseIterable, Identifiable {
    case present
    case past
    case future
    case fifties

    var id: String { rawValue }

    /// What a stored value falls back to when it is missing or unrecognised.
    static let fallback: LCPalette = .present

    var displayName: String {
        switch self {
        case .present: return "Present"
        case .past:    return "Past"
        case .future:  return "Future"
        case .fifties: return "50s"
        }
    }

    var subtitle: String {
        switch self {
        case .present: return "Pink, blue and yellow as they are today"
        case .past:    return "Pink becomes blue, blue becomes yellow, yellow becomes pink"
        case .future:  return "Pink becomes yellow, blue becomes pink, yellow becomes blue"
        case .fifties: return "Black and white, with every contrast kept"
        }
    }

    /// Which hue family fills the given role in this palette.
    /// 50s keeps the roles in place and greys them, so it maps to itself.
    func hue(for role: LCHue) -> LCHue {
        switch self {
        case .present, .fifties:
            return role
        case .past:
            switch role {
            case .pink:   return .blue
            case .blue:   return .yellow
            case .yellow: return .pink
            }
        case .future:
            switch role {
            case .pink:   return .yellow
            case .blue:   return .pink
            case .yellow: return .blue
            }
        }
    }

    /// The colour to paint for `role` in this palette.
    func resolved(_ role: LCHue, variant: LCColorVariant) -> Color {
        let family = hue(for: role)
        return Color(hex: self == .fifties
                     ? Self.grey(family, variant)
                     : Self.colour(family, variant))
    }

    // MARK: - The three hue families

    /// Pink is the handoff's own set. Blue and yellow derive their deep/dark/light
    /// shades by applying pink's measured HSB offsets (+0.189 S / +0.031 V for
    /// deep, −0.059 V for dark, +0.059 V for light) to their own base, so no
    /// shade was picked by eye.
    private static func colour(_ hue: LCHue, _ variant: LCColorVariant) -> Int {
        switch (hue, variant) {
        case (.pink,   .base):  return 0xDD4298
        case (.pink,   .deep):  return 0xE5197F
        case (.pink,   .dark):  return 0xCE3D8D
        case (.pink,   .light): return 0xEC47A3
        case (.pink,   .alt):   return 0xD933A9

        case (.blue,   .base):  return 0x37C1F1
        case (.blue,   .deep):  return 0x0ABBF9
        case (.blue,   .dark):  return 0x33B5E2
        case (.blue,   .light): return 0x3BCCFF
        case (.blue,   .alt):   return 0x27D9ED

        case (.yellow, .base):  return 0xE4E80F
        case (.yellow, .deep):  return 0xECF000
        case (.yellow, .dark):  return 0xD5D90D
        case (.yellow, .light): return 0xF3F711
        case (.yellow, .alt):   return 0xE4C400   // the handoff's amber `yellowAlt`
        }
    }

    /// 50s: a neutral grey carrying the SAME relative luminance (WCAG) as the
    /// colour it replaces, so every contrast pairing in the app is preserved to
    /// within 0.03 — the CTA still reads, the chips still read, the rings stay
    /// distinguishable by lightness instead of hue. The neumorphic surface,
    /// shadows and ink are deliberately untouched in all four palettes.
    private static func grey(_ hue: LCHue, _ variant: LCColorVariant) -> Int {
        switch (hue, variant) {
        case (.pink,   .base):  return 0x808080   // was 0xDD4298, L 0.215
        case (.pink,   .deep):  return 0x787878   // was 0xE5197F, L 0.189
        case (.pink,   .dark):  return 0x777777   // was 0xCE3D8D, L 0.184
        case (.pink,   .light): return 0x898989   // was 0xEC47A3, L 0.250
        case (.pink,   .alt):   return 0x7C7C7C   // was 0xD933A9, L 0.200

        case (.blue,   .base):  return 0xB3B3B3   // was 0x37C1F1, L 0.453
        case (.blue,   .deep):  return 0xAEAEAE   // was 0x0ABBF9, L 0.424
        case (.blue,   .dark):  return 0xA8A8A8   // was 0x33B5E2, L 0.392
        case (.blue,   .light): return 0xBEBEBE   // was 0x3BCCFF, L 0.513
        case (.blue,   .alt):   return 0xC6C6C6   // was 0x27D9ED, L 0.562

        case (.yellow, .base):  return 0xE0E0E0   // was 0xE4E80F, L 0.742
        case (.yellow, .deep):  return 0xE7E7E7   // was 0xECF000, L 0.802
        case (.yellow, .dark):  return 0xD1D1D1   // was 0xD5D90D, L 0.638
        case (.yellow, .light): return 0xEEEEEE   // was 0xF3F711, L 0.856
        case (.yellow, .alt):   return 0xC5C5C5   // was 0xE4C400, L 0.560
        }
    }

    // MARK: - Ink: the accent as TEXT rather than as a fill

    /// The colour to paint for `role` when it is drawn as **text or a thin glyph
    /// on the app surface**, rather than as a large fill.
    ///
    /// A rotation changes which hue fills a role, and the three families sit at
    /// very different lightnesses — pink reads at 3.5:1 on the surface, yellow at
    /// 1.2:1. So a rotated palette that swapped pink text for yellow text would
    /// leave headings all but invisible. The rule this enforces:
    ///
    ///   *in every palette, a role's ink must contrast against the surface at
    ///   least as well as that same role does in Present.*
    ///
    /// Only the six pairings that would otherwise regress are darkened; every
    /// other pairing already meets its baseline and is returned untouched. In
    /// Present nothing is darkened at all, so `ink` and `resolved` are the same
    /// colour there and the default look cannot shift.
    func ink(_ role: LCHue, deep: Bool = false) -> Color {
        let variant: LCColorVariant = deep ? .deep : .base
        if let darkened = Self.darkenedInk(self, role, variant) {
            return Color(hex: darkened)
        }
        return resolved(role, variant: variant)
    }

    /// Contrast ratios are against the app surface 0xF0F0F5. Present's baselines
    /// are pink 3.48 / 3.87, blue 1.84 / 1.95, yellow 1.17 / 1.09.
    private static func darkenedInk(_ palette: LCPalette,
                                    _ role: LCHue,
                                    _ variant: LCColorVariant) -> Int? {
        switch (palette, role, variant) {
        // Past: pink's role is filled by blue (1.84) and blue's by yellow (1.17).
        case (.past, .pink, .base):   return 0x2789AC   // 1.84 -> 3.51, clears pink's 3.48
        case (.past, .pink, .deep):   return 0x0781AC   // 1.95 -> 3.90, clears pink's 3.87
        case (.past, .blue, .base):   return 0xB7BA0C   // 1.17 -> 1.84, clears blue's 1.84
        case (.past, .blue, .deep):   return 0xB1B400   // 1.09 -> 1.97, clears blue's 1.95
        // Future: pink's role is filled by yellow (1.17).
        case (.future, .pink, .base): return 0x828409   // 1.17 -> 3.52, clears pink's 3.48
        case (.future, .pink, .deep): return 0x7B7D00   // 1.09 -> 3.87, clears pink's 3.87
        default: return nil
        }
    }

    // MARK: - The full-bleed auth cover

    /// Login / Register / Forgot Password paint the whole screen in the deep
    /// shade of the pink role, with shadows tinted to match. Present's four
    /// values are the handoff's own; the others apply pink's measured offsets
    /// (+0.024 S / -0.161 V dark, -0.040 S / +0.102 V light) to their own deep
    /// shade, so a rotated cover never keeps pink shadows on a blue ground.
    var coverBackground: Color { Color(hex: Self.cover(self).background) }

    func coverShadow(dark: Bool) -> Color {
        Color(hex: dark ? Self.cover(self).shadowDark : Self.cover(self).shadowLight)
    }

    /// The cover's link colour. The palette's CTA accent when it clears WCAG's
    /// 3:1 large-text minimum against the cover, and the best available ink when
    /// it does not — Past's blue cover and Future's yellow cover are far too
    /// light to carry a pink or blue link.
    var coverLink: Color { Color(hex: Self.cover(self).link) }

    private static func cover(_ palette: LCPalette)
        -> (background: Int, shadowDark: Int, shadowLight: Int, link: Int) {
        switch palette {
        case .present: return (0xE5197F, 0xBC1066, 0xFF2694, 0xEDEF12) // handoff, unchanged
        case .past:    return (0x0ABBF9, 0x039BD0, 0x14C2FF, 0x2B2B31) // pink on blue is 1.79:1
        case .future:  return (0xECF000, 0xC4C700, 0xFBFF0A, 0x2B2B31) // blue on yellow is 1.69:1
        case .fifties: return (0x787878, 0x4F4F4F, 0x929292, 0xE0E0E0)
        }
    }
}
