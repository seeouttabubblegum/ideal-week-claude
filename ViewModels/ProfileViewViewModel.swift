//
//  ProfileViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit
import SwiftData

class ProfileViewViewModel: ObservableObject {
    
    @Published var user: User? = nil
    @Published var profileImage: UIImage? = nil
    @Published var isLoading = false

    private let db = Firestore.firestore()

    func fetchUser(){
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(), error == nil else { return }
            DispatchQueue.main.async {
                var user = User(
                    id: data["id"] as? String ?? "",
                    first_name: data["first_name"] as? String ?? "",
                    last_name: data["last_name"] as? String ?? "",
                    email: data["email"] as? String ?? "",
                    joined: data["joined"] as? TimeInterval ?? 0
                )
                
                // Load optional fields
                if let dob = data["date_of_birth"] as? TimeInterval {
                    user.date_of_birth = dob
                }
                user.gender = data["gender"] as? String
                user.address = data["address"] as? String
                user.city = data["city"] as? String
                user.state = data["state"] as? String
                user.zip_code = data["zip_code"] as? String
                user.country = data["country"] as? String ?? "United States"
                user.height_feet = data["height_feet"] as? Int
                user.height_inches = data["height_inches"] as? Int
                if let weight = data["weight_kg"] as? Double {
                    user.weight_kg = weight
                } else if let weight = data["weight_kg"] as? String, let weightDouble = Double(weight) {
                    user.weight_kg = weightDouble
                }
                user.wake_up_time = data["wake_up_time"] as? String
                user.sleep_time = data["sleep_time"] as? String
                user.work_time_start = data["work_time_start"] as? String
                user.work_time_end = data["work_time_end"] as? String
                user.bio = data["bio"] as? String
                user.goal_focus_areas = data["goal_focus_areas"] as? String
                
                self?.user = user
            }
        }
    }

    init(){}
    
    func logOut(){
        // Clear user data before signing out
        DispatchQueue.main.async { [weak self] in
            self?.user = nil
            self?.profileImage = nil
        }
        
        // Sign out
        do {
            try Auth.auth().signOut()
        } catch {
            AppLogger.error(AppLogger.auth, "Error signing out: \(error.localizedDescription)")
        }
    }
    
    func saveProfilePicture(_ image: UIImage, to context: ModelContext, userId: String) {
        isLoading = true
        
        // Compress image to reduce storage size
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            isLoading = false
            return
        }
        
        // Fetch existing profile settings or create new
        let descriptor = FetchDescriptor<UserProfileSettings>(
            predicate: #Predicate<UserProfileSettings> { $0.userId == userId }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            existing.profilePictureData = imageData
        } else {
            let newProfileSettings = UserProfileSettings(userId: userId, profilePictureData: imageData)
            context.insert(newProfileSettings)
        }
        
        // Save to context
        do {
            try context.save()
            profileImage = image
            isLoading = false
        } catch {
            isLoading = false
        }
    }
    
    func loadProfilePicture(from context: ModelContext, userId: String) -> UIImage? {
        let descriptor = FetchDescriptor<UserProfileSettings>(
            predicate: #Predicate<UserProfileSettings> { $0.userId == userId }
        )
        
        if let profileSettings = try? context.fetch(descriptor).first,
           let imageData = profileSettings.profilePictureData,
           let image = UIImage(data: imageData) {
            return image
        }
        
        return nil
    }
    
    func updateProfile(data: [String: Any?], completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        isLoading = true

        // Filter out nil values and prepare update data
        var updateData: [String: Any] = [:]
        for (key, value) in data {
            if let val = value {
                updateData[key] = val
            }
            // Note: We don't explicitly delete fields with nil values
            // Firestore will keep existing values if we don't update them
        }
        
        db.collection("users").document(userId).updateData(updateData) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if error == nil {
                    // Refresh user data
                    self?.fetchUser()
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    func updatePassword(currentPassword: String, newPassword: String, completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            completion(false)
            return
        }
        
        isLoading = true
        
        // Reauthenticate user with current password
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        user.reauthenticate(with: credential) { [weak self] result, error in
            if error != nil {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    completion(false)
                }
                return
            }
            
            // Update password
            user.updatePassword(to: newPassword) { error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    completion(error == nil)
                }
            }
        }
    }
}
