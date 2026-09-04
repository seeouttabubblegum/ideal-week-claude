//
//  HapticFeedback.swift
//  The Ideal Week
//
//  Created for haptic feedback utility
//

import UIKit

struct HapticFeedback {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    static func success() {
        notification(type: .success)
    }
    
    static func error() {
        notification(type: .error)
    }
    
    static func warning() {
        notification(type: .warning)
    }
}

