//
//  PlanningSheetCopy.swift
//  The Ideal Week
//
//  Week-naming copy for the planning sheet, kept out of the view so it can be
//  asserted. The sheet is reached by three routes that do NOT all write the
//  same week, and until 2026-08-20 two of them said "Next Week" while saving
//  into the CURRENT one:
//
//    • weekly prompt (Pick)        → current week
//    • Next?, empty current week   → current week  (NextPlanningDecision.fillCurrentWeek)
//    • Next?, normal               → next week
//
//  The "My" in the Next?-tab wording is the pre-existing voice of that tab and
//  is deliberately preserved; only the week name was wrong.
//

import Foundation

enum PlanningSheetCopy {
    /// CTA under "Missed Anything?" that appends another new-ideal draft.
    static func addAnotherIdealLabel(isWeeklyPrompt: Bool, targetsCurrentWeek: Bool) -> String {
        if isWeeklyPrompt { return "Add To Current Week" }
        return targetsCurrentWeek ? "Add To My Current Week" : "Add To My Next Week"
    }
}
