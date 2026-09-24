//
//  DrawerTabPalette.swift
//  The Ideal Week
//
//  Colours for the drawer's six cascading tabs: each tab's background, and the
//  ink its label and glyph are drawn in.
//
//  The backgrounds step from the primary accent toward white, 16% per tab. The
//  labels were a single #181818 on all six, which is fine wherever the primary
//  is a mid or light colour — but 50s makes the primary #303030, so the top two
//  tabs put near-black type on a near-black ground (1.35:1 and 2.24:1).
//
//  So in 50s the labels run as a gradient opposite to the backgrounds: pure
//  black on the bottom tab, lighter on every tab going up, white on the top one.
//  Present, Past and Future keep the handoff's #181818 on every tab.
//
//  Two opposing gradients have to cross, and with evenly spaced greys PROFILE
//  and SETTINGS read at only 1.7:1 and 1.9:1. So the greys are spaced evenly
//  within the light half and within the dark half, with the gap between the
//  halves falling between PROFILE and SETTINGS. PROFILE's light grey and
//  SETTINGS' dark grey sit as close to the middle as they can while each still
//  clears 3:1.
//

import SwiftUI

enum DrawerTabPalette {
    static let tabCount = 6

    /// How far each tab's background moves toward white.
    static let step: Double = 0.16

    /// The handoff's drawer ink.
    static let handoffInk = Color(hex: 0x181818)

    /// Background for tab `index`: the primary accent mixed toward white.
    static func shade(_ index: Int) -> Color {
        mix(LCColor.pink, .white, step * Double(index))
    }

    /// 50s label greys, top tab to bottom.
    static let fiftiesInk: [Int] = [0xFFFFFF, 0xE6E6E6, 0xCDCDCD, 0x474747, 0x262626, 0x000000]

    /// Label and glyph ink for tab `index`.
    static func ink(_ index: Int) -> Color {
        guard ThemeManager.current == .fifties else { return handoffInk }
        return Color(hex: fiftiesInk[index])
    }

    static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let x = a.getComponents(), y = b.getComponents()
        return Color(red: x.red + (y.red - x.red) * t,
                     green: x.green + (y.green - x.green) * t,
                     blue: x.blue + (y.blue - x.blue) * t,
                     opacity: 1)
    }
}

/// The ink a drawer tab's label and glyph are drawn in, set by the tab so
/// `MenuItem` — which is built separately inside each tab — picks it up without
/// every call site having to pass its index along.
private struct DrawerInkKey: EnvironmentKey {
    static let defaultValue: Color = DrawerTabPalette.handoffInk
}

extension EnvironmentValues {
    var drawerInk: Color {
        get { self[DrawerInkKey.self] }
        set { self[DrawerInkKey.self] = newValue }
    }
}
