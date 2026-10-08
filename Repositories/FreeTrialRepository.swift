//
//  FreeTrialRepository.swift
//  The Ideal Week
//
//  Where the free trial's start lives: `users/{uid}.freeTrialStartedAt`, a
//  server timestamp written once (`FreeTrial`). Kept apart from
//  `SubscriptionManager` because Firestore's `Transaction` clashes with
//  StoreKit's there.
//

import Foundation
import FirebaseFirestore

enum FreeTrialRepository {
    /// Records the start if it never was, then reads it back. Completion on
    /// the main queue with the start, or nil when it could not be read.
    static func loadStart(userId: String, completion: @escaping (Date?, Error?) -> Void) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        db.runTransaction({ transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(userRef)
                let existing = (snapshot.data()?[FreeTrial.startField] as? Timestamp)?.dateValue()
                if FreeTrial.shouldRecordStart(existing: existing) {
                    transaction.setData([FreeTrial.startField: FieldValue.serverTimestamp()],
                                        forDocument: userRef, merge: true)
                }
            } catch let error as NSError {
                errorPointer?.pointee = error
            }
            return nil
        }) { _, transactionError in
            // Read back either way: a failed write may still leave an
            // earlier start in place.
            userRef.getDocument { snapshot, readError in
                let start = (snapshot?.data()?[FreeTrial.startField] as? Timestamp)?.dateValue()
                DispatchQueue.main.async { completion(start, readError ?? transactionError) }
            }
        }
    }
}
