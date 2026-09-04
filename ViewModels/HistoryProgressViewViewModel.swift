//
//  HistoryProgressViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 28/8/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class HistoryProgressViewViewModel: ObservableObject {
    @Published var showingDetailView = false
    @Published var user: User? = nil

    private let db = Firestore.firestore()

    func fetchUser() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(), error == nil else { return }
            DispatchQueue.main.async {
                self?.user = User(
                    id: data["id"] as? String ?? "",
                    first_name: data["first_name"] as? String ?? "",
                    last_name: data["last_name"] as? String ?? "",
                    email: data["email"] as? String ?? "",
                    joined: data["joined"] as? TimeInterval ?? 0
                )
            }
        }
    }
}
