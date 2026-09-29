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
    /// The Next? page when next week is locked behind the PIN — the tour walks
    /// through setting it, then into planning.
    case nextPageLocked
    /// The Next? page when planning can start right away.
    case nextPageOpen
    /// The first plan, for someone who already has ideals: picking what comes
    /// with them, then the "Missed Anything?" step.
    case firstPlan
    /// The first plan for a brand-new user, whose plan opens with one starter
    /// ideal already in it — the one claim the other version must not make.
    case firstPlanStarter
}

enum WalkthroughGate {
    static func seenKey(_ walkthrough: Walkthrough, uid: String) -> String {
        "walkthrough_\(walkthrough.rawValue)_\(uid)"
    }

    /// "Show tips again" in Help, remembered per user so it outlives the run.
    static func tipsRequestedKey(uid: String) -> String {
        "walkthrough_tipsRequested_\(uid)"
    }

    /// How long after the install the tours may still start on their own.
    static let automaticWindow: TimeInterval = 14 * 86_400

    /// Slack for the account's creation time (the server's clock) against the
    /// install date (the phone's clock).
    static let clockSlack: TimeInterval = 60 * 60

    /// Whether the tours may start by themselves for this user (client,
    /// 2026-09-29): only on the FIRST install — the account was made on this
    /// install, so it is a new user, not an existing one reinstalling — and
    /// only within two weeks of that install. Anything unseen by then stays
    /// unseen unless the user turns the tips back on from Help.
    static func allowsAutomaticTours(accountCreated: Date?,
                                     installedAt: Date,
                                     now: Date = Date()) -> Bool {
        guard let accountCreated else { return false }
        let madeOnThisInstall = accountCreated >= installedAt.addingTimeInterval(-clockSlack)
        let withinWindow = now.timeIntervalSince(installedAt) < automaticWindow
        return madeOnThisInstall && withinWindow
    }

    /// Whether `walkthrough` should start now.
    ///
    /// - Parameters:
    ///   - seen: this user has already been through it (or skipped it).
    ///   - onboardingFinished: the preferences step is done. Only the list
    ///     tour waits for it — the others belong to a screen the user has just
    ///     opened, and a user who skipped onboarding needs them more, not less.
    ///   - automaticAllowed: `allowsAutomaticTours` — a new user, inside two
    ///     weeks of installing. Someone reinstalling the app and signing back
    ///     in already knows it; their per-user flags went with the old install,
    ///     so the account's age against the install is what keeps the tours
    ///     away. Asking for them from Help bypasses this.
    static func shouldRun(_ walkthrough: Walkthrough,
                          seen: Bool,
                          onboardingFinished: Bool,
                          automaticAllowed: Bool) -> Bool {
        guard !seen, automaticAllowed else { return false }
        switch walkthrough {
        case .firstLaunchTour: return onboardingFinished
        case .nextPageLocked, .nextPageOpen, .firstPlan, .firstPlanStarter: return true
        }
    }
}
