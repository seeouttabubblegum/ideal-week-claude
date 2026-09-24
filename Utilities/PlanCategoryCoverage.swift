//
//  PlanCategoryCoverage.swift
//  The Ideal Week
//
//  Which of the seven categories a plan still leaves empty — the list the
//  "Missed Anything?" notice and the save warning both name.
//

import Foundation

enum PlanCategoryCoverage {
    /// The picker's spelling of a stored category, or nil if it is not one of
    /// the seven. Stored values are not always spelled exactly like the picker
    /// (older builds, the Android app), so case and surrounding spaces are
    /// ignored — otherwise a "family" ideal would leave Family listed as empty.
    static func canonical(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return Category.allCases.first { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }?.rawValue
    }

    /// Categories with nothing in `categories`, in the picker's order.
    static func missing(from categories: [String]) -> [String] {
        let present = Set(categories.compactMap(canonical))
        return Category.allCases.map(\.rawValue).filter { !present.contains($0) }
    }
}
