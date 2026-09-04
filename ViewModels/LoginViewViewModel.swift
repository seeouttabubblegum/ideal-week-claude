//
//  LoginViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//
import FirebaseAuth
import Foundation
import LocalAuthentication
import Combine
import Network
import SwiftData

@MainActor
class LoginViewViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var errorMessage: String = ""
    @Published var biometricError: String = ""
    @Published var isConnected: Bool = true
    @Published var resetEmail: String = ""
    @Published var resetErrorMessage: String = ""
    @Published var resetSuccessMessage: String = ""
    @Published var isResettingPassword: Bool = false
    @Published var isLoggingIn: Bool = false
    
    private var cancellable: AnyCancellable?

    init() {
        cancellable = NetworkMonitor.shared.$isConnected
            .sink { [weak self] connected in
                Task { @MainActor [weak self] in
                    self?.isConnected = connected
                }
            }
    }
    
    deinit {
        cancellable?.cancel()
    }
    
    func login() {
        guard validate() else {
            return
        }
        guard !isLoggingIn else { return }

        errorMessage = "" // Clear previous errors
        isLoggingIn = true

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoggingIn = false

                if let error = error {
                    self.errorMessage = authErrorMessage(for: error)
                } else {
                    // Store credentials for biometric login if biometric is enabled and login is successful
                    if UserDefaults.standard.bool(forKey: "biometric_login_enabled") {
                        self.storeCredentialsForBiometric()
                    }
                    self.errorMessage = "" // Clear error on success
                    // Clear credentials from memory after successful login
                    self.email = ""
                    self.password = ""
                }
            }
        }
    }
    
    func loginWithBiometrics(completion: @escaping (Bool, String?) -> Void) {
        // Check if biometric login is enabled
        guard isBiometricLoginEnabled() else {
            completion(false, "Please enable biometric login first by logging in with your username and password")
            return
        }
        
        // Get stored credentials
        guard let credentials = getStoredCredentials() else {
            completion(false, "No stored credentials found. Please login with username and password first.")
            return
        }
        
        let context = LAContext()
        var error: NSError?
        // Check whether biometric authentication is available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let biometricType = getBiometricType()
            let reason = "Authenticate with \(biometricType) to login."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, authenticationError in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if success {
                        // Auto-login with stored credentials (don't expose to @Published state)
                        self.isLoggingIn = true
                        Auth.auth().signIn(withEmail: credentials.email, password: credentials.password) { [weak self] _, error in
                            Task { @MainActor [weak self] in
                                self?.isLoggingIn = false
                            }
                        }
                        completion(true, nil)
                    } else {
                        let message = authenticationError?.localizedDescription ?? "Failed to authenticate."
                        self.biometricError = message
                        completion(false, message)
                    }
                }
            }
        } else {
            let message = error?.localizedDescription ?? "Biometric authentication not available."
            self.biometricError = message
            completion(false, message)
        }
    }
    
    func isBiometricLoginEnabled() -> Bool {
        // Check UserDefaults for biometric login setting
        return UserDefaults.standard.bool(forKey: "biometric_login_enabled")
    }
    
    func storeCredentialsForBiometric() {
        BiometricCredentialStore.shared.store(email: email, password: password)
    }
    
    func getStoredCredentials() -> (email: String, password: String)? {
        BiometricCredentialStore.shared.fetch()
    }
    
    func clearStoredCredentials() {
        BiometricCredentialStore.shared.clear()
    }
    
    static func getBiometricType() -> String {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                return "Face ID"
            case .touchID:
                return "Touch ID"
            case .opticID:
                return "Optic ID"
            default:
                return "Biometric"
            }
        }
        return "Biometric"
    }
    
    func getBiometricType() -> String {
        return LoginViewViewModel.getBiometricType()
    }
    
    func sendPasswordReset() {
        resetErrorMessage = ""
        resetSuccessMessage = ""
        
        guard !resetEmail.trimmingCharacters(in: .whitespaces).isEmpty else {
            resetErrorMessage = "Please enter your email address"
            return
        }
        
        guard resetEmail.contains("@") && resetEmail.contains(".") else {
            resetErrorMessage = "Please enter a valid email address"
            return
        }
        
        isResettingPassword = true
        
        Auth.auth().sendPasswordReset(withEmail: resetEmail) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isResettingPassword = false
                
                if let error = error {
                    self.resetErrorMessage = authErrorMessage(for: error)
                } else {
                    self.resetSuccessMessage = "Password reset email sent! Please check your inbox."
                    self.resetEmail = "" // Clear email after success
                }
            }
        }
    }
    
    private func validate() -> Bool {
        errorMessage = ""
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty, !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please fill in all fields"
            return false
        }
        
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter valid email"
            return false
        }
        return true
    }
}

/// Maps Firebase Auth error codes to user-friendly messages.
/// Shared by LoginViewViewModel and RegisterViewViewModel.
func authErrorMessage(for error: Error) -> String {
    let code = (error as NSError).code
    switch code {
    case AuthErrorCode.invalidEmail.rawValue:
        return "Invalid email address. Please check and try again."
    case AuthErrorCode.networkError.rawValue:
        return "Network error. Please check your internet connection."
    case AuthErrorCode.userNotFound.rawValue:
        return "No account found with this email address."
    case AuthErrorCode.wrongPassword.rawValue:
        return "Incorrect password. Please try again."
    case AuthErrorCode.tooManyRequests.rawValue:
        return "Too many failed attempts. Please try again later."
    case AuthErrorCode.emailAlreadyInUse.rawValue:
        return "An account with this email already exists. Please use a different email or try logging in."
    case AuthErrorCode.weakPassword.rawValue:
        return "Password is too weak. Please use a stronger password (at least 6 characters)."
    default:
        return error.localizedDescription
    }
}
