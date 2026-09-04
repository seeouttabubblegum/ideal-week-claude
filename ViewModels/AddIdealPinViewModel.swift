//
//  AddIdealPinViewModel.swift
//  The Ideal Week
//
//  Created on 1/15/25.
//

import Foundation

class AddIdealPinViewModel: ObservableObject {
    @Published var enteredPin: String = ""
    @Published var confirmPin: String = ""
    @Published var pinDigits: [String] = Array(repeating: "", count: 4) // Individual digit fields
    @Published var confirmPinDigits: [String] = Array(repeating: "", count: 4) // For setting new PIN
    @Published var reason: String = ""
    @Published var showPinError: Bool = false
    @Published var showReasonError: Bool = false
    @Published var pinErrorMessage: String = ""
    @Published var currentScreen: PinScreen = .pinEntry
    @Published var isSettingPin: Bool = false // True when setting PIN for first time, false when entering existing PIN
    
    enum PinScreen {
        case pinEntry
        case reason
    }
    
    // Computed property to get PIN from digits array
    var enteredPinFromDigits: String {
        pinDigits.joined()
    }
    
    // Computed property to get confirm PIN from digits array
    var confirmPinFromDigits: String {
        confirmPinDigits.joined()
    }
    
    
    // Check if PIN is complete and valid (for auto-advance)
    func checkPinComplete(storedPin: String?, onError: (() -> Void)? = nil, onValid: @escaping () -> Void) {
        let pin = enteredPinFromDigits
        if pin.count == 4 {
            if let storedPin = storedPin, !storedPin.isEmpty {
                // PIN exists, validate entered PIN
                if pin == storedPin {
                    showPinError = false
                    onValid()
                } else {
                    showPinError = true
                    pinErrorMessage = "Incorrect PIN. Please try again."
                    // Clear PIN on error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.pinDigits = Array(repeating: "", count: 4)
                        onError?()
                    }
                }
            } else {
                // Setting new PIN - need to check if confirm is also complete
                let confirmPin = confirmPinFromDigits
                if confirmPin.count == 4 {
                    if pin == confirmPin {
                        showPinError = false
                        onValid()
                    } else {
                        showPinError = true
                        pinErrorMessage = "PINs do not match"
                        // Clear both PINs on error
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.pinDigits = Array(repeating: "", count: 4)
                            self.confirmPinDigits = Array(repeating: "", count: 4)
                            onError?()
                        }
                    }
                }
            }
        }
    }
    
    func canContinue() -> Bool {
        return !enteredPin.isEmpty
    }
    
    func canConfirm() -> Bool {
        return !reason.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func reset() {
        enteredPin = ""
        confirmPin = ""
        pinDigits = Array(repeating: "", count: 4)
        confirmPinDigits = Array(repeating: "", count: 4)
        reason = ""
        showPinError = false
        showReasonError = false
        pinErrorMessage = ""
        currentScreen = .pinEntry
        isSettingPin = false
    }
}

