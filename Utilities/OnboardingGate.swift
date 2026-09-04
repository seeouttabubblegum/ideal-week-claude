//
//  OnboardingGate.swift
//  The Ideal Week
//
//  Pure decision logic for the first-launch onboarding (help screens + default
//  preferences), keyed PER USER.
//
//  History: the shown/completed flags used to be device-global UserDefaults
//  keys ("hasSeenHelpOnboarding" / "hasCompletedOnboardingSettings"), so a
//  brand-new account created on a device where any earlier account had
//  finished onboarding silently skipped it. The gate now uses per-uid keys,
//  detects fresh accounts from Firebase's account creationDate (metadata
//  arrives synchronously with auth — no racy registration-time flag), and
//  migrates the legacy globals onto old accounts so they are never re-shown.
//
//  The legacy global keys are intentionally NEVER cleared: a second legacy
//  account on the same device must also be able to migrate.
//

import Foundation

enum OnboardingGate {

    // MARK: - Keys

    static let legacySeenHelpKey = "hasSeenHelpOnboarding"
    static let legacyCompletedSettingsKey = "hasCompletedOnboardingSettings"

    static func seenHelpKey(uid: String) -> String { "hasSeenHelpOnboarding_\(uid)" }
    static func completedSettingsKey(uid: String) -> String { "hasCompletedOnboardingSettings_\(uid)" }

    /// Accounts created within this window count as "new" — their onboarding
    /// shows even on a device whose legacy globals say it was already seen
    /// (those belong to an older account). Registration presents the main view
    /// within seconds, so this window is generous headroom, not a requirement.
    static let newAccountWindow: TimeInterval = 7 * 86_400

    static func isNewAccount(creationDate: Date?, now: Date = Date()) -> Bool {
        guard let creationDate else { return false }
        return now.timeIntervalSince(creationDate) < newAccountWindow
    }

    // MARK: - Decision

    struct Signals {
        /// Account was created recently (see `isNewAccount`).
        let isNewAccount: Bool
        /// Per-user keys for the signed-in uid.
        let userSeenHelp: Bool
        let userCompletedSettings: Bool
        /// Device-global keys from before per-user scoping.
        let legacySeenHelp: Bool
        let legacyCompletedSettings: Bool
    }

    enum Decision: Equatable {
        /// Present the help onboarding (settings follow when help is dismissed).
        case showHelp
        /// Help already seen — present only the default-preferences step.
        case showSettings
        /// Nothing to present.
        case none
    }

    struct Outcome: Equatable {
        let decision: Decision
        /// When true, the caller should stamp the legacy global values into
        /// this uid's per-user keys (the account predates per-user scoping).
        let migrateLegacyToUser: Bool
    }

    static func decide(_ s: Signals) -> Outcome {
        // 1. This user's own record wins.
        if s.userSeenHelp {
            return Outcome(decision: s.userCompletedSettings ? .none : .showSettings,
                           migrateLegacyToUser: false)
        }
        // 2. Fresh account: the legacy globals (if any) belong to an older
        //    account on this device — ignore them and onboard.
        if s.isNewAccount {
            return Outcome(decision: .showHelp, migrateLegacyToUser: false)
        }
        // 3. Old account with legacy device state: it was this account (or its
        //    era) that saw onboarding under the global keys — migrate, resume
        //    the settings step only if it was never completed.
        if s.legacySeenHelp {
            return Outcome(decision: s.legacyCompletedSettings ? .none : .showSettings,
                           migrateLegacyToUser: true)
        }
        // 4. Old account, fresh device: same as the app has always behaved.
        return Outcome(decision: .showHelp, migrateLegacyToUser: false)
    }
}
