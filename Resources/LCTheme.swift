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

    // Three brand colours, used at FULL STRENGTH — see LCPalette. There are no
    // shades or tints: `pink`, `blue` and `yellow` are ROLES, and a palette
    // decides which of loveandchaos.org's three hexes each role carries.
    //   primary #FD399A · secondary #00BAF1 · tertiary #FFF000  (Present)
    private static var palette: LCPalette { ThemeManager.current }

    static var pink: Color   { palette.resolved(.pink) }    // primary — values, selected states, links, headings
    static var blue: Color   { palette.resolved(.blue) }    // secondary — "NEXT:", info, save-check, titles
    static var yellow: Color { palette.resolved(.yellow) }  // tertiary — key CTA fills, bell/plus highlights

    /// The colour a role carries in the current palette. Equivalent to the
    /// three accessors above; useful where the role arrives as a value.
    static func resolved(_ role: LCHue) -> Color { palette.resolved(role) }

    /// The brand colour itself, ignoring which role carries it. See
    /// `LCPalette.colour(of:)`.
    static func brand(_ family: LCHue) -> Color { palette.colour(of: family) }

    /// The role's colour, but never the unreadable one — that gives way to pink
    /// rather than ink. See `LCPalette.chromatic(_:)`.
    static func chromatic(_ role: LCHue) -> Color { palette.chromatic(role) }

    /// The hard offset shadow that keeps an accent readable when the palette has
    /// handed that role a colour too light to stand on its own — nil when it
    /// reads unaided. Prefer the `.accentText(_:)` modifier, which applies both
    /// the colour and this shadow together.
    static func textShadow(for role: LCHue) -> Color? { palette.textShadow(for: role) }

    /// A glyph sitting inside a filled shape — a boxed icon: the close X in its
    /// raised circle, the pencil on the profile's CTA button, the save
    /// checkmark.
    ///
    /// Keeps the accent the design asks for while it still separates from what
    /// is behind it, and falls back to white/ink when a rotation drops it below
    /// that. The bar is 1.5:1 — except where the handoff itself ships a weaker
    /// pairing (the save button's count badge is pink on blue at 1.49:1), and
    /// there Present's own ratio becomes the bar. So Present is a no-op by
    /// construction and the default look can never be second-guessed; only
    /// pairings a rotation genuinely breaks are rescued.
    ///
    /// Unlike `accentText`, this adds no silhouette shadow: inside a 40pt circle
    /// a hard offset reads as misregistration rather than an outline.
    ///
    /// `onFill` is the ROLE the shape is filled with, or nil for the app surface.
    static func glyph(_ role: LCHue, onFill fillRole: LCHue? = nil) -> Color {
        let fill = fillRole.map { palette.resolved($0) } ?? surface
        let presentFill = fillRole.map { LCPalette.present.resolved($0) } ?? surface
        let bar = min(1.5, contrast(LCPalette.present.resolved(role), presentFill))
        let accent = palette.resolved(role)
        return contrast(accent, fill) >= bar ? accent : contrastingInk(on: fill)
    }

    /// Foreground for text or glyphs drawn ON an accent fill.
    ///
    /// The handoff's own rule is white on the darker accents, ink on the light
    /// ones, and this reproduces it: white wherever white still clears WCAG's
    /// 3:1 large-text minimum, ink everywhere else. Picking purely by "whichever
    /// contrasts more" would flip pink chips to dark text — white on #FD399A is
    /// 3.37:1 and ink is 4.11:1 — which is more readable but not the design.
    /// White can never end up on yellow: there it manages 1.06:1.
    static func contrastingInk(on fill: Color) -> Color {
        contrast(.white, fill) >= 3 ? .white : ink
    }

    /// WCAG relative-luminance contrast ratio between two colours.
    static func contrast(_ a: Color, _ b: Color) -> Double {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func relativeLuminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    static let ink           = Color(hex: 0x2B2B31) // labels, ideal titles
    static let textSecondary = Color(hex: 0x6B6B74) // subtitles, helper copy
    static let textMuted     = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.55) // stats, inactive

    /// Neumorphic shadow pair.
    static let shadowDark  = Color(hex: 0xCBCCD4)
    static let shadowLight = Color.white

    /// Feathered divider base grey (used at 0.4 opacity mid-stop).
    static let dividerGrey = Color(hex: 0xA0A2B2)

    // Legacy dot token (kept for call-site compatibility; dots are now SUNKEN
    // primary-accent per the handoff).
    static var dotPink: Color      { pink }
    static let dotEmptyShadow = shadowDark
    static let buttonShadow   = shadowDark
}

