//
//  LCPalette.swift
//  The Ideal Week
//
//  Three brand colours, three roles, four schemes.
//
//  Love & Chaos has exactly three colours — the ones on loveandchaos.org:
//
//      pink #FD399A · blue #00BAF1 · yellow #FFF000
//
//  Those hexes are used at FULL STRENGTH everywhere. There are no shades, no
//  tints, no darkened or lightened variants: if a colour appears on screen it is
//  one of these three, exactly as written above. An earlier version of this file
//  derived deep/dark/light shades and nudged colours darker to protect contrast;
//  that produced olive and teal that were not brand colours at all, and it is
//  gone.
//
//  A palette therefore decides ONE thing: which colour plays which role.
//
//      role       Present   Past     Future
//      primary    pink      blue     yellow
//      secondary  blue      yellow   pink
//      tertiary   yellow    pink     blue
//
//  Past and Future are the two directions of the same three-colour cycle, which
//  is why the book covers read pink/blue, then blue/yellow, then yellow/pink.
//  50s greys the three out, each grey carrying the luminance of the colour it
//  replaces so every contrast relationship in the app survives the switch.
//

import SwiftUI

/// A colour ROLE. `pink` is the primary accent, `blue` the secondary, `yellow`
/// the tertiary — whichever brand colour a palette hands them.
///
/// The cases are named after the colours they carry in Present because that is
/// how the whole codebase already reads (`LCColor.pink` is the primary accent).
enum LCHue: String, CaseIterable {
    case pink, blue, yellow
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

    /// Which brand colour fills the given role in this palette.
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

    /// The colour to paint for `role`. Always one of the three brand hexes
    /// (or, in 50s, one of the three greys) — never a shade of one.
    func resolved(_ role: LCHue) -> Color {
        Color(hex: hex(hue(for: role)))
    }

    // MARK: - Keeping the lightest colour readable

    /// Yellow is far too light to read as text: against the app surface it
    /// manages 1.04:1, where pink reaches 2.97 and blue 1.99. Rather than darken
    /// it — which would make it a different colour, and no longer the brand's —
    /// yellow type is given a hard offset shadow in blue, exactly the treatment
    /// the login cover's subtitle has always used. This returns that shadow
    /// colour, or nil when the role's colour reads on its own.
    func textShadow(for role: LCHue) -> Color? {
        let family = hue(for: role)
        guard needsShadow(family) else { return nil }
        return Color(hex: hex(Self.shadowPartner(family)))
    }

    /// Measured against the surface 0xF0F0F5: only yellow falls below 1.5:1.
    /// The 50s greys are chosen to read unaided, so nothing there needs it.
    /// `LCPaletteTests` re-derives this from luminance for every palette so the
    /// shortcut cannot drift away from the measurement behind it.
    func needsShadow(_ family: LCHue) -> Bool {
        self != .fifties && family == .yellow
    }

    /// Yellow borrows blue's silhouette. The other two are listed for
    /// completeness; neither is light enough to ever ask.
    static func shadowPartner(_ family: LCHue) -> LCHue {
        switch family {
        case .yellow: return .blue
        case .blue:   return .pink
        case .pink:   return .blue
        }
    }

    /// Long-form copy. A whole paragraph wearing the silhouette shadow reads as
    /// outlined and heavy, so where a palette would hand this role the colour
    /// that needs the shadow, body text takes the pink instead. Still one of the
    /// three, still at full strength.
    func bodyResolved(_ role: LCHue) -> Color {
        let family = hue(for: role)
        return Color(hex: hex(needsShadow(family) ? .pink : family))
    }

    // MARK: - The full-bleed auth cover

    /// The cover paints the primary accent and its links are the tertiary, so
    /// the pairing is accent-on-accent and the surface rule does not apply. When
    /// those two sit too close — pink links on Past's blue ground are 1.49:1 —
    /// the link takes a hard shadow in the one brand colour left over.
    var coverLinkShadow: Color? {
        let ground = hue(for: .pink)
        let link = hue(for: .yellow)
        guard Self.contrast(hex(ground), hex(link)) < 2.5 else { return nil }
        guard let third = LCHue.allCases.first(where: { $0 != ground && $0 != link })
        else { return nil }
        return Color(hex: hex(third))
    }

    private static func contrast(_ a: Int, _ b: Int) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func luminance(_ hex: Int) -> Double {
        func channel(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    // MARK: - The three colours

    private func hex(_ family: LCHue) -> Int {
        self == .fifties ? Self.grey(family) : Self.brand(family)
    }

    /// loveandchaos.org, sampled from the site's own stylesheet.
    private static func brand(_ family: LCHue) -> Int {
        switch family {
        case .pink:   return 0xFD399A
        case .blue:   return 0x00BAF1
        case .yellow: return 0xFFF000
        }
    }

    /// 50s: three neutral greys.
    ///
    /// These used to carry the exact luminance of the colours they replace, on
    /// the theory that every contrast pairing would then survive. It does not
    /// work: the coloured palettes lean on HUE difference as much as luminance —
    /// blue type on a pink band is only 1.48:1 and reads purely because the hues
    /// differ. Strip the hue and that pairing becomes grey mush, which is exactly
    /// what happened ("FIX" at 1.48:1, "MY IDEAL WEEK" at 2.00:1, the CTA capsule
    /// at 1.04:1 against the surface).
    ///
    /// So the greys are spaced for greyscale instead, keeping the same ORDER —
    /// primary darkest, tertiary lightest. Every pairing the app actually draws
    /// now clears 3:1, and the CTA separates from the surface at 2.42:1:
    ///
    ///     primary on surface        11.62:1      secondary on surface   3.43:1
    ///     secondary on the band      3.39:1      tertiary on surface    2.42:1
    ///     ink on tertiary            5.12:1      white on primary      13.20:1
    private static func grey(_ family: LCHue) -> Int {
        switch family {
        case .pink:   return 0x303030   // bands, headings, body
        case .blue:   return 0x818181   // titles, labels on a band
        case .yellow: return 0x9C9C9C   // CTA fills
        }
    }
}
