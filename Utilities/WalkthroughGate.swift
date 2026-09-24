//
//  WalkthroughGate.swift
//  The Ideal Week
//
//  The first-run walkthroughs: four short guided tours, each tied to the moment
//  it explains, each shown once per user.
//
//  Keyed PER USER for the same reason `OnboardingGate` is: device-global flags
//  meant a second account on the same phone silently missed everything.
//

import Foundation

enum Walkthrough: String, CaseIterable {
    /// The ideals list, right after onboarding finishes — and straight through
    /// the New Ideal screen, where the user types and saves a real first ideal.
    case firstLaunchTour
    /// The Next? page, the first time it opens.
    case nextTab
    /// The first plan — the "Missed Anything?" step with a starter ideal in it.
    case firstPlan
}

enum WalkthroughGate {
    static func seenKey(_ walkthrough: Walkthrough, uid: String) -> String {
        "walkthrough_\(walkthrough.rawValue)_\(uid)"
    }

    /// Whether `walkthrough` should start now.
    ///
    /// - Parameters:
    ///   - seen: this user has already been through it (or skipped it).
    ///   - onboardingFinished: the preferences step is done. Only the list
    ///     tour waits for it — the others belong to a screen the user has just
    ///     opened, and a user who skipped onboarding needs them more, not less.
    ///   - isNewAccount: the account was created recently
    ///     (`OnboardingGate.isNewAccount`). Someone reinstalling the app and
    ///     signing back in already knows it; their per-user flags went with the
    ///     old install, so account age is what keeps the tours away. Asking for
    ///     them from Help bypasses this.
    static func shouldRun(_ walkthrough: Walkthrough,
                          seen: Bool,
                          onboardingFinished: Bool,
                          isNewAccount: Bool) -> Bool {
        guard !seen, isNewAccount else { return false }
        switch walkthrough {
        case .firstLaunchTour: return onboardingFinished
        case .nextTab, .firstPlan: return true
        }
    }
}
