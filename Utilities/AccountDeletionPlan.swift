//
//  AccountDeletionPlan.swift
//  The Ideal Week
//
//  Describes exactly what deleting an account removes. Required by App Store
//  Review Guideline 5.1.1(v): an app that offers account creation must let the
//  user delete that account from inside the app.
//
//  Kept separate from the code that performs the deletion so the scope can be
//  asserted in tests — this is irreversible, and the dangerous mistakes are
//  reaching too far (the shared community collection, another user's data) or
//  not far enough (an orphaned subcollection).
//
//  NOTE ON FIRESTORE: deleting a document does NOT delete its subcollections.
//  Every collection below has to be walked and deleted explicitly.
//

import Foundation

struct AccountDeletionPlan {
    let userId: String

    // MARK: - Firestore

    /// Collections directly under `users/{uid}`.
    let userSubcollections = ["ideals", "planned_ideal_records", "QA"]

    /// Collections nested under each ideal document.
    let idealSubcollections = ["reviewScores"]

    var userDocumentPath: String { "users/\(userId)" }

    var userSubcollectionPaths: [String] {
        userSubcollections.map { "\(userDocumentPath)/\($0)" }
    }

    func reviewScoresPath(idealId: String) -> String {
        "\(userDocumentPath)/ideals/\(idealId)/reviewScores"
    }

    // Deliberately absent: the root `community_ideals` collection. Those
    // documents are shared aggregates (totalScore / reviewCount across all
    // users) and are owned by no single account — removing one would corrupt
    // everyone else's Top Ideals list.

    // MARK: - Local state
    //
    // Weekly-flow state is device-local and NOT keyed by uid, so leaving it
    // behind would hand the next account to sign in on this device a half-used
    // week. It is stored one key per week, hence the prefix match.

    let userDefaultsPrefixesToClear = [
        "weeklyFlowProcessed_",
        "lastWeekReviewPromptShown_",
        "weeklyPlanningSheetShown_",
        "weeklyPromptOpenCount_",
    ]

    let userDefaultsKeysToClear = [
        "biometric_login_enabled",
        "weeklyPromptForceShowPending",
    ]

    func shouldClearUserDefaultsKey(_ key: String) -> Bool {
        userDefaultsKeysToClear.contains(key)
            || userDefaultsPrefixesToClear.contains { key.hasPrefix($0) }
    }
}
