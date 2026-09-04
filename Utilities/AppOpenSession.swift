//
//  AppOpenSession.swift
//  The Ideal Week
//
//  Counts "app opens" so features can be gated per open rather than per view
//  instance or per process. Introduced for the weekly prompt's second chance
//  (client rule: the automatic prompt may be offered on the first AND second
//  open of the week). Before this, that gate lived in an `@State` on
//  IdealListView, which is view-scoped: pushing a fresh IdealListView (e.g. My
//  Progress → Ideals) counted as a "second open", while closing and reopening
//  the app after a Skip never re-offered anything.
//
//  Definition of an open (client wording: "app close kore abar open korle"):
//    • process launch → open #0
//    • the app returns to the foreground after spending at least
//      `minimumBackgroundDwell` in the BACKGROUND → +1
//
//  The dwell requirement is what keeps "closed and reopened" distinct from
//  merely glancing away: locking the phone, taking a call, or checking Safari
//  for ten seconds all send the app to the background, and without the dwell a
//  user who tapped "Skip For Now" would be asked again seconds later — burning
//  both of the week's chances in one sitting. Not an open at all: `.inactive`
//  blips that never reach the background (Control Center, notification shade,
//  app-switcher peek, incoming-call banner), and any in-app navigation.
//
//  `noteScenePhase` is idempotent per background cycle, so the App struct and
//  any view may both report the same transition without double-counting;
//  whichever observer runs first performs the bump.
//

import SwiftUI

/// Main-actor isolated: scene-phase changes and the views that consult this all
/// run on the main thread, and the test target builds in Swift 6 mode.
@MainActor
enum AppOpenSession {
    /// How long the app must stay backgrounded for the return to count as a new
    /// open. Tuned so a lock/unlock or a quick app switch does not count.
    static let minimumBackgroundDwell: TimeInterval = 5 * 60

    /// Monotonic id of the current open. 0 = the launch open.
    private(set) static var currentId: Int = 0
    /// When the app entered the background; consumed by the next `.active`.
    private static var backgroundedAt: Date?

    /// Wall-clock is passed in so tests can drive the dwell deterministically.
    /// Deliberately `Date()` and not `DateProviderService` — this measures real
    /// elapsed time, and must not move when a tester overrides the virtual date.
    static func noteScenePhase(_ phase: ScenePhase, at now: Date = Date()) {
        switch phase {
        case .background:
            // Keep the earliest timestamp of this background stretch.
            if backgroundedAt == nil { backgroundedAt = now }
        case .active:
            guard let since = backgroundedAt else { return }
            backgroundedAt = nil
            let dwell = now.timeIntervalSince(since)
            guard dwell >= minimumBackgroundDwell else {
                AppLogger.debug(AppLogger.app, "[AppOpenSession] returned after \(Int(dwell))s — same open #\(currentId)")
                return
            }
            currentId += 1
            AppLogger.debug(AppLogger.app, "[AppOpenSession] new open #\(currentId) (backgrounded \(Int(dwell))s)")
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    /// True when `openId` (a value captured from `currentId` earlier) is still
    /// the open we are in. `nil` never matches — "not presented yet".
    static func isCurrentOpen(_ openId: Int?) -> Bool {
        openId == currentId
    }

    /// Test hook: back to the launch state.
    static func resetForTesting() {
        currentId = 0
        backgroundedAt = nil
    }
}
