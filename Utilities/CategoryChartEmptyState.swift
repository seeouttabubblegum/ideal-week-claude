//
//  CategoryChartEmptyState.swift
//  The Ideal Week
//
//  Which empty state the category review chart should show, if any.
//
//  This was a one-line boolean in the view and it was wrong: the "no review
//  scores" message required the category to HAVE ideals, so a category the user
//  had never added an ideal to fell through every branch — an empty chart above,
//  a suppressed message below, and a blank white screen in between. Pulled out
//  here so the decision is a value that can be tested rather than a condition
//  buried in a `body`.
//

import Foundation

enum CategoryChartEmptyState: Equatable {
    /// There is something to plot.
    case none
    /// The category has ideals, but none of them was reviewed in this period.
    case noScores
    /// The category has no ideals at all in this period.
    case noIdeals

    /// - Parameters:
    ///   - isDataReady: false while review scores are still loading.
    ///   - weeklyAverageCount: how many weekly points the chart would draw.
    ///   - categoryIdealCount: ideals in this category, already narrowed to the
    ///     period being shown.
    static func resolve(isDataReady: Bool,
                        weeklyAverageCount: Int,
                        categoryIdealCount: Int) -> CategoryChartEmptyState {
        // Say nothing until the data has landed — the loading overlay owns the
        // screen, and claiming "no scores" mid-fetch would be a lie.
        guard isDataReady else { return .none }
        guard weeklyAverageCount == 0 else { return .none }
        return categoryIdealCount == 0 ? .noIdeals : .noScores
    }
}
