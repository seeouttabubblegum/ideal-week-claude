//
//  StarterPlanSuggestions.swift
//  The Ideal Week
//
//  A first plan opens on "Missed Anything?" with seven empty categories and a
//  blank form. For a brand-new user that is a cold start, so the step begins
//  with ONE ideal already in the list — one category, not all seven, so the
//  plan still reads as theirs.
//
//  Copy here is a first draft for the client to edit.
//

import Foundation

enum StarterPlanSuggestions {
    /// The category the starter ideal belongs to.
    static let category: Category = .fix

    static let title = "Clear one small thing off my list"

    /// Whether the starter ideal should be put in.
    ///
    /// - Parameters:
    ///   - seen: this user has already been offered it once.
    ///   - hasAnyIdeals: they already have ideals, so they do not need a
    ///     starting point and the step opens empty, as it always has.
    static func shouldOffer(seen: Bool, hasAnyIdeals: Bool) -> Bool {
        !seen && !hasAnyIdeals
    }

    /// The drafts the step opens with — deliberately one.
    static func drafts() -> [PlanningSheetViewModel.NewIdealDraft] {
        [PlanningSheetViewModel.NewIdealDraft(title: title, category: category.rawValue, targetCount: "1")]
    }
}
