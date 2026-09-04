//
//  ReviewScoreScale.swift
//  The Ideal Week
//
//  Bridges the on-disk 0-100 score (legacy storage) and the 1-7 UI scale used
//  by the new neumorphic review slider. Keep all conversions here so changing
//  the scale later only touches this file.
//

import Foundation

enum ReviewScoreScale {
    /// Min/max of the user-facing scale.
    static let displayMin: Double = 1
    static let displayMax: Double = 7

    /// Convert a stored 0-100 score into the 1-7 display value.
    ///
    /// **Direction (official): higher = better.** `display = 7` is best (yellow/happy),
    /// `display = 1` is worst (blue/sad). Storage matches: `stored = 100 → display 7`,
    /// `stored = 0 → display 1`. This is the natural (non-inverted) mapping and it also
    /// keeps legacy 1–10×10 data correct (legacy `stored = 100` = "10/10" = best = 7/7).
    static func display(fromStored stored: Int) -> Double {
        let clamped = max(0, min(100, stored))
        return displayMin + (Double(clamped) / 100.0) * (displayMax - displayMin)
    }

    /// Same, but accepts a raw Double (e.g. an average of stored scores).
    static func display(fromStored stored: Double) -> Double {
        let clamped = max(0.0, min(100.0, stored))
        return displayMin + (clamped / 100.0) * (displayMax - displayMin)
    }

    /// Convert a 1-7 slider value into the 0-100 stored integer
    /// (`display = 7` → `stored = 100` best, `display = 1` → `stored = 0` worst).
    static func stored(fromDisplay display: Double) -> Int {
        let clamped = max(displayMin, min(displayMax, display))
        let normalised = (clamped - displayMin) / (displayMax - displayMin) // 0...1
        return Int((normalised * 100.0).rounded())
    }

    /// Format the 1-7 display value as a short string ("4" or "4.2").
    static func formattedDisplay(_ value: Double) -> String {
        let rounded = (value * 10.0).rounded() / 10.0
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }
}
