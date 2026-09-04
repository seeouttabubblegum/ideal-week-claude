//
//  HowOftenSlider.swift
//  The Ideal Week
//
//  Geometry for the 1–6+ "How often?" slider on the wishlist quick-add sheet.
//  The knob travels between the two margins rather than between column centres,
//  so at 1 its left edge meets the section labels and at 6+ its right edge meets
//  the category wells above it. Stop labels are centred on these same positions,
//  which keeps the knob sitting exactly over its number.
//

import CoreGraphics

enum HowOftenSlider {

    /// 1, 2, 3, 4, 5, 6+
    static let stopCount = 6

    static let knobDiameter: CGFloat = 32
    static let trackHeight: CGFloat = 10

    /// Centre of the knob for a (possibly fractional) value inside `width`.
    static func thumbX(for value: Double, width: CGFloat) -> CGFloat {
        let radius = knobDiameter / 2
        let travel = max(0, width - knobDiameter)
        let clamped = min(max(value, 1), Double(stopCount))
        return radius + travel * CGFloat(clamped - 1) / CGFloat(stopCount - 1)
    }

    /// The stop nearest to a drag location.
    static func value(atX x: CGFloat, width: CGFloat) -> Int {
        let radius = knobDiameter / 2
        let travel = max(1, width - knobDiameter)
        let raw = (x - radius) / travel * CGFloat(stopCount - 1) + 1
        guard raw.isFinite else { return 1 }
        return min(max(Int(raw.rounded()), 1), stopCount)
    }

    /// The top stop is open-ended: "6+", not "6".
    static func label(for value: Int) -> String {
        value >= stopCount ? "\(stopCount)+" : "\(value)"
    }

    /// Inverse of `label(for:)` — parses a stored target back into a stop.
    /// Anything unrecognised falls back to 1.
    static func value(fromLabel label: String) -> Int {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("+") { return stopCount }
        guard let parsed = Int(trimmed) else { return 1 }
        return min(max(parsed, 1), stopCount)
    }
}
