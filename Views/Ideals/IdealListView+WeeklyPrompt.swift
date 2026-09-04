//
//  IdealListView+WeeklyPrompt.swift
//  The Ideal Week
//
//  Weekly prompt flow and related planning data helpers extracted from IdealListView.
//

import Foundation
import UIKit

extension IdealListView {
    // MARK: - Forced weekly-prompt re-present
    //
    // Weekly-prompt state lives entirely in device-local UserDefaults, so it
    // cannot be reset server-side. This flag forces the prompt to re-present
    // once on the next evaluation, then self-clears. Set only by the DEBUG test
    // trigger; the one-time reset that used to arm it for a specific support
    // account (jay@pijut.com) was removed before the App Store release — a
    // hardcoded real user's email must not ship.
    private static let weeklyPromptForceShowPendingKey = "weeklyPromptForceShowPending"
    // Records whether the recap currently on screen was presented by a forced
    // re-present. A forced recap deliberately bypasses the plan-exists gate, so
    // a plan arriving mid-recap must not retroactively close its choice prompt.
    // Captured at presentation because the force-show flag is already consumed
    // by then. Rewritten on every recap presentation, so it cannot go stale.
    private static let weeklyRecapForcedKey = "weeklyRecapForced"

    private static func weeklyKeySuffix(for date: Date = DateProviderService.shared.now(), weekStartDay: String) -> String {
        let weekStart = WeekdayUtility.weekStart(for: date, weekStartDay: weekStartDay).timeIntervalSince1970
        let dayToken = weekStartDay.lowercased().replacingOccurrences(of: " ", with: "_")
        return "\(dayToken)_\(Int(weekStart))"
    }

    private static func weeklyFlowProcessedKey(for date: Date = DateProviderService.shared.now(), weekStartDay: String) -> String {
        "weeklyFlowProcessed_\(weeklyKeySuffix(for: date, weekStartDay: weekStartDay))"
    }

    private static func weeklyPlanningSheetShownKey(for date: Date = DateProviderService.shared.now(), weekStartDay: String) -> String {
        "weeklyPlanningSheetShown_\(weeklyKeySuffix(for: date, weekStartDay: weekStartDay))"
    }

    private static func weeklyPromptOpenCountKey(for date: Date = DateProviderService.shared.now(), weekStartDay: String) -> String {
        "weeklyPromptOpenCount_\(weeklyKeySuffix(for: date, weekStartDay: weekStartDay))"
    }

    /// Increment the count of times the weekly prompt was opened this week (for debug/summary).
    /// Called only from main thread (SwiftUI action handlers), so read-then-write is safe.
    func incrementWeeklyPromptOpenCount() {
        guard let weekStartDay = storedTempSettings.first?.week_start_day else { return }
        let key = Self.weeklyPromptOpenCountKey(for: dateProvider.now(), weekStartDay: weekStartDay)
        let defaults = UserDefaults.standard
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }

    /// Number of times the weekly prompt was opened this week.
    var currentWeekWeeklyPromptOpenCount: Int {
        guard let weekStartDay = storedTempSettings.first?.week_start_day else { return 0 }
        let key = Self.weeklyPromptOpenCountKey(for: dateProvider.now(), weekStartDay: weekStartDay)
        return UserDefaults.standard.integer(forKey: key)
    }

    /// Plan-record IDs for current week that also have a matching non-wishlist ideal in current week.
    /// This is the strict "plan exists for current week" condition.
    var validCurrentWeekPlanRecordIds: Set<String> {
        let currentWeekRecordIds = plannedRecordIdsForCurrentWeek
        guard !currentWeekRecordIds.isEmpty else { return [] }
        return Set(items.compactMap { item in
            guard currentWeekRecordIds.contains(item.id) else { return nil }
            guard !item.wishlistEnabled else { return nil }
            guard isInCurrentWeek(item) else { return nil }
            return item.id
        })
    }


    // Compute the number of days until the start of the next week based on settings or viewModel fallback.
    func daysUntilNextWeekStart() -> Int {
        let weekStartDay = storedTempSettings.first?.week_start_day ?? viewModel.start_day
        return WeekdayUtility.daysUntilNextWeekStart(from: dateProvider.now(), weekStartDay: weekStartDay)
    }

