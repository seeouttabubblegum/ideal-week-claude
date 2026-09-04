//
//  IdealHistoryDetailViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 28/8/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class IdealHistoryDetailViewViewModel: ObservableObject {
    @Published var active: Bool
    @Published var showAlert = false
    @Published var alertMessage = ""

    private let idealId: String
    private let idealTitle: String
    private let idealCategory: String
    private let initialActiveState: Bool
    private let db = Firestore.firestore()

    init(ideal: Ideal) {
        self.idealId = ideal.id
        self.idealTitle = ideal.title
        self.idealCategory = ideal.category
        self.active = ideal.active
        self.initialActiveState = ideal.active
    }

    func save(weekStartDay: String? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            alertMessage = "User not authenticated"
            showAlert = true
            return
        }

        var updateData: [String: Any] = ["active": active]
        if !initialActiveState && active {
            // Ideal is being reactivated - set startDate to current week start for history
            let calendar = Calendar.current
            let now = DateProviderService.shared.now()
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            updateData["startDate"] = calendar.startOfDay(for: weekStart).timeIntervalSince1970

            // Check for duplicates in the current week before reactivating
            let effectiveWeekStartDay = weekStartDay ?? WeekdayUtility.defaultWeekStartDay
            IdealDuplicateGuard.fetchCurrentWeekKeys(userId: uid, weekStartDay: effectiveWeekStartDay, excludingIds: [idealId]) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let existingKeys):
                    if let key = IdealDuplicateGuard.duplicateKey(category: self.idealCategory, title: self.idealTitle),
                       existingKeys.contains(key) {
                        DispatchQueue.main.async {
                            self.alertMessage = "An ideal with the same title and category already exists this week."
                            self.showAlert = true
                        }
                        return
                    }
                    self.commitUpdate(db: db, uid: uid, updateData: updateData)
                case .failure:
                    // On error, proceed with the save (fail open)
                    self.commitUpdate(db: db, uid: uid, updateData: updateData)
                }
            }
            return
        }

        commitUpdate(db: db, uid: uid, updateData: updateData)
    }

    private func commitUpdate(db: Firestore, uid: String, updateData: [String: Any]) {
        db.collection("users")
            .document(uid)
            .collection("ideals")
            .document(idealId)
            .updateData(updateData) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.alertMessage = "Error updating ideal: \(error.localizedDescription)"
                        self?.showAlert = true
                    }
                }
            }
    }
}
