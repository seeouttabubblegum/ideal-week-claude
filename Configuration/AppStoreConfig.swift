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

    // Subscription terms (client, 2026-10-07). The price itself is set in App
    // Store Connect; this is what it is meant to be, so a mismatch in the US
    // store can be noticed (`SubscriptionPricing`).
    static let monthlyProductID = "idealweekapp"
    static let monthlyPriceUSD = Decimal(string: "6.99")!
    // Free days for everyone before a plan is needed. Apple's introductory
    // offers cannot be 17 days, so the app counts them itself (`FreeTrial`);
    // do not also add an Apple free-trial offer, or people get both.
    static let freeTrialDays = 17
    
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
