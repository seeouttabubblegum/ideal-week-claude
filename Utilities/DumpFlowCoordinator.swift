//
//  DumpFlowCoordinator.swift
//  The Ideal Week
//
//  Opens and closes the first-week dump (`DumpFlowView`), and decides what
//  follows it: the tour prompt after a save, the old first-run tour after a
//  close. `MenuView` hosts the cover; the temporary test link opens it too.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class DumpFlowCoordinator: ObservableObject {
    static let shared = DumpFlowCoordinator()

    @Published var isPresented = false
    /// "Want a quick tour?" after a save.
    @Published var offersTour = false
    /// Opened from the test link: an existing account, no first-run rules.
    private(set) var isTestRun = false

    private enum Outcome { case saved, closed }
    private var outcome: Outcome?
    private var uid = ""
    /// Where the done flag lives (injectable for tests).
    private var defaults: UserDefaults = .standard
    /// What a first-run close falls back to — the list tour, as before.
    private var afterClose: (() -> Void)?

    /// First run: open the dump if this user should get it, otherwise run
    /// `fallback` (the old start of the list tour). Any doubt — a failed read,
    /// an empty uid — takes the fallback, so nothing changes for anyone else.
    func openIfNeeded(uid: String,
                      automaticAllowed: Bool,
                      defaults: UserDefaults = .standard,
                      fallback: @escaping () -> Void) {
        self.defaults = defaults
        let done = defaults.bool(forKey: DumpFlowGate.doneKey(uid: uid))
        guard !uid.isEmpty, DumpFlowGate.shouldCheck(automaticAllowed: automaticAllowed, done: done) else {
            fallback()
            return
        }
        // The server, not the cache: a reinstall starts with an empty cache.
        Firestore.firestore().collection("users").document(uid).collection("ideals")
            .getDocuments(source: .server) { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self, error == nil, let snapshot else {
                        fallback()
                        return
                    }
                    let flags = snapshot.documents.map { $0.data()["wishlistEnabled"] as? Bool }
                    let hasWeekIdeal = DumpFlowGate.hasAnyWeekIdeal(wishlistFlags: flags)
                    guard DumpFlowGate.shouldShow(automaticAllowed: automaticAllowed,
                                                  done: done,
                                                  hasAnyWeekIdeal: hasWeekIdeal) else {
                        // Ideals already in a week: the dump can never apply,
                        // so stop asking on every launch.
                        if hasWeekIdeal { self.defaults.set(true, forKey: DumpFlowGate.doneKey(uid: uid)) }
                        fallback()
                        return
                    }
                    self.afterClose = fallback
                    // Let the preferences sheet finish closing first.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                        guard let self else { return }
                        // Still the same account — a sign-out in between
                        // must not open another user's dump.
                        guard Auth.auth().currentUser?.uid == uid else {
                            self.afterClose = nil
                            return
                        }
                        self.present(testRun: false)
                    }
                }
            }
    }

    /// The temporary test link — any account, any time.
    func openForTest() {
        afterClose = nil
        present(testRun: true)
    }

    private func present(testRun: Bool) {
        guard !isPresented else { return }
        isTestRun = testRun
        outcome = nil
        isPresented = true
    }

    /// Called by the dump when it is saved or closed. Either way it never
    /// opens by itself again for this user.
    func finish(saved: Bool, uid: String, defaults: UserDefaults = .standard) {
        if !uid.isEmpty { defaults.set(true, forKey: DumpFlowGate.doneKey(uid: uid)) }
        outcome = saved ? .saved : .closed
        isPresented = false
    }

    /// Called whenever the signed-in account is known. A different account
    /// starts clean — nothing from the last one may carry over.
    func setUser(_ uid: String) {
        guard uid != self.uid else { return }
        self.uid = uid
        reset()
    }

    func reset() {
        isPresented = false
        offersTour = false
        outcome = nil
        afterClose = nil
    }

    /// The cover has gone.
    func didDismiss() {
        defer { outcome = nil }
        switch outcome {
        case .saved?:
            offersTour = true
        case .closed?:
            if !isTestRun { afterClose?() }
        case nil:
            break
        }
        afterClose = nil
    }
}
