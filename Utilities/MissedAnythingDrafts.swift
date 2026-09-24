//
//  MissedAnythingDrafts.swift
//  The Ideal Week
//
//  "Missed Anything?" keeps its new ideals as one list of drafts: every draft
//  but the last is listed as added, and the last is the form being filled in.
//

import Foundation

enum MissedAnythingDrafts {
    typealias Draft = PlanningSheetViewModel.NewIdealDraft

    /// Whether "Add To Current Week" may open another form. Not while the form
    /// on screen is still blank — that would list an "Untitled" ideal. The very
    /// first form can always be opened.
    static func canAddAnother(_ drafts: [Draft]) -> Bool {
        guard let form = drafts.last else { return true }
        return !form.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Brings an added ideal back into the form so it can be changed.
    ///
    /// Whatever the form held is not lost: if it had a title it becomes an
    /// added ideal in its place; a blank form is simply dropped. Editing the
    /// form itself, or an id that is not there, changes nothing.
    static func reopen(id: String, in drafts: [Draft]) -> [Draft] {
        guard let index = drafts.firstIndex(where: { $0.id == id }),
              index < drafts.count - 1 else { return drafts }
        var result = drafts
        let reopened = result.remove(at: index)
        if let form = result.last, form.title.trimmingCharacters(in: .whitespaces).isEmpty {
            result.removeLast()
        }
        result.append(reopened)
        return result
    }
}