/// The full-bleed cover shared by Login, Register and Forgot Password.
///
/// The ground is the primary accent and the links the tertiary, so the cover
/// rotates with everything else. Its two neumorphic shadows are deliberately
/// NEUTRAL rather than a tint of the ground: tinting them would mean inventing a
/// fourth and fifth colour, and black/white at low opacity gives the same depth
/// on a pink, a blue, a yellow or a grey cover alike.
enum LCAuthCover {
    static var background: Color  { LCColor.pink }
    static var link: Color        { LCColor.yellow }
    static let shadowDark  = Color.black.opacity(0.22)
    static let shadowLight = Color.white.opacity(0.28)

    /// Text and glyphs on the cover. White or ink, whichever reads better on the
    /// ground the palette painted — neither is a shade of a brand colour.
    static var foreground: Color  { LCColor.contrastingInk(on: background) }

    /// A hard shadow behind the links, in the third brand colour, for the
    /// palettes where link and ground sit too close to separate on their own.
    static var linkShadow: Color? { ThemeManager.current.coverLinkShadow }
}

/// Paints text or a glyph in one of the three brand colours — and, when the
/// palette has handed that role a colour too light to read, gives it the hard
/// offset shadow that makes it legible without changing the colour itself.
/// Use this anywhere an accent is the INK; plain fills keep `.foregroundColor`.
extension View {
    /// Text or a thin glyph in an accent.
    ///
    /// On the app surface, a colour that cannot be read there is not outlined or
    /// darkened — the text is simply drawn in the app's ink instead. Yellow at
    /// 1.04:1 has no version of itself that works on white, and a keyline around
    /// every yellow word reads as noise once it is on more than a title.
    ///
    /// - Parameter backdrop: the ROLE whose colour sits behind this text, or nil
    ///   for the surface. Text on a coloured fill keeps the design's own pairing:
    ///   the category band wants its accent label, not black.
    func accentText(_ role: LCHue, on backdrop: LCHue? = nil) -> some View {
        modifier(AccentTextStyle(role: role, backdrop: backdrop))
    }
}

extension View {
    /// Long-form copy in an accent. Same three colours, but never the one that
    /// would need the silhouette shadow — a whole paragraph wearing that shadow
    /// reads as outlined and heavy. See `LCPalette.bodyResolved`.
    func accentBodyText(_ role: LCHue) -> some View {
        foregroundColor(LCColor.chromatic(role))
    }

    /// A link on the full-bleed auth cover: the tertiary accent, plus the hard
    /// shadow that separates it from the cover's own ground where the two are
    /// too close (Past's pink-on-blue is 1.49:1).
    func authCoverLink() -> some View {
        foregroundColor(LCAuthCover.link)
            .shadow(color: LCAuthCover.linkShadow ?? .clear, radius: 0, x: 1, y: 1)
    }
}

extension View {
    /// Yellow type kept as yellow, with a thin keyline in a named brand colour.
    ///
    /// The one exception to the ink rule above: the "MY IDEAL WEEK" wordmark is
    /// the app's signature, and turning it black in Past would cost more than
    /// the keyline does. `outline` is a COLOUR, not a role — a role would rotate
    /// with the text and could land on the same hue it is meant to separate from.
    /// No keyline at all when the colour reads unaided, so Present is untouched.
    func accentOutlinedText(_ role: LCHue, outline: LCHue, width: CGFloat = 1) -> some View {
        modifier(AccentOutlinedTextStyle(role: role, outline: outline, width: width))
    }
}

struct AccentOutlinedTextStyle: ViewModifier {
    let role: LCHue
    let outline: LCHue
    let width: CGFloat

    private static let ring: [CGPoint] = [
        CGPoint(x: -1, y: -1), CGPoint(x: 0, y: -1), CGPoint(x: 1, y: -1),
        CGPoint(x: -1, y:  0),                       CGPoint(x: 1, y:  0),
        CGPoint(x: -1, y:  1), CGPoint(x: 0, y:  1), CGPoint(x: 1, y:  1),
    ]

    func body(content: Content) -> some View {
        let colour = LCColor.resolved(role)
        if LCColor.textShadow(for: role) != nil {
            let keyline = LCColor.brand(outline)
            return AnyView(
                ZStack {
                    ForEach(Self.ring, id: \.self) { point in
                        content
                            .foregroundColor(keyline)
                            .offset(x: point.x * width, y: point.y * width)
                    }
                    content.foregroundColor(colour)
                }
            )
        }
        return AnyView(content.foregroundColor(colour))
    }
}

struct AccentTextStyle: ViewModifier {
    let role: LCHue
    var backdrop: LCHue? = nil

    func body(content: Content) -> some View {
        // On a coloured fill the pairing is the design's to make. Only on the
        // surface does an unreadable accent give way to ink.
        let unreadableOnSurface = backdrop == nil && LCColor.textShadow(for: role) != nil
        return content.foregroundColor(unreadableOnSurface ? LCColor.ink
                                                           : LCColor.resolved(role))
    }
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
