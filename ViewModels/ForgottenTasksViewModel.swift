//
//  ForgottenTasksViewModel.swift
//  The Ideal Week
//
//  Created on 1/15/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class ForgottenTasksViewModel: ObservableObject {
    private let db = Firestore.firestore()

    func incrementDoneCount(for item: Ideal) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        let currentDate = Date().timeIntervalSince1970

        // Fetch current ideal to get lastCompletedDate before updating
        let documentRef = db.collection("users")
            .document(uid)
            .collection("ideals")
            .document(item.id)

        func applyDateShuffle(from data: [String: Any]) {
            // Get current lastCompletedDate if it exists
            let currentLastCompletedDate = data["lastCompletedDate"] as? TimeInterval

            // Prepare update data: move lastCompletedDate to secondCompletionDate, set new lastCompletedDate
            var updateData: [String: Any] = [
                "doneCount": FieldValue.increment(Int64(1)),
                "lastCompletedDate": currentDate
            ]

            if let previousDate = currentLastCompletedDate {
                updateData["secondCompletionDate"] = previousDate
            }

            documentRef.updateData(updateData)
        }

        // Read the CACHE first: it overlays this device's pending writes, so a
        // second completion moments after the first sees the first tap's
        // lastCompletedDate. The default read is server-first and still returns
        // the pre-tap value, which would get shifted into secondCompletionDate
        // and leave a stale rollback marker. Fall back to the default read on a
        // cache miss (document not cached on this device yet).
        documentRef.getDocument(source: .cache) { snapshot, error in
            if error == nil, let data = snapshot?.data() {
                applyDateShuffle(from: data)
                return
            }

            documentRef.getDocument { snapshot, error in
                if let error = error {
                    AppLogger.error(AppLogger.firestore, "[ForgottenTasksViewModel] Error fetching ideal for increment: \(error.localizedDescription)")
                    // Fallback: just update without date shifting
                    documentRef.updateData([
                        "doneCount": FieldValue.increment(Int64(1)),
                        "lastCompletedDate": currentDate
                    ])
                    return
                }

                guard let data = snapshot?.data() else {
                    // Fallback: just update without date shifting
                    documentRef.updateData([
                        "doneCount": FieldValue.increment(Int64(1)),
                        "lastCompletedDate": currentDate
                    ])
                    return
                }

                applyDateShuffle(from: data)
            }
        }
    }
}
