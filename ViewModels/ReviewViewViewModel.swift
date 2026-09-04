//
//  ReviewViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 24/8/25.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore
@MainActor
class ReviewViewViewModel: ObservableObject {

    @Published var currentUserId: String = ""
    /// Guards against double-tap on the submit button. Read on main thread.
    @Published var isSaving: Bool = false
    
    nonisolated(unsafe) private var handler: AuthStateDidChangeListenerHandle?
    // Firestore is thread-safe; mark nonisolated so it can be referenced inside
    // Sendable callbacks (getDocuments, addSnapshotListener) without warnings.
    nonisolated private let db = Firestore.firestore()

    init(){
        self.handler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.currentUserId = user?.uid ?? ""
            }
        }
    }
    
    nonisolated private func removeAuthListener() {
        if let h = handler {
            Auth.auth().removeStateDidChangeListener(h)
            handler = nil
        }
    }
    
    deinit {
        removeAuthListener()
    }

    func save(item: Ideal, score: Int) {
        guard !item.id.isEmpty else {
            return
        }

        guard let uId = Auth.auth().currentUser?.uid else {
            return
        }
        
        
        db.collection("users")
            .document(uId)
            .collection("ideals")
            .document(item.id)
            .updateData([
                "reviewScore": score
            ]) { error in
                if let error {
                    AppLogger.error(AppLogger.firestore, "[ReviewViewViewModel] Error saving review score: \(error.localizedDescription)")
                }
            }
    }
    
    func saveReviewScore(score: Double, item: Ideal, position: Int) {
        guard !item.id.isEmpty else { return }
        guard let uId = Auth.auth().currentUser?.uid else { return }
        // Re-entrancy guard — submit button could be double-tapped during the
        // dismiss animation.
        guard !isSaving else { return }
        isSaving = true

        // The async completions below must not depend on `self` for the writes:
        // this VM is deallocated as soon as the review sheet dismisses, which
        // happens while the reviewScores round-trip is still in flight on a slow
        // connection. `db` is a thread-safe singleton (see the property above),
        // so capturing it instead of `self` keeps the average update alive
        // without extending the VM's lifetime past deinit/removeAuthListener().
        let db = self.db
        let idealId = item.id

        let reviewScoreId = UUID().uuidString
        // `score` is on the 1-7 user-facing scale. Persist on the legacy 0-100
        // scale (with inverted semantics — see ReviewScoreScale) so existing
        // analytics / averages keep working.
        let scoreValue = ReviewScoreScale.stored(fromDisplay: score)
        let currentDate = Date().timeIntervalSince1970

        // Build the new score document.
        let reviewScore = ReviewScore(
            id: reviewScoreId,
            idealId: item.id,
            position: position,
            score: scoreValue,
            date: currentDate
        )

        // Save to Firestore subcollection: users/{userId}/ideals/{idealId}/reviewScores/{reviewScoreId}
        do {
            try db.collection("users")
                .document(uId)
                .collection("ideals")
                .document(item.id)
                .collection("reviewScores")
                .document(reviewScoreId)
                .setData(from: reviewScore)
        } catch {
            AppLogger.error(AppLogger.firestore, "Error saving review score: \(error.localizedDescription)")
        }

        // Contribute anonymised title + score to the community top-ideals
        // collection — but only while the feature is switched on. With Community
        // Ideals hidden there is nothing in the app that reads this collection,
        // so writing to it would ship users' ideal titles off-device for no
        // reason. Gated on the same flag that hides the UI.
        if AppStoreConfig.isCommunityIdealsEnabled {
            CommunityIdealService.shared.upsert(title: item.title, category: item.category, score: scoreValue)
        }

        // Backward-compat: update `Ideal.reviewScore` with the average across
        // all the ideal's review scores. We include the just-written `scoreValue`
        // locally because Firestore queries aren't guaranteed read-after-write
        // consistent across the cache.
        db.collection("users")
            .document(uId)
            .collection("ideals")
            .document(idealId)
            .collection("reviewScores")
            .getDocuments { [weak self] snapshot, error in
                if let error {
                    AppLogger.error(AppLogger.firestore, "[ReviewViewViewModel] Error fetching review scores: \(error.localizedDescription)")
                    Task { @MainActor [weak self] in self?.isSaving = false }
                    return
                }

                // Existing scores, excluding the document we just wrote (it may
                // or may not be present in `documents` depending on cache state).
                let existing: [Int] = (snapshot?.documents ?? []).compactMap { doc in
                    guard let parsed = try? doc.data(as: ReviewScore.self) else { return nil }
                    if parsed.id == reviewScoreId { return nil }
                    return parsed.score
                }

                // Always include the just-written score so the average reflects it
                // deterministically.
                let allScores = existing + [scoreValue]
                let total = allScores.reduce(0, +)
                let average = Int((Double(total) / Double(allScores.count)).rounded())

                db.collection("users")
                    .document(uId)
                    .collection("ideals")
                    .document(idealId)
                    .updateData([
                        "reviewScore": average
                    ]) { [weak self] error in
                        if let error {
                            AppLogger.error(AppLogger.firestore, "[ReviewViewViewModel] Error updating average review score: \(error.localizedDescription)")
                        }
                        Task { @MainActor [weak self] in self?.isSaving = false }
                    }
            }
    }
}
