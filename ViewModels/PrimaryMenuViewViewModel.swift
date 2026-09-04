//
//  PrimaryMenuViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//
import FirebaseAuth
import Foundation
class PrimaryMenuViewViewModel: ObservableObject {
    @Published var currentUserId: String = ""
    private var handler: AuthStateDidChangeListenerHandle?
    init(){
        self.handler = Auth.auth().addStateDidChangeListener {[weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUserId = user?.uid ?? ""
            }
        }
    }
    
    public var isSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }
    
    func logOut(){
        // Remove auth state listener before signing out to prevent crashes
        if let handler = handler {
            Auth.auth().removeStateDidChangeListener(handler)
            self.handler = nil
        }

        // Clear biometric credentials from Keychain so the next user can't reuse them
        BiometricCredentialStore.shared.clear()
        UserDefaults.standard.set(false, forKey: "biometric_login_enabled")

        // Clear current user ID
        DispatchQueue.main.async { [weak self] in
            self?.currentUserId = ""
        }

        // Sign out
        do {
            try Auth.auth().signOut()
        } catch {
            AppLogger.error(AppLogger.auth, "Error signing out: \(error.localizedDescription)")
        }
    }
    
    deinit {
        // Clean up listener if view model is deallocated
        if let handler = handler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
}
