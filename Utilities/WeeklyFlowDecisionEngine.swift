//
//  WeeklyFlowDecisionEngine.swift
//  The Ideal Week
//
//  Pure decision logic for the weekly planning flow, extracted from IdealListView
//  for testability. No SwiftUI, Firebase, or UserDefaults dependencies.
//

import Foundation

/// Encapsulates the weekly prompt flow decision logic as a pure function.
/// All inputs are provided explicitly — no singletons or side effects.
enum WeeklyFlowDecisionEngine {

    /// All inputs needed to make a weekly flow decision.
    struct Input {
        let isWeeklyFlowPresentationActive: Bool
        let flowAlreadyProcessed: Bool
        let daysSinceWeekStart: Int
        let planExistsForCurrentWeek: Bool
        let openCount: Int
        let alreadyShownLastWeekReview: Bool
        let hasPresentedPlanningThisSession: Bool
        /// One-time, account-targeted override (e.g. a support reset) that forces
        /// the weekly prompt to re-present once, bypassing the processed /
        /// day-limit / max-showings / plan-exists gates. Defaults to false.
        let forceShow: Bool
        /// Whether the account has any ideal in a week strictly BEFORE the
        /// current one. The whole weekly flow (recap + choice) is built on the
        /// previous week's ideals, so a first-active-week account has nothing
        /// to recap or re-plan — the flow must stay silent. Defaults to true
        /// (the pre-existing behavior for established accounts).
        let hasPreviousWeekIdeals: Bool

        init(
            isWeeklyFlowPresentationActive: Bool,
            flowAlreadyProcessed: Bool,
            daysSinceWeekStart: Int,
            planExistsForCurrentWeek: Bool,
            openCount: Int,
            alreadyShownLastWeekReview: Bool,
            hasPresentedPlanningThisSession: Bool,
            forceShow: Bool = false,
            hasPreviousWeekIdeals: Bool = true
        ) {
            self.isWeeklyFlowPresentationActive = isWeeklyFlowPresentationActive
            self.flowAlreadyProcessed = flowAlreadyProcessed
            self.daysSinceWeekStart = daysSinceWeekStart
            self.planExistsForCurrentWeek = planExistsForCurrentWeek
            self.openCount = openCount
            self.alreadyShownLastWeekReview = alreadyShownLastWeekReview
            self.hasPresentedPlanningThisSession = hasPresentedPlanningThisSession
            self.forceShow = forceShow
            self.hasPreviousWeekIdeals = hasPreviousWeekIdeals
        }
    }

    /// The decision output — what the flow should do.
    enum Decision: Equatable {
        /// Do nothing — a guard blocked the flow.
        case blocked(reason: BlockReason)
        /// Show the last week review (recap), then proceed to choice prompt on dismiss.
        case showRecapThenChoice
        /// Show the last week review only (plan exists), then mark flow complete on dismiss.
        case showRecapOnly
        /// Skip recap (already shown), show choice prompt directly.
        case showChoicePrompt
        /// Plan exists and recap already shown — mark flow complete immediately.
        case markFlowComplete
    }

    enum BlockReason: Equatable {
        case weeklyFlowAlreadyActive
        case flowAlreadyProcessed
        case dayBeyondLimit
        case maxShowingsReached
        case sessionAlreadyPresented
        /// First active week: the account has no ideal in any week before the
        /// current one, so there is nothing to recap or re-plan.
        case noPreviousWeekIdeals
    }

    /// Pure decision function. Returns what the weekly flow should do given the inputs.
    static func decide(_ input: Input) -> Decision {
        // Gate 1: Modal already active
        guard !input.isWeeklyFlowPresentationActive else {
            return .blocked(reason: .weeklyFlowAlreadyActive)
        }

        // One-time forced re-present (e.g. a support reset): bypass the processed /
        // day-limit / max-showings / plan-exists gates and present the recap+choice
        // once. Still avoids duplicate UI within a session.
        if input.forceShow {
            if !input.alreadyShownLastWeekReview {
                return .showRecapThenChoice
            } else if !input.hasPresentedPlanningThisSession {
                return .showChoicePrompt
            } else {
                return .blocked(reason: .sessionAlreadyPresented)
            }
        }

        // Gate 2: First active week — no previous-week ideals means the whole
        // flow (recap of last week + "what do you wanna do this week?") has no
        // basis. A brand-new user creating their first ideal lands here.
        // Placed after forceShow so the explicit support/test override still works.
        guard input.hasPreviousWeekIdeals else {
            return .blocked(reason: .noPreviousWeekIdeals)
        }

        // Gate 3: Flow already processed this week
        guard !input.flowAlreadyProcessed else {
            return .blocked(reason: .flowAlreadyProcessed)
        }

        // Gate 3: Day limit (days 0-4 allowed, day 5+ blocked)
        guard input.daysSinceWeekStart <= 4 else {
            return .blocked(reason: .dayBeyondLimit)
        }

        // Branch: Plan already exists for current week
        if input.planExistsForCurrentWeek {
            if !input.alreadyShownLastWeekReview {
                return .showRecapOnly
            } else {
                return .markFlowComplete
            }
        }

        // Gate 5: Max 2 planning showings per week
        guard input.openCount < 2 else {
            return .blocked(reason: .maxShowingsReached)
        }

        // Gate 6: Show recap or choice prompt
        if !input.alreadyShownLastWeekReview {
            return .showRecapThenChoice
        } else if !input.hasPresentedPlanningThisSession {
            return .showChoicePrompt
        } else {
            return .blocked(reason: .sessionAlreadyPresented)
        }
    }

    /// After recap dismiss: decide whether to show choice prompt or mark flow complete.
    static func decideAfterRecapDismiss(
        planningSheetAlreadyShown: Bool,
        hasPresentedPlanningThisSession: Bool
    ) -> RecapDismissDecision {
        if planningSheetAlreadyShown {
            return .markFlowComplete
        } else if !hasPresentedPlanningThisSession {
            return .showChoicePrompt
        } else {
            return .skipUntilNextSession
        }
    }

    enum RecapDismissDecision: Equatable {
        case markFlowComplete
        case showChoicePrompt
        case skipUntilNextSession
    }
}
