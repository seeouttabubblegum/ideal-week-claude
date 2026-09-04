//
//  NextPlanningDecision.swift
//  The Ideal Week
//
//  What the Next? screen offers. Pure logic so the combinations are testable
//  without a view (same shape as WeeklyFlowDecisionEngine).
//
//  The screen shows up to TWO planning buttons, each owning one week:
//
//    1. Next week — always shown, original rules untouched: locked behind the
//       PIN when a plan already exists (re-plan) or when we are outside the
//       planning window.
//    2. Current week — shown ONLY when the current week has no ideals at all.
//       Sources the PREVIOUS ACTIVE week and saves straight into this week, no
//       PIN and no window lock (client rule, 2026-08-19/20). A user who missed
//       the planning window would otherwise be stranded with an empty week.
//
//  They are independent: an existing next-week plan no longer suppresses the
//  current-week route, because it no longer has to share one button with it.
//

import Foundation

enum NextPlanningDecision {

    /// The always-present next-week button.
    enum NextWeekMode: Equatable, CaseIterable {
        /// Inside the planning window with no plan yet — opens straight away.
        case plan
        /// A plan for next week already exists — PIN, then wipe and re-plan.
        case replanAfterPin
        /// Outside the planning window — PIN to unlock next week's plan.
        case unlockAfterPin

        /// The padlock on the button; also exactly the modes that ask for a PIN.
        var isLocked: Bool { requiresPin }

        var requiresPin: Bool { self != .plan }

        var buttonLabel: String {
            switch self {
            case .plan: return "Plan Your Next Week"
            case .replanAfterPin: return "Re-plan Next Week"
            case .unlockAfterPin: return "Unlock Next Week's Plan"
            }
        }
    }

    struct Layout: Equatable {
        let nextWeek: NextWeekMode
        /// The extra "fill this week from last active week" button.
        let showsFillCurrentWeek: Bool
    }

    static func layout(currentWeekIsEmpty: Bool,
                       hasPlanForNextWeek: Bool,
                       isWithinPlanningWindow: Bool) -> Layout {
        let nextWeek: NextWeekMode
        if hasPlanForNextWeek {
            nextWeek = .replanAfterPin
        } else if isWithinPlanningWindow {
            nextWeek = .plan
        } else {
            nextWeek = .unlockAfterPin
        }
        return Layout(nextWeek: nextWeek, showsFillCurrentWeek: currentWeekIsEmpty)
    }

    // MARK: - The "Again?" source list

    /// Which ideals the Next? screen offers to repeat: this week's, or — when
    /// this week is empty — the last week that actually had some.
    ///
    /// Applies to BOTH of its buttons. Planning next week off an empty current
    /// week used to open onto a blank Again? list with nothing to pick, which
    /// is exactly the situation the current-week button exists for; the source
    /// falls back either way, and only the TARGET week differs between them.
    static func againSourceIdeals<T>(currentWeek: [T], lastActiveWeek: [T]) -> [T] {
        currentWeek.isEmpty ? lastActiveWeek : currentWeek
    }

    // MARK: - The current-week button
    //
    // Constants rather than a mode: it has exactly one appearance and one
    // behaviour, and it only exists at all when the week is empty.

    /// Named for the week it actually writes — saying "Next Week" here told the
    /// user the opposite of what the button does.
    static let fillCurrentWeekLabel = "Plan Your Current Week"
    static let fillCurrentWeekIsLocked = false
    static let fillCurrentWeekRequiresPin = false
}
