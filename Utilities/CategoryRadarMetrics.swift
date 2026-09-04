//
//  CategoryRadarMetrics.swift
//  The Ideal Week
//
//  Pure (UI-free, testable) computation for the Profile "Your Top Ideals" radar chart
//  and the per-card completion badge. All functions take an already date-filtered set of
//  ideals; the host decides the date range and passes the filtered array in.
//
//  Two overlays share the same 0…1 radial ring per category axis:
//   - Completion: equal-weight mean of each ideal's min(doneCount / target, 1).
//   - Review: average user review on the 1–7 display scale, normalized onto 0…1 by ÷7
//     (in this app 7 = happiest/best, so 7/7 = full ring is the intuitive direction).
//

import Foundation

/// One radar axis = one ideal category, with both overlays' plotted values.
struct RadarAxis: Equatable {
    let category: Category
    /// Completion overlay, 0…1 (already clamped at 1.0 — over-completion lives only in the badge).
    let completion: Double
    /// Raw average review on the 1–7 display scale (nil when no reviews in range). For the tooltip.
    let reviewDisplay: Double?
    /// Review overlay plotted on the same 0…1 ring (= reviewDisplay / 7; 0 when no reviews).
    let reviewPlotted: Double
}

enum CategoryRadarMetrics {
    /// Parsed target action count for an ideal. "6+" → 6; numeric string → its Int; else 0.
    static func target(_ ideal: Ideal) -> Int {
        ideal.targetCount == "6+" ? 6 : (Int(ideal.targetCount) ?? 0)
    }

    /// RAW completion percentage for a single ideal's card badge (unclamped, so 150%, 250%… show).
    /// Returns nil when target == 0 (badge should render "–" or hide — never NaN/∞).
    static func badgePercent(_ ideal: Ideal) -> Int? {
        let t = target(ideal)
        guard t > 0 else { return nil }
        return Int((Double(ideal.doneCount) / Double(t) * 100).rounded())
    }

    /// Completion overlay value for a category, 0…1. Equal-weight mean (each ideal counts once,
    /// NOT action-weighted) of `min(doneCount / target, 1.0)` across ideals in the category with
    /// target > 0. Ideals with target == 0 are excluded. Empty category → 0.
    static func completionAxis(ideals: [Ideal], category: Category) -> Double {
        let inCategory = ideals.filter { $0.category == category.rawValue && target($0) > 0 }
        guard !inCategory.isEmpty else { return 0 }
        let sum = inCategory.reduce(0.0) { acc, ideal in
            acc + min(Double(ideal.doneCount) / Double(target(ideal)), 1.0)
        }
        return sum / Double(inCategory.count)
    }

    /// Average review for a category on the 1–7 display scale, or nil when no ideal in the
    /// category carries a review in range. Uses `Ideal.reviewScore` (stored 0–100) converted via
    /// `ReviewScoreScale.display(fromStored:)` — the same value the cards display.
    static func reviewDisplayAxis(ideals: [Ideal], category: Category) -> Double? {
        let scores = ideals
            .filter { $0.category == category.rawValue }
            .compactMap { $0.reviewScore }
        guard !scores.isEmpty else { return nil }
        let displays = scores.map { ReviewScoreScale.display(fromStored: $0) }
        return displays.reduce(0, +) / Double(displays.count)
    }

    /// Normalize a 1–7 display review onto the shared 0…1 ring (÷7). 7/7 = outer ring (best).
    static func reviewPlotted(_ displayAvg: Double?) -> Double {
        guard let displayAvg else { return 0 }
        return max(0, min(1, displayAvg / ReviewScoreScale.displayMax))
    }

    /// Build the full set of radar axes (one per category, in `categories` order).
    static func axisData(ideals: [Ideal], categories: [Category]) -> [RadarAxis] {
        categories.map { category in
            let reviewDisplay = reviewDisplayAxis(ideals: ideals, category: category)
            return RadarAxis(
                category: category,
                completion: completionAxis(ideals: ideals, category: category),
                reviewDisplay: reviewDisplay,
                reviewPlotted: reviewPlotted(reviewDisplay)
            )
        }
    }
}
