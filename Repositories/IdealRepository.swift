//
//  IdealRepository.swift
//  The Ideal Week
//
//  Firestore data access for ideal list mutations.
//

import Foundation
import FirebaseFirestore

final class IdealRepository {
    static let shared = IdealRepository()

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func deleteIdeal(userId: String, idealId: String, completion: ((Error?) -> Void)? = nil) {
        db.collection("users")
            .document(userId)
            .collection("ideals")
            .document(idealId)
            .delete(completion: completion)
    }

    func deletePlannedRecord(userId: String, idealId: String, completion: ((Error?) -> Void)? = nil) {
        db.collection("users")
            .document(userId)
            .collection(PlannedIdealRecord.collectionName)
            .document(idealId)
            .delete(completion: completion)
    }

    /// Take an ideal out of next week's plan: its plan record goes, and so does
    /// the ideal itself — deleted if the planning flow made it, back to the
    /// wishlist if it was a wishlist item moved in (`PlanRemoval`). Removing
    /// only the record left the ideal in next week, where it turned up on its
    /// own once the week began.
    func removeFromNextWeekPlan(userId: String, ideal: Ideal, targetWeekStart: TimeInterval,
                                completion: ((Error?) -> Void)? = nil) {
        let userRef = db.collection("users").document(userId)
        let batch = db.batch()
        batch.deleteDocument(userRef.collection(PlannedIdealRecord.collectionName).document(ideal.id))
        let idealRef = userRef.collection("ideals").document(ideal.id)
        switch PlanRemoval.action(for: ideal, targetWeekStart: targetWeekStart) {
        case .deleteCopy: batch.deleteDocument(idealRef)
        case .returnToWishlist: batch.updateData(PlanRemoval.wishlistRestoreFields, forDocument: idealRef)
        }
        batch.commit(completion: completion)
    }

    /// IDs of the plan records for one week, read once (not from the listener).
    func fetchPlanRecordIds(userId: String, start: TimeInterval, endExclusive: TimeInterval,
                            completion: @escaping (Result<Set<String>, Error>) -> Void) {
        db.collection("users").document(userId)
            .collection(PlannedIdealRecord.collectionName)
            .whereField("startDate", isGreaterThanOrEqualTo: start)
            .whereField("startDate", isLessThan: endExclusive)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error { completion(.failure(error)); return }
                    completion(.success(Set(snapshot?.documents.map(\.documentID) ?? [])))
                }
            }
    }

    /// Add a wishlist ideal to next week's plan (update ideal in-place and create planned record).
    func addWishlistIdealToNextWeekPlan(
        userId: String,
        idealId: String,
        weekStartDay: String,
        category: String? = nil,
        targetCount: String? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        let nextWeekStart = WeekdayUtility.nextWeekRange(weekStartDay: weekStartDay).start.timeIntervalSince1970
        let idealsRef = db.collection("users").document(userId).collection("ideals").document(idealId)
        let recordsRef = db.collection("users").document(userId).collection(PlannedIdealRecord.collectionName).document(idealId)
        var updateData: [String: Any] = [
            "wishlistEnabled": false,
            "startDate": nextWeekStart,
            // Marks it as a wishlist item, so leaving the plan returns it there.
            "plannedFromWishlistAt": Date().timeIntervalSince1970
        ]
        if let category = category, !category.isEmpty {
            updateData["category"] = category
        }
        if let targetCount = targetCount, !targetCount.isEmpty {
            updateData["targetCount"] = targetCount
        }
        
        idealsRef.updateData(updateData) { error in
            if let error = error {
                completion?(error)
                return
            }
            let record = PlannedIdealRecord(id: idealId, startDate: nextWeekStart, createdDate: Date().timeIntervalSince1970)
            recordsRef.setData(record.asDictionary(), completion: completion)
        }
    }
}