    func daysUntilNextWeekStart(from date: Date) -> Int {
        let weekStartDay = storedTempSettings.first?.week_start_day ?? viewModel.start_day
        return WeekdayUtility.daysUntilNextWeekStart(from: date, weekStartDay: weekStartDay)
    }

    /// Sync week start day from settings and show previous-week sheet or weekly planning prompt if needed.
    func syncStartDayAndCheckPreviousWeekSheet() {
        guard let firstSettings = storedTempSettings.first else { return }
        guard !items.isEmpty else { return }
        viewModel.start_day = firstSettings.week_start_day
        continueSyncAfterPlanningStateCheck()
    }

    /// True when any weekly-flow modal/alert is currently on-screen.
    var isWeeklyFlowPresentationActive: Bool {
        showPlanningSheet || showLastWeekReviewPrompt || showLastWeekReviewView || showWeeklyChoicePrompt
    }

    /// True when ANY UIKit-presented modal (sheet, fullScreenCover, alert — from
    /// any screen) is up. Used to hold the foreground weekly-flow evaluation:
    /// presenting the recap over another modal defers or drops it while its
    /// "shown this week" flag is already latched. Generic on purpose — the list
    /// has a dozen sheets and enumerating them would rot.
    static var isAnyModalPresented: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .contains { $0.rootViewController?.presentedViewController != nil }
    }

    private static func lastWeekReviewPromptKey(for date: Date = DateProviderService.shared.now(), weekStartDay: String) -> String {
        "lastWeekReviewPromptShown_\(weeklyKeySuffix(for: date, weekStartDay: weekStartDay))"
    }

    private func currentWeeklyKeys(now: Date, weekStartDay: String) -> (
        weeklyFlowKey: String,
        lastWeekPromptKey: String,
        planningSheetShownKey: String
    ) {
        (
            weeklyFlowKey: Self.weeklyFlowProcessedKey(for: now, weekStartDay: weekStartDay),
            lastWeekPromptKey: Self.lastWeekReviewPromptKey(for: now, weekStartDay: weekStartDay),
            planningSheetShownKey: Self.weeklyPlanningSheetShownKey(for: now, weekStartDay: weekStartDay)
        )
    }

    /// Weekly prompt flow: shows last-week review first, then a "What do you wanna do this week?" choice.
    /// - Last-week review shown once per week (before anything else).
    /// - After review is dismissed, "What do you wanna do this week?" appears.
    /// - "Pick" → full 3-step planning flow. "Skip" → spends one of the week's two
    ///   chances (does NOT close the week).
    /// - If a plan already exists for this week (created last week), skip the planning choice
    ///   entirely and just show the last-week review, then mark done.
    /// - If user creates a plan from Pick, don't show again.
    /// - If user skips, or dismisses planning without a plan, show the choice prompt
    ///   once more on the NEXT app open (launch or return from background — see
    ///   `AppOpenSession`); never again within the same open.
    /// - Max 2 showings per week, one count per showing however it ends — Skip,
    ///   Pick-without-save, or the app closed with the prompt open all spend one
    ///   (final client rule, 2026-08-28). Pick → Save closes the week outright.
    /// - Never shows beyond day 5 (S+4).
    func continueSyncAfterPlanningStateCheck() {
        guard let firstSettings = storedTempSettings.first else {
            AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] guard: no settings, skipping")
            return
        }
        guard !items.isEmpty else {
            AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] guard: items empty, skipping")
            return
        }

        let weekStartDay = firstSettings.week_start_day
        let now = dateProvider.now()

        let forceShow = UserDefaults.standard.bool(forKey: Self.weeklyPromptForceShowPendingKey)

        let keys = currentWeeklyKeys(now: now, weekStartDay: weekStartDay)
        let weeklyFlowKey = keys.weeklyFlowKey
        let planningSheetShownKey = keys.planningSheetShownKey
        let lastWeekPromptKey = keys.lastWeekPromptKey

        let flowAlreadyProcessed = UserDefaults.standard.bool(forKey: weeklyFlowKey)
        let daysSinceWeekStart = WeekdayUtility.daysSinceWeekStart(from: now, weekStartDay: weekStartDay)
        let openCount = currentWeekWeeklyPromptOpenCount
        let alreadyShownLastWeekReview = UserDefaults.standard.bool(forKey: lastWeekPromptKey)
        let isTestMode = firstSettings.testModeEnabled && dateProvider.isVirtualDateOverrideEnabled
        let planExists = hasPlanRecordForCurrentWeek
        let plannedRecordCount = plannedItemRecords.count
        // First-active-week detection: lastActiveWeekRange only looks strictly
        // BEFORE the current week, so a brand-new account (first ideal created
        // this week) yields an empty previous week → the flow stays silent.
        let hasPreviousWeekIdeals = !getPreviousWeekItems().isEmpty

        AppLogger.debug(AppLogger.ui, """
            [WeeklyPrompt] continueSyncAfterPlanningStateCheck
              virtualDate=\(now)
              weekStartDay=\(weekStartDay)
              daysSinceWeekStart=\(daysSinceWeekStart)
              flowAlreadyProcessed=\(flowAlreadyProcessed)
              openCount=\(openCount)
              isTestMode=\(isTestMode)
              hasPlanRecordForCurrentWeek(raw)=\(hasPlanRecordForCurrentWeek)
              hasPlanRecordForCurrentWeek(effective)=\(planExists)
              plannedItemRecords.count=\(plannedRecordCount)
              alreadyShownLastWeekReview=\(alreadyShownLastWeekReview)
              hasPresentedThisOpen=\(hasPresentedWeeklyPlanningPromptThisSession) (open #\(AppOpenSession.currentId))
              hasPreviousWeekIdeals=\(hasPreviousWeekIdeals)
              weeklyFlowKey=\(weeklyFlowKey)
            """)

        // Use the decision engine for pure logic (testable independently).
        let input = WeeklyFlowDecisionEngine.Input(
            isWeeklyFlowPresentationActive: isWeeklyFlowPresentationActive,
            flowAlreadyProcessed: flowAlreadyProcessed,
            daysSinceWeekStart: daysSinceWeekStart,
            planExistsForCurrentWeek: planExists,
            openCount: openCount,
            alreadyShownLastWeekReview: alreadyShownLastWeekReview,
            hasPresentedPlanningThisSession: hasPresentedWeeklyPlanningPromptThisSession,
            forceShow: forceShow,
            hasPreviousWeekIdeals: hasPreviousWeekIdeals
        )
        let decision = WeeklyFlowDecisionEngine.decide(input)

        AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] Decision: \(decision)")

        switch decision {
        case .blocked(let reason):
            AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] BLOCKED: \(reason)")
            return

        case .showRecapOnly:
            UserDefaults.standard.set(true, forKey: planningSheetShownKey)
            UserDefaults.standard.set(false, forKey: Self.weeklyRecapForcedKey)
            markLastWeekReviewPromptShownThisWeek()
            showLastWeekReviewView = true

        case .markFlowComplete:
            UserDefaults.standard.set(true, forKey: planningSheetShownKey)
            UserDefaults.standard.set(true, forKey: weeklyFlowKey)

        case .showRecapThenChoice:
            UserDefaults.standard.set(forceShow, forKey: Self.weeklyRecapForcedKey)
            if forceShow { consumeWeeklyPromptForceShow() }
            markLastWeekReviewPromptShownThisWeek()
            showLastWeekReviewView = true

        case .showChoicePrompt:
            if forceShow { consumeWeeklyPromptForceShow() }
            presentWeeklyChoiceIfNeeded()
        }
    }

    /// Consumes the one-time force-show flag so the forced prompt appears only once.
    private func consumeWeeklyPromptForceShow() {
        UserDefaults.standard.set(false, forKey: Self.weeklyPromptForceShowPendingKey)
        AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] force-show consumed")
    }

    /// Test-only (Test Mode button): resets THIS week's weekly-prompt "already
    /// opened / processed" trackers, then force-triggers the flow to present
    /// immediately — bypassing the normal day/openCount/plan-exists gates.
    func triggerWeeklyPromptForTesting() {
        guard let firstSettings = storedTempSettings.first else { return }
        let weekStartDay = firstSettings.week_start_day
        let now = dateProvider.now()
        let keys = currentWeeklyKeys(now: now, weekStartDay: weekStartDay)
        let d = UserDefaults.standard
        // Reset the "weekly prompt opened / processed this week" trackers.
        d.removeObject(forKey: keys.weeklyFlowKey)
        d.removeObject(forKey: keys.planningSheetShownKey)
        d.removeObject(forKey: keys.lastWeekPromptKey)
        d.removeObject(forKey: Self.weeklyPromptOpenCountKey(for: now, weekStartDay: weekStartDay))
        // Allow re-presentation this open and force past the normal gates.
        Self.resetWeeklyPromptPresentedMarker()
        d.set(true, forKey: Self.weeklyPromptForceShowPendingKey)
        AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] manual TEST trigger: trackers reset + force-show armed")
        continueSyncAfterPlanningStateCheck()
    }

    /// Called when the last-week review sheet is dismissed.
    /// Marks the review as shown, then either closes the weekly flow (plan already existed)
    /// or presents the "What do you wanna do this week?" choice.
    func handleLastWeekReviewDismiss() {
        markLastWeekReviewPromptShownThisWeek()
        guard let firstSettings = storedTempSettings.first else { return }
        let weekStartDay = firstSettings.week_start_day
        let now = dateProvider.now()
        let planningSheetShownKey = Self.weeklyPlanningSheetShownKey(for: now, weekStartDay: weekStartDay)
        let weeklyFlowKey = Self.weeklyFlowProcessedKey(for: now, weekStartDay: weekStartDay)
        let planningSheetAlreadyShown = UserDefaults.standard.bool(forKey: planningSheetShownKey)

        let decision = WeeklyFlowDecisionEngine.decideAfterRecapDismiss(
            planningSheetAlreadyShown: planningSheetAlreadyShown,
            hasPresentedPlanningThisSession: hasPresentedWeeklyPlanningPromptThisSession
        )

        switch decision {
        case .markFlowComplete:
            AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] handleLastWeekReviewDismiss: plan existed, marking flow complete")
            UserDefaults.standard.set(true, forKey: weeklyFlowKey)
        case .showChoicePrompt:
            AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] handleLastWeekReviewDismiss: no pre-existing plan, presenting weekly choice")
            presentWeeklyChoiceIfNeeded()
        case .skipUntilNextSession:
            AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] handleLastWeekReviewDismiss: planning already presented this session, skipping")
        }
    }

    /// Called from `.onChange(of: plannedItemRecords)` when planned records arrive late.
    /// If the choice prompt is already showing but a plan actually exists, dismiss it
    /// and mark the weekly flow complete (plan was created last week).
    /// If the recap is still on screen instead, it stays up — only the planning-sheet
    /// marker is latched, so the recap's dismiss handler closes the flow rather than
    /// asking a question the existing plan has already answered.
    func reconcileWeeklyFlowIfPlanArrivedLate() {
        guard hasPlanRecordForCurrentWeek else { return }

        if showWeeklyChoicePrompt {
            showWeeklyChoicePrompt = false
            guard let firstSettings = storedTempSettings.first else { return }
            let weekStartDay = firstSettings.week_start_day
            let now = dateProvider.now()
            UserDefaults.standard.set(true, forKey: Self.weeklyFlowProcessedKey(for: now, weekStartDay: weekStartDay))
            UserDefaults.standard.set(true, forKey: Self.weeklyPlanningSheetShownKey(for: now, weekStartDay: weekStartDay))
            AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] reconcileWeeklyFlowIfPlanArrivedLate: plan arrived late, dismissed choice prompt and marked flow complete")
        } else if showLastWeekReviewView {
            // A forced recap bypasses the plan-exists gate on purpose to re-present
            // the choice, so latching it here would defeat the very reset that asked
            // for it — and the migration key is already burned, so it cannot retry.
            guard !UserDefaults.standard.bool(forKey: Self.weeklyRecapForcedKey) else { return }
            guard let firstSettings = storedTempSettings.first else { return }
            let weekStartDay = firstSettings.week_start_day
            let now = dateProvider.now()
            // Marker only: never touch showLastWeekReviewView, or the recap would
            // vanish from under the user a beat after it opened.
            UserDefaults.standard.set(true, forKey: Self.weeklyPlanningSheetShownKey(for: now, weekStartDay: weekStartDay))
            AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] reconcileWeeklyFlowIfPlanArrivedLate: plan arrived during recap, marked planning sheet shown")
        }
    }

    /// Show "What do you wanna do this week?" choice alert if no weekly flow is already active.
    /// Stamps "offered in this open" at PRESENTATION time (not only on Pick/Skip)
    /// so a second alive IdealListView instance evaluating right after cannot
    /// present a second copy and burn the week's other chance.
    ///
    /// The counter is spent HERE, once per showing (final client rule,
    /// 2026-08-28): every appearance costs one of the week's two — Skip,
    /// Pick-then-cancel, and closing the app with the prompt still open all
    /// count the same. Skip on showing #1 therefore leaves the count at 1 and
    /// the second showing comes on the next open; after two showings the week
    /// is quiet. Pick/Skip do NOT increment again — one showing, one count.
    /// A prompt that stays open across a background/return is still the same
    /// showing (Gate 1 blocks re-evaluation while it is up).
    func presentWeeklyChoiceIfNeeded() {
        guard !isWeeklyFlowPresentationActive else { return }
        hasPresentedWeeklyPlanningPromptThisSession = true
        incrementWeeklyPromptOpenCount()
        showWeeklyChoicePrompt = true
    }

    /// Handle "Pick" from the weekly choice alert — show the full planning sheet flow.
    func handleWeeklyChoicePick() {
        AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] CHOICE: Pick → showing planning sheet (openCount=\(currentWeekWeeklyPromptOpenCount))")
        planningViewModel.reset()
        isWeeklyPromptPlanningFlow = true
        hasPresentedWeeklyPlanningPromptThisSession = true
        weeklyPromptWithExistingPlan = false
        showOnlyMissedAnythingStep = false
        // No increment: this showing was already counted when it was presented.
        showPlanningSheet = true
    }

    /// Handle "Skip For Now" from the weekly choice — spend ONE of the week's two
    /// chances, do not close the week.
    ///
    /// Client rule: the automatic prompt is offered on the first and second app
    /// open of the week. This used to call `markWeeklyFlowComplete()`, which
    /// latched `weeklyFlowProcessed_<week>` and made the engine's `openCount < 2`
    /// second chance unreachable after a Skip (only Pick → cancel could reach
    /// it). Now Skip bumps the same per-week open count Pick uses (so the second
    /// showing gets the "Forgot to add plans…" copy) and stamps the current app
    /// open, so nothing re-offers until the app is closed and reopened. After
    /// the second answer, `openCount == 2` blocks the rest of the week.
    func handleWeeklyChoiceSkip() {
        // Already counted at presentation; Skip just closes the showing.
        hasPresentedWeeklyPlanningPromptThisSession = true
        AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] CHOICE: Skip (showings=\(currentWeekWeeklyPromptOpenCount) of 2)")
    }

    /// Mark the weekly flow as fully processed for this week.
    func markWeeklyFlowComplete() {
        guard let firstSettings = storedTempSettings.first else { return }
        let weekStartDay = firstSettings.week_start_day
        let now = dateProvider.now()
        let weeklyFlowKey = Self.weeklyFlowProcessedKey(for: now, weekStartDay: weekStartDay)
        UserDefaults.standard.set(true, forKey: weeklyFlowKey)
    }

    /// True only when at least one current-week plan record ID has a matching non-wishlist ideal in current week.
    /// This prevents stale/unmatched records from suppressing the Again? flow.
    var hasPlanRecordForCurrentWeek: Bool {
        !validCurrentWeekPlanRecordIds.isEmpty
    }

    /// UserDefaults key for "last week review prompt shown this week" (so we only prompt once per week).
    static func lastWeekReviewPromptKey(weekStartDay: String) -> String {
        lastWeekReviewPromptKey(for: DateProviderService.shared.now(), weekStartDay: weekStartDay)
    }

    /// Mark that the last week review screen was shown/dismissed this week so it won't show again.
    func markLastWeekReviewPromptShownThisWeek() {
        let weekStartDay = storedTempSettings.first?.week_start_day ?? viewModel.start_day
        let now = dateProvider.now()
        let promptKey = Self.lastWeekReviewPromptKey(for: now, weekStartDay: weekStartDay)
        UserDefaults.standard.set(true, forKey: promptKey)
    }




    // Get current week's active ideals for planning (ideals with startDate set to this week).
    // All current-week non-wishlist ideals are shown — no already-planned or duplicate-key filtering.
    var currentWeekIdeals: [Ideal] {
        guard let firstSettings = storedTempSettings.first else { return [] }
        let weekStartDay = firstSettings.week_start_day
        let currentWeekStartTimestamp = WeekdayUtility.weekStart(weekStartDay: weekStartDay).timeIntervalSince1970
        let nextWeekStartTimestamp = WeekdayUtility.nextWeekRange(weekStartDay: weekStartDay).start.timeIntervalSince1970

        return items.filter { item in
            guard !item.wishlistEnabled else { return false }
            guard item.startDate > 0 else { return false }
            return item.startDate >= currentWeekStartTimestamp && item.startDate < nextWeekStartTimestamp
        }
    }

    // Wishlist ideals for planning. If last week's plan exists for current week, hide wishlist IDs already present in that planned-ID record set.
    var wishlistIdealsForPlanning: [Ideal] {
        let plannedKeys = nextWeekPlannedKeys
        let filteredById: [Ideal]
        if weeklyPromptWithExistingPlan {
            let excludedIds = plannedRecordIdsForCurrentWeek
            filteredById = items.filter { $0.wishlistEnabled && !excludedIds.contains($0.id) }
        } else {
            filteredById = items.filter { $0.wishlistEnabled }
        }
        return filteredById.filter { item in
            guard let key = duplicateKey(for: item) else { return true }
            return !plannedKeys.contains(key)
        }
    }

    /// Previous-week ideals shown in the weekly start prompt, excluding keys already present this week.
    var previousWeekIdealsForWeeklyPrompt: [Ideal] {
        let existingKeys = currentWeekExistingKeys
        guard !existingKeys.isEmpty else { return getPreviousWeekItems() }
        return getPreviousWeekItems().filter { item in
            guard let key = duplicateKey(for: item) else { return true }
            return !existingKeys.contains(key)
        }
    }


    /// Wishlist items not yet planned for current week (S). Used so we only show the Next? step in the weekly prompt when this list is non-empty.
    var wishlistIdealsNotPlannedForCurrentWeek: [Ideal] {
        let plannedKeysForS = Set(items.filter { plannedRecordIdsForCurrentWeek.contains($0.id) }.compactMap { duplicateKey(for: $0) })
        guard !plannedKeysForS.isEmpty else {
            return items.filter { $0.wishlistEnabled }
        }
        return items.filter { item in
            guard item.wishlistEnabled else { return false }
            guard let key = duplicateKey(for: item) else { return true }
            return !plannedKeysForS.contains(key)
        }
    }

    // Get items from the last *active* week (most recent past week that had at least one ideal).
    // Skips empty weeks so the recap/badge stays meaningful even if the user hasn't opened the
    // app for a while. Wishlist items (startDate == 0) are excluded.
    func getPreviousWeekItems() -> [Ideal] {
        guard let firstSettings = storedTempSettings.first else { return [] }
        let weekStartDay = firstSettings.week_start_day

        let nonWishlistStartDates = items
            .filter { !$0.wishlistEnabled }
            .map { $0.startDate }

        guard let activeRange = WeekdayUtility.lastActiveWeekRange(
            fromStartDates: nonWishlistStartDates,
            weekStartDay: weekStartDay
        ) else {
            return []
        }

        let startTs = activeRange.start.timeIntervalSince1970
        let endTs = activeRange.end.timeIntervalSince1970

        return items.filter { item in
            guard item.startDate > 0, !item.wishlistEnabled else { return false }
            return item.startDate >= startTs && item.startDate <= endTs
        }
    }

}
