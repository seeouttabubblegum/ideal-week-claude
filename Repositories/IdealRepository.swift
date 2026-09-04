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
            "startDate": nextWeekStart
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
