//
//  Category.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 13/6/25.
//

import UIKit
enum Category: String, CaseIterable, Identifiable {
    case fix = "Fix"
    case fitness = "Fitness"
    case feelings = "Feelings"
    case faculties = "Faculties"
    case family = "Family"
    case finance = "Finance"
    case fun = "Fun"
    var id: Self { self }
    
    var subheading: String {
        switch self {
            case .fix:
                return "What’s been nagging you? How do we make some space?"
            case .fitness:
                return "What will make you feel healthier this week?"
            case .feelings:
                return "How can you feel lighter this week?"
            case .faculties:
                return "How are you going to sharpen your thoughts this week?"
            case .family:
                return "What will you do this week to improve the relationships with the people you love?"
            case .finance:
                return "What financial impact can you make this week to your bottomline?"
            case .fun:
                return "How are you letting loose this week?"
        }
    }

    // MARK: - Love & Chaos icon assets
    // The catalog now ships only the Line assets `lcCategoryIconV2` can reach
    // (one tint per category) plus the two Cat replacements — the unused
    // Solid/other-tint variants were removed on 2026-09-04.

    /// Returns the FIRST Line asset that actually exists for this category.
    /// Icons are rendered `.template`, so the source tint is irrelevant.
    private static let tintPreference = ["Blue", "Blk", "Yellow", "Pink", "White"]
    fileprivate func lcLineIconAvailable() -> String {
        for t in Self.tintPreference {
            let name = "Line \(rawValue)_\(t)"
            if UIImage(named: name) != nil { return name }
        }
        return "Line \(rawValue)_Blue"
    }
    /// THE category glyph — single source of truth for every category icon in
    /// the app (client, 2026-08-28: the ideal-list set is canonical). Fitness
    /// and Family use the v2 replacements (running shoe → heartbeat pulse,
    /// group-with-rays → two figures); the rest resolve to the Line assets.
    /// Render template-tinted. Never reach for `lcLineIconAvailable` or an
    /// SF-symbol stand-in from a view — both are private now.
    func lcCategoryIconV2() -> String {
        switch self {
        case .fitness: return "Cat Fitness"
        case .family:  return "Cat Family"
        default:       return lcLineIconAvailable()
        }
    }
}

