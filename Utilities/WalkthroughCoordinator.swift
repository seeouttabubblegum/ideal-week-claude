//
//  WalkthroughCoordinator.swift
//  The Ideal Week
//
//  Remembers which walkthroughs a user has been through, and owns the one that
//  is running.
//

import SwiftUI

/// Per-user record of the walkthroughs already shown. `UserDefaults` is
/// injected so the rule can be tested without touching the app's own store.
struct WalkthroughStore {
    let defaults: UserDefaults

    static let standard = WalkthroughStore(defaults: .standard)

    func isSeen(_ walkthrough: Walkthrough, uid: String) -> Bool {
        defaults.bool(forKey: WalkthroughGate.seenKey(walkthrough, uid: uid))
    }

    func markSeen(_ walkthrough: Walkthrough, uid: String) {
        defaults.set(true, forKey: WalkthroughGate.seenKey(walkthrough, uid: uid))
    }

    /// "Show tips again" in Help — this user only.
    func resetAll(uid: String) {
        for walkthrough in Walkthrough.allCases {
            defaults.removeObject(forKey: WalkthroughGate.seenKey(walkthrough, uid: uid))
        }
    }
}

@MainActor
final class WalkthroughCoordinator: ObservableObject {
    /// One per app run: screens and sheets all show the same tour, and a sheet
    /// cannot inherit an overlay from the page underneath it.
    static let shared = WalkthroughCoordinator()

    @Published private(set) var run: WalkthroughRun?

    /// What the tour is asking the app to do right now — opening the New Ideal
    /// screen, so the user does not have to find the plus button themselves.
    /// The screen that acts on it calls `clearRequest()`.
    @Published private(set) var request: WalkthroughRequest?

    /// The title of the ideal the user created during the tour, so the step
    /// after the form can point at their own row.
    @Published private(set) var createdIdealTitle: String?

    /// Set by "Show tips again": the list tour belongs to onboarding, so
    /// without this the list would never offer it a second time.
    private var replayRequested = false

    private let store: WalkthroughStore
    private(set) var uid: String
    /// Whether this account was created recently. Tours only start on their own
    /// for new accounts; a returning user can still ask for them.
    private(set) var isNewAccount = false

    init(store: WalkthroughStore = .standard, uid: String = "") {
        self.store = store
        self.uid = uid
    }

    func setUser(_ uid: String) {
        guard uid != self.uid else { return }
        self.uid = uid
        run = nil
    }

    func setAccountAge(isNewAccount: Bool) {
        self.isNewAccount = isNewAccount
    }

    /// Start `walkthrough` if this user has not had it. Never interrupts one
    /// that is already running — a second tour would cover the first.
    /// - Parameter asked: the user asked for this themselves (Help's "Show tips
    ///   again", or the test link), which overrides the once-per-user record
    ///   and the new-account rule.
    func start(_ walkthrough: Walkthrough, onboardingFinished: Bool = true, asked: Bool = false) {
        guard run == nil, !uid.isEmpty else { return }
        guard asked || WalkthroughGate.shouldRun(walkthrough,
                                                 seen: store.isSeen(walkthrough, uid: uid),
                                                 onboardingFinished: onboardingFinished,
                                                 isNewAccount: isNewAccount) else { return }
        createdIdealTitle = nil
        withAnimation(.easeOut(duration: 0.25)) {
            run = WalkthroughRun(walkthrough: walkthrough)
        }
        raiseRequestOfCurrentStep()
    }

    /// Called when the ideals list appears. Starts the list tour only after a
    /// replay — its normal start is the end of onboarding.
    /// The Next? page tour — the first time that page is opened, and only once
    /// the list tour is behind the user (it is a separate lesson, not part of
    /// the first run).
    func startNextPageTour() {
        guard hasSeen(.firstLaunchTour), !hasSeen(.nextTab) else { return }
        start(.nextTab, onboardingFinished: true, asked: true)
    }

    func startOnListAppear() {
        guard replayRequested else { return }
        replayRequested = false
        start(.firstLaunchTour, onboardingFinished: true, asked: true)
    }

    func advance() {
        guard var current = run else { return }
        current.advance()
        finishOrKeep(current)
    }

    /// Remembers what the user called the ideal they made during the tour.
    func noteCreatedIdeal(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        createdIdealTitle = trimmed.isEmpty ? nil : trimmed
    }

    /// Something the user did — typing a title, saving, closing the form.
    func report(_ event: WalkthroughEvent) {
        guard var current = run else { return }
        current.report(event)
        finishOrKeep(current)
    }

    /// Called by the screen that has acted on `request`.
    func clearRequest() { request = nil }

    func skip() {
        guard var current = run else { return }
        current.skip()
        finishOrKeep(current)
    }

    /// Whether a given walkthrough has already been shown — the starter ideal
    /// in the first plan asks this too.
    func hasSeen(_ walkthrough: Walkthrough) -> Bool {
        store.isSeen(walkthrough, uid: uid)
    }

    /// Test entry point (the link beside the weekly-prompt one): forget the
    /// record and run the list tour immediately, whatever has been seen.
    func restartTour() {
        replayAll()
        replayRequested = false
        start(.firstLaunchTour, onboardingFinished: true, asked: true)
    }

    func replayAll() {
        store.resetAll(uid: uid)
        replayRequested = true
        run = nil
    }

    private func finishOrKeep(_ current: WalkthroughRun) {
        if current.isFinished {
            store.markSeen(current.walkthrough, uid: uid)
            withAnimation(.easeOut(duration: 0.2)) { run = nil }
            request = nil
        } else {
            run = current
            raiseRequestOfCurrentStep()
        }
    }

    private func raiseRequestOfCurrentStep() {
        if let stepRequest = run?.step?.request {
            request = stepRequest
        }
    }
}
