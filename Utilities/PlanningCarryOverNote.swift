//
//  PlanningCarryOverNote.swift
//  The Ideal Week
//
//  The weekly prompt's planning lists last week's ideals MINUS those already in
//  this week (same title and category). Jay had 29 last week, 27 of them
//  already planned into this one, saw a two-item list and read it as lost data
//  (client, 2026-09-29). This line says what was left out and why.
//
//  Copy is a first draft for the client to edit, like the rest.
//

import Foundation

enum PlanningCarryOverNote {
    /// nil when nothing was left out.
    static func text(alreadyInWeek: Int, lastWeekTotal: Int) -> String? {
        guard alreadyInWeek > 0, lastWeekTotal > 0 else { return nil }
        if alreadyInWeek >= lastWeekTotal {
            return lastWeekTotal == 1
                ? "Last week\u{2019}s ideal is already in this week."
                : "All \(lastWeekTotal) of last week\u{2019}s ideals are already in this week."
        }
        return alreadyInWeek == 1
            ? "1 of last week\u{2019}s \(lastWeekTotal) ideals is already in this week, so it isn\u{2019}t listed here."
            : "\(alreadyInWeek) of last week\u{2019}s \(lastWeekTotal) ideals are already in this week, so they aren\u{2019}t listed here."
    }
}
