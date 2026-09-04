//
//  AppStoreConfig.swift
//  The Ideal Week
//
//  Configuration for App Store Connect and In-App Purchases
//

import Foundation

struct AppStoreConfig {
    // Temporary release switch:
    // false = bypass/hide subscription workflow (used for TestFlight archive validation)
    // true  = enforce normal subscription workflow
    static let isSubscriptionWorkflowEnabled = false

    // Community "Top Ideals from the Community" browser.
    // false = hide every entry point (the personal "Your Top Ideals" is unaffected)
    // true  = show it again
    static let isCommunityIdealsEnabled = false

    // Product IDs
    static let productIDs = ["idealweekapp", "idealweekappyearly"]
    
    // Apple ID for reference
    static let expectedAppleID = "6756083434"
    
    // App Store Server API Configuration
    // SECURITY: Server-to-server credentials removed from client app.
    // These must only exist on a secure backend server, never in the iOS binary.
    // If needed, store in a backend environment variable or secrets manager.
    
    // Bundle Identifier
    static let bundleIdentifier = "org.loveandchaos.theidealweek"
    
    // Subscription Group Configuration
    static let subscriptionGroupID = "21844932"
    static let subscriptionGroupName = "app fees"
}
