//
//  RegisterViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
@MainActor
class RegisterViewViewModel: ObservableObject {
    @Published var first_name: String = ""
    @Published var last_name: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var errorMessage: String = ""
    @Published var isRegistering: Bool = false
    private let db = Firestore.firestore()

    init(){}

    func register(){
        guard validate() else {
            return
        }
        guard !isRegistering else { return }

        errorMessage = "" // Clear previous errors
        isRegistering = true

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                self.isRegistering = false
                if let error = error {
                    self.errorMessage = authErrorMessage(for: error)
                } else if let userId = result?.user.uid {
                    self.insertUserRecord(id: userId)
                    self.errorMessage = "" // Clear error on success
                } else {
                    self.errorMessage = "Registration failed. Please try again."
                }
            }
        }
    }
    
    private func insertUserRecord(id: String) {
        let newUser = User(id: id, first_name: first_name, last_name: last_name, email: email, joined: Date().timeIntervalSince1970)
        db.collection("users")
            .document(id)
            .setData(newUser.asDictionary())
    }
    
    private func validate() -> Bool{
        errorMessage = ""
        let trimmedFirst = first_name.trimmingCharacters(in: .whitespaces)
        let trimmedLast = last_name.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        guard !trimmedFirst.isEmpty,
              !trimmedLast.isEmpty,
              !trimmedEmail.isEmpty,
              !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please fill in all fields"
            return false
        }

        guard trimmedFirst.count <= 100 else {
            errorMessage = "First name is too long (max 100 characters)"
            return false
        }

        guard trimmedLast.count <= 100 else {
            errorMessage = "Last name is too long (max 100 characters)"
            return false
        }

        // Basic email format: something@domain.tld (at least 2-char TLD)
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard trimmedEmail.range(of: emailRegex, options: .regularExpression) != nil else {
            errorMessage = "Please enter a valid email address"
            return false
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters long"
            return false
        }
        return true
    }
}
