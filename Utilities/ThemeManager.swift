//
//  ThemeManager.swift
//  The Ideal Week
//
//  Holds the palette the user picked in Settings. Stored in UserDefaults rather
//  than SwiftData so switching themes needs no schema change and cannot touch a
//  user's ideals.
//
//  `LCColor` reads `ThemeManager.current` for its accents, so a change here
//  repaints the whole app — but only once the tree is rebuilt, because those
//  accents are statics that SwiftUI does not observe. MenuView keys the
//  signed-in content on `palette` to force that rebuild.
//
//  That rebuild is total: it discards the navigation stack and every `@State`
//  underneath it. Applying a new palette the instant it is tapped would
//  therefore throw the user out of Settings — the very screen they are standing
//  in — and lose anything half-typed there. So a choice is STAGED when it is
//  made and COMMITTED when Settings closes. `stagedPalette` drives the Settings
//  row itself, so the choice still reads back immediately.
//

import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let storageKey = "lc.selectedPalette"

    /// Read directly (not through the @Published property) so `LCColor` can stay
    /// a set of plain statics without creating a publish-during-render loop.
    private(set) static var current: LCPalette = {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        return stored.flatMap(LCPalette.init(rawValue:)) ?? .fallback
    }()

    /// The palette the app is currently painted in.
    @Published private(set) var palette: LCPalette

    /// The palette the user has chosen, which may not be painted yet. Equal to
    /// `palette` except between a pick in Settings and leaving Settings.
    @Published private(set) var stagedPalette: LCPalette

    private init() {
        palette = ThemeManager.current
        stagedPalette = ThemeManager.current
    }

    /// Record a choice without repainting. Persisted immediately, so a choice
    /// survives the app being killed before Settings is closed.
    func stage(_ palette: LCPalette) {
        guard palette != stagedPalette else { return }
        UserDefaults.standard.set(palette.rawValue, forKey: Self.storageKey)
        stagedPalette = palette
    }

    /// Paint the staged choice. Safe to call when nothing is staged.
    func commitStaged() {
        guard stagedPalette != palette else { return }
        ThemeManager.current = stagedPalette
        palette = stagedPalette
    }

    /// Stage and paint in one step, for callers that are not inside Settings.
    func select(_ palette: LCPalette) {
        stage(palette)
        commitStaged()
    }

    /// Test seam — resets the cached value, the staged value and the stored one.
    func resetForTesting() {
        ThemeManager.current = .fallback
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        palette = .fallback
        stagedPalette = .fallback
    }
}
