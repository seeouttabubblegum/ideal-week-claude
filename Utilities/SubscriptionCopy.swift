//
//  SubscriptionCopy.swift
//  The Ideal Week
//
//  What the subscription and offer-code screens say when something goes wrong.
//
//  These used to be written for whoever was debugging the build: product IDs,
//  "Ensure StoreKit Configuration schema is set to 'None' in Xcode", sandbox
//  tester accounts. None of that is something a user can act on, and most of it
//  is not even true on their device. The detail still goes to the log, where it
//  belongs; the screen gets the two things a person can actually check — their
//  connection, and whether they are signed in to the App Store.
//
//  Copy here is a first draft for the client to edit, like the rest.
//

import Foundation

enum SubscriptionCopy {

    /// Products came back empty — nothing the user did, and nothing they can fix.
    static let optionsUnavailable =
        "We couldn't load the subscription options just now. Please check your connection and try again."

    /// Loading the products threw.
    static let optionsLoadFailed =
        "Something went wrong loading the subscription options. Please try again."

    /// `AppStore.sync()` threw while restoring.
    static let restoreFailed =
        "We couldn't restore your purchases. Please check your connection and try again."

    /// A purchase threw (after the user confirmed it).
    static let purchaseFailed =
        "Your purchase didn't go through. Nothing has been charged — please try again."

    /// The offer-code sheet could not be opened.
    static let redeemSheetUnavailable =
        "We couldn't open the code sheet. Please make sure you're signed in to the App Store on this device, then try again."

    /// The offer-code sheet could not reach the store.
    static let offline =
        "We can't reach the App Store. Please check your connection and make sure you're signed in on this device."

    /// "Check subscription status" found nothing yet.
    static let noSubscriptionYet =
        "We can't see an active subscription yet. If you've just redeemed a code, give it a few seconds and check again."

    /// Shown under the price list, so nobody is surprised which account is charged.
    static let accountNote =
        "Purchases use the Apple ID signed in on this device."

    /// The first redemption step.
    static let redeemStepSignedIn =
        "Make sure you're signed in to the App Store on this device"

    /// Everything a user can be shown, for the copy tests to police.
    static let userFacingMessages: [String] = [
        optionsUnavailable,
        optionsLoadFailed,
        restoreFailed,
        purchaseFailed,
        redeemSheetUnavailable,
        offline,
        noSubscriptionYet,
        accountNote,
    ]
}
