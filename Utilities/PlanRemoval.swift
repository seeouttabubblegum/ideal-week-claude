//
//  PlanRemoval.swift
//  The Ideal Week
//
//  What happens to an ideal when it leaves next week's plan — removed with
//  "Remove from plan?", or replaced by a new plan.
//
//  A planned ideal is one of two things:
//   - a COPY the planning flow made (from this week's ideal, or typed into
//     "Missed Anything?"). Nothing else refers to it: it is deleted.
//   - a WISHLIST item the plan moved into next week in place (the planning
//     flow's wishlist step, or the yellow ADD on a wishlist row). It is the
//     user's only copy: it goes back to the wishlist.
//
//  Removing only the plan record (the old behaviour) left the ideal in next
//  week — off the Next? page, but in the list the moment the week began. That
//  is how "last week's items came into this week by themselves" (2026-09-29).
//

import Foundation

enum PlanRemoval {
    enum Action: Equatable {
        case deleteCopy
        case returnToWishlist
    }

    /// Copies are stamped with the target week (createdDate = its start) or
    /// carry `sourceIdealId`; a wishlist item keeps its own, earlier creation
    /// date, and the planning flow also stamps `plannedFromWishlistAt`.
    static func action(plannedFromWishlistAt: TimeInterval,
                       sourceIdealId: String?,
                       createdDate: TimeInterval,
                       targetWeekStart: TimeInterval) -> Action {
        if plannedFromWishlistAt > 0 { return .returnToWishlist }
        if let source = sourceIdealId, !source.isEmpty { return .deleteCopy }
        return createdDate < targetWeekStart ? .returnToWishlist : .deleteCopy
    }

    static func action(for ideal: Ideal, targetWeekStart: TimeInterval) -> Action {
        action(plannedFromWishlistAt: ideal.plannedFromWishlistAt,
               sourceIdealId: ideal.sourceIdealId,
               createdDate: ideal.createdDate,
               targetWeekStart: targetWeekStart)
    }

    /// Back on the wishlist: no week, and no schedule — days picked for one
    /// week mean nothing on the wishlist, and would show a stale "NEXT:".
    static let wishlistRestoreFields: [String: Any] = [
        "wishlistEnabled": true,
        "startDate": TimeInterval(0),
        "plannedFromWishlistAt": TimeInterval(0),
        "scheduledDays": [Int](),
        "reminderTime": TimeInterval(0),
        "reminderSchedules": [[String: Any]](),
        "reminderIds": [String](),
        "scheduleBaselineDoneCount": 0
    ]

    struct TargetWeekDoc: Equatable {
        let id: String
        let isWishlist: Bool
    }

    /// What a new plan for next week replaces: the old plan's ideals, and any
    /// next-week ideal that lost its plan record (a leftover of the old
    /// "Remove from plan?") — otherwise that leftover slipped past the
    /// duplicate check and next week got the same ideal twice. Wishlist items
    /// are never part of a week.
    static func idsReplacedByNewPlan(targetWeekDocs: [TargetWeekDoc]) -> [String] {
        targetWeekDocs.filter { !$0.isWishlist }.map(\.id)
    }
}

/// The "a plan already exists" gate of the weekly prompt. The planned-records
/// listener is only inferred to have loaded (from the ideals listener), so
/// before the prompt offers planning it asks the server once per week.
enum WeeklyPlanConfirmation {
    static func mustConfirm(decision: WeeklyFlowDecisionEngine.Decision,
                            forceShow: Bool,
                            confirmedWeekKey: String?,
                            currentWeekKey: String) -> Bool {
        guard !forceShow, confirmedWeekKey != currentWeekKey else { return false }
        switch decision {
        case .showRecapThenChoice, .showChoicePrompt: return true
        default: return false
        }
    }

    static func planExists(fromListener: Bool,
                           confirmedIds: Set<String>,
                           confirmedWeekKey: String?,
                           currentWeekKey: String) -> Bool {
        fromListener || (confirmedWeekKey == currentWeekKey && !confirmedIds.isEmpty)
    }

    /// The plan the server really holds for a week: its records, less any
    /// whose ideal is gone (a stale record must not hold the flow up forever).
    static func confirmedPlanIds(recordIds: Set<String>, idealIds: Set<String>) -> Set<String> {
        recordIds.intersection(idealIds)
    }

    /// Whether the weekly flow must hold: the server confirmed a plan for this
    /// week, and the list has not yet shown every one of its ideals. Deciding
    /// before that let the choice prompt open over a week that was already
    /// planned (client, 2026-10-02). `loadedIds` is every current-week ideal
    /// the list has shown so far, so an ideal removed later cannot block it.
    static func waitsForPlanIdeals(confirmedIds: Set<String>,
                                   confirmedWeekKey: String?,
                                   currentWeekKey: String,
                                   loadedIds: Set<String>) -> Bool {
        guard confirmedWeekKey == currentWeekKey, !confirmedIds.isEmpty else { return false }
        return !confirmedIds.isSubset(of: loadedIds)
    }
}
