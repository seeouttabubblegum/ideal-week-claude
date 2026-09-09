//
//  CategoryReviewAverage.swift
//  The Ideal Week
//
//  The average review score for a set of ideals over a period.
//
//  Pulled out of the view because the same calculation existed there three
//  times and the copies had drifted: one of them narrowed the ideals to those
//  that STARTED inside the period as well as filtering the scores by date. That
//  extra condition silently dropped every score belonging to an ideal carried
//  over from an earlier week — which is most of them, since ideals persist.
//
//  The period is decided by the REVIEW's date and nothing else. When an ideal
//  was created has no bearing on which week its review belongs to.
//

import Foundation

enum CategoryReviewAverage {
    /// Mean of the stored (0-100) scores whose date falls inside `start...end`.
    /// nil when the period holds no reviews at all — the caller shows a dash.
    static func average(idealIds: [String],
                        scoresByIdeal: [String: [ReviewScore]],
                        from start: TimeInterval,
                        to end: TimeInterval) -> Double? {
        let scores = idealIds
            .compactMap { scoresByIdeal[$0] }
            .flatMap { $0 }
            .filter { $0.date >= start && $0.date <= end }
            .map(\.score)

        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
}
