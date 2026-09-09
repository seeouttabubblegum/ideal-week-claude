//
//  PlanningSheetView.swift
//  The Ideal Week
//
//  Created on 1/15/25.
//

import SwiftUI
import FirebaseAuth
import UIKit

struct PlanningSheetView: View {
    @ObservedObject var viewModel: PlanningSheetViewModel
    let ideals: [Ideal]
    let wishlistIdeals: [Ideal]
    /// Ideals already present in the target week (current week for weekly prompt, next week for Next? tab).
    /// Used to validate that all categories are covered before saving in Missed Anything?.
    let existingTargetWeekIdeals: [Ideal]
    let accentColor: Color
    let weekStartDay: String
    @Binding var isPresented: Bool
    let unlockedWithPin: Bool // Whether planning was unlocked with PIN
    /// When true (weekly prompt): no create wishlist option, skip to createNewIdeals if no wishlist, always show third screen. When false (Next? tab): current behavior.
    let isWeeklyPrompt: Bool
    /// Next? tab opened on an EMPTY current week: the sheet keeps its Next?
    /// shape (screens, copy, wishlist-create button) but plans the CURRENT week
    /// — day picker shows this week's remaining days and the save writes
    /// current-week ideals instead of a next-week plan. Deliberately separate
    /// from `isWeeklyPrompt`, which also drives routing and labels.
    let targetsCurrentWeek: Bool
    /// When true, Next? tab opened to add more to existing next-week plan; save must not run plan-table cleanup.
    /// When true (weekly prompt + plan already from Next?): show only unselected Again? list if any, then Missed Anything? (skip wishlist).
    let weeklyPromptWithExistingPlan: Bool
    /// When true, sheet shows only Missed Anything? step (no Again?, no Wishlist); Back is hidden, only Cancel.
    let showOnlyMissedAnythingStep: Bool
    /// Parent-held flag: user already answered "Why plan early?" in a previous sheet open this session; skip reason screen.
    let reasonAlreadyProvidedFromParent: Bool
    /// Callback when user submits reason (so parent can persist and skip reason on next open).
    let onReasonProvided: () -> Void
    /// Called when Save succeeds, before dismissing, so parent can throttle re-opening (e.g. after items update from Firestore).
    let onDismissedAfterSave: () -> Void
    @State private var showNewWishlistItemSheet = false
    @State private var hasAppeared = false // Track if view has appeared to prevent reset
    @State private var showPlanningAlert = false
    @State private var planningAlertTitle = ""
    @State private var planningAlertMessage = ""
    @State private var dismissAfterPlanningAlert = false
    /// Average review score per ideal (raw 0-100 scale) — fetched from `reviewScores` subcollection on appear.
    @State private var reviewScoreAveragesByIdeal: [String: Double] = [:]
    /// Category-coverage warning state.
    @State private var showCategoryCoverageWarning = false
    @State private var missingCategoryNames: [String] = []
    @State private var pendingMissedAnythingSave: (() -> Void)? = nil
    /// Categories that had no ideal when the user landed on Missed Anything?.
    /// Empty means they arrived fully covered, so the notice never appears; the
    /// notice itself tracks what is STILL missing as drafts are added.
    @State private var missedOnArrival: [String] = []
    @FocusState private var isPlanningReasonFieldFocused: Bool

    init(viewModel: PlanningSheetViewModel, ideals: [Ideal], wishlistIdeals: [Ideal], existingTargetWeekIdeals: [Ideal] = [], accentColor: Color, weekStartDay: String, isPresented: Binding<Bool>, unlockedWithPin: Bool, isWeeklyPrompt: Bool = false, targetsCurrentWeek: Bool = false, weeklyPromptWithExistingPlan: Bool = false, showOnlyMissedAnythingStep: Bool = false, reasonAlreadyProvidedFromParent: Bool = false, onReasonProvided: @escaping () -> Void = {}, onDismissedAfterSave: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.ideals = ideals
        self.wishlistIdeals = wishlistIdeals
        self.existingTargetWeekIdeals = existingTargetWeekIdeals
        self.accentColor = accentColor
        self.weekStartDay = weekStartDay
        self._isPresented = isPresented
        self.unlockedWithPin = unlockedWithPin
        self.isWeeklyPrompt = isWeeklyPrompt
        self.targetsCurrentWeek = targetsCurrentWeek
        self.weeklyPromptWithExistingPlan = weeklyPromptWithExistingPlan
        self.showOnlyMissedAnythingStep = showOnlyMissedAnythingStep
        self.reasonAlreadyProvidedFromParent = reasonAlreadyProvidedFromParent
        self.onReasonProvided = onReasonProvided
        self.onDismissedAfterSave = onDismissedAfterSave

        // Don't set initial screen in init - let onAppear handle it
        // This prevents async init from overriding user navigation
    }

    // MARK: - Stats / partition helpers (Again? success vs rest)

    private func targetInt(_ ideal: Ideal) -> Int {
        if ideal.targetCount == "6+" { return 6 }
        return max(1, Int(ideal.targetCount) ?? 1)
    }

    private func donePercent(_ ideal: Ideal) -> Double {
        let target = targetInt(ideal)
        guard target > 0 else { return 0 }
        return Double(ideal.doneCount) / Double(target)
    }

    private func isSuccessful(_ ideal: Ideal) -> Bool {
        ideal.doneCount >= targetInt(ideal)
    }

    private var visibleAgainIdeals: [Ideal] {
        ideals.filter { !viewModel.movedToLaterIds.contains($0.id) }
    }

    private var successfulAgainIdeals: [Ideal] {
        visibleAgainIdeals.filter(isSuccessful).sorted { donePercent($0) > donePercent($1) }
    }

    private var restAgainIdeals: [Ideal] {
        visibleAgainIdeals.filter { !isSuccessful($0) }.sorted { donePercent($0) > donePercent($1) }
    }

    private var sortedAgainIdeals: [Ideal] {
        switch viewModel.currentScreen {
        case .selectionSuccess: return successfulAgainIdeals
        case .selection: return restAgainIdeals
        default: return visibleAgainIdeals.sorted { donePercent($0) > donePercent($1) }
        }
    }

    private func formatAverageScore(_ raw: Double) -> String {
        let display = ReviewScoreScale.display(fromStored: raw)
        return "\(ReviewScoreScale.formattedDisplay(display))/7"
    }

    @ViewBuilder
    private func idealStatsLine(for ideal: Ideal) -> some View {
        let avg = reviewScoreAveragesByIdeal[ideal.id]
        if let avg {
            Text("\(ideal.doneCount) out of \(ideal.targetCount) did and scored \(formatAverageScore(avg))")
                .font(.manrope(12))
                .foregroundColor(LCColor.textMuted)
        } else {
            Text("\(ideal.doneCount) out of \(ideal.targetCount) did")
                .font(.manrope(12))
                .foregroundColor(LCColor.textMuted)
        }
    }

    private var againContentTitle: String? {
        switch viewModel.currentScreen {
        case .selectionSuccess: return "Do these pieces fit?"
        case .selection: return "Do these fit or should be modified or move to later?"
        default: return nil
        }
    }

    /// Route from selectionSuccess → selection (rest) if non-empty, else fall through to wishlist/createNew.
    private func continueFromSelectionSuccess() {
        if !restAgainIdeals.isEmpty {
            viewModel.currentScreen = .selection
        } else {
            routeFromSelectionToNextAvailableScreen()
        }
    }

    /// Initial routing for weekly prompt's Again? screens.
    private func routeWeeklyPromptInitial() {
        if !successfulAgainIdeals.isEmpty {
            viewModel.currentScreen = .selectionSuccess
        } else if !restAgainIdeals.isEmpty {
            viewModel.currentScreen = .selection
        } else {
            routeFromSelectionToNextAvailableScreen()
        }
    }

    private func fetchReviewScoreAverages() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let idealIds = ideals.map(\.id)
        guard !idealIds.isEmpty else { return }
        Task {
            let fetched = await ReviewScoreRepository.fetchScoresByIdeal(userId: userId, idealIds: idealIds)
            var averages: [String: Double] = [:]
            for (idealId, scores) in fetched where !scores.isEmpty {
                let total = scores.reduce(0) { $0 + $1.score }
                averages[idealId] = Double(total) / Double(scores.count)
            }
            await MainActor.run {
                self.reviewScoreAveragesByIdeal = averages
            }
        }
    }

    /// Categories that will have no ideal in the target week if save proceeds as-is.
    /// Combines existing target-week categories + selected Again? + selected wishlist + new drafts.
    private func missingCategoriesIfSavedNow() -> [String] {
        let allCategoryNames = Category.allCases.map(\.rawValue)
        var present = Set(existingTargetWeekIdeals.map(\.category))
        for ideal in ideals where viewModel.selectedIdealIds.contains(ideal.id) {
            present.insert(viewModel.getPlannedCategory(for: ideal.id, defaultCategory: ideal.category))
        }
        for ideal in wishlistIdeals where viewModel.selectedWishlistIdealIds.contains(ideal.id) {
            present.insert(viewModel.wishlistCategories[ideal.id] ?? ideal.category)
        }
        for draft in viewModel.newIdealsToCreate where !draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
            present.insert(draft.category)
        }
        return allCategoryNames.filter { !present.contains($0) }
    }

    private var sortedNextWishlistIdeals: [Ideal] {
        wishlistIdeals.sorted { ($0.createdDate, $0.id) > ($1.createdDate, $1.id) }
    }
    
    /// True when everything this sheet saves belongs to the CURRENT week — the
    /// weekly prompt, or the Next? tab's empty-week fallback. Drives the day
    /// picker and the save's target week; nothing else.
    private var plansCurrentWeek: Bool { isWeeklyPrompt || targetsCurrentWeek }

    /// "Missed Anything?" CTA copy — names the week this sheet actually saves to.
    private var addAnotherIdealLabel: String {
        PlanningSheetCopy.addAnotherIdealLabel(isWeeklyPrompt: isWeeklyPrompt,
                                               targetsCurrentWeek: targetsCurrentWeek)
    }

    /// Week days for the schedule day-picker, computed once per render.
    private var scheduleDays: [DayInfo] {
        plansCurrentWeek
            ? getCurrentWeekRemainingDays(weekStartDay: weekStartDay)
            : getNextWeekDays(weekStartDay: weekStartDay)
    }
    
    // Check if we're in the planning window (within 2 days before next week starts)
    private func isInPlanningWindow() -> Bool {
        WeekdayUtility.isWithinPlanningWindow(weekStartDay: weekStartDay)
    }
    
    // Get remaining days of current week (today → end of week)
    func getCurrentWeekRemainingDays(weekStartDay: String) -> [DayInfo] {
        let calendar = Calendar.current
        let now = DateProviderService.shared.now()
        let today = calendar.startOfDay(for: now)
        let userCalendar = WeekdayUtility.calendar(firstWeekday: weekStartDay)
        let weekStart = userCalendar.date(from: userCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let weekStartDayStart = calendar.startOfDay(for: weekStart)
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStartDayStart) else { return [] }
        let weekEndDayStart = calendar.startOfDay(for: weekEnd)
        let dayAbbreviations = WeekdayUtility.dayAbbreviations
        var days: [DayInfo] = []
        var currentDate = today
        while currentDate <= weekEndDayStart {
            let weekday = calendar.component(.weekday, from: currentDate)
            let dayOfMonth = calendar.component(.day, from: currentDate)
            days.append(DayInfo(weekday: weekday, abbreviation: dayAbbreviations[weekday - 1], dayNumber: "\(dayOfMonth)"))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = calendar.startOfDay(for: nextDate)
        }
        return days
    }

    // Get all days of next week
    func getNextWeekDays(weekStartDay: String) -> [DayInfo] {
        let calendar = Calendar.current
        let nextWeekRange = WeekdayUtility.nextWeekRange(weekStartDay: weekStartDay)
        let nextWeekStartDayStart = nextWeekRange.start
        let nextWeekEndDayStart = nextWeekRange.end.startOfDay
        
        // Day abbreviations
        let dayAbbreviations = WeekdayUtility.dayAbbreviations
        
        var days: [DayInfo] = []
        
        // Iterate through all days of next week
        var currentDate = nextWeekStartDayStart
        while currentDate <= nextWeekEndDayStart {
            let weekday = calendar.component(.weekday, from: currentDate)
            let dayOfMonth = calendar.component(.day, from: currentDate)
            
            days.append(DayInfo(
                weekday: weekday,
                abbreviation: dayAbbreviations[weekday - 1],
                dayNumber: "\(dayOfMonth)"
            ))
            
            // Move to next day
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = calendar.startOfDay(for: nextDate)
        }
        
        return days
    }

    private func routeFromSelectionToNextAvailableScreen() {
        // Next? tab always includes a wishlist creation option, so route there even when empty.
        if !isWeeklyPrompt {
            viewModel.currentScreen = .wishlist
        } else {
            if !wishlistIdeals.isEmpty {
                viewModel.currentScreen = .wishlist
            } else {
                viewModel.currentScreen = .createNewIdeals
                if viewModel.newIdealsToCreate.isEmpty {
                    viewModel.addNewIdealDraft()
                }
            }
        }
    }
    
    /// Format current week's schedule (from ideal) as read-only label, e.g.
    /// "This week: Mon, Wed at 9:00 AM • Fri at 6:00 PM" (one segment per reminder group).
    private func currentWeekScheduleLabel(ideal: Ideal) -> some View {
        let dayAbbreviations = WeekdayUtility.dayAbbreviations
        let segments = ideal.effectiveReminderSchedules.map { group -> String in
            let daysText = group.days.sorted().map { dayAbbreviations[$0 - 1] }.joined(separator: ", ")
            let hour = Int(group.time) / 3600
            let minute = (Int(group.time) % 3600) / 60
            let displayHour = hour % 12 == 0 ? 12 : hour % 12
            let ampm = hour < 12 ? "AM" : "PM"
            return String(format: "%@ at %d:%02d %@", daysText, displayHour, minute, ampm)
        }
        return Text("This week: \(segments.joined(separator: " • "))")
            .font(.manrope(12))
            .foregroundColor(LCColor.textMuted)
    }
    
    var body: some View {
        let currentScreen = viewModel.currentScreen
        
        return NavigationStack {
            Group {
                switch currentScreen {
                    case .selectionSuccess:
                        selectionScreen
                    case .selection:
                        selectionScreen
                    case .wishlist:
                        wishlistScreen
                    case .reason:
                        reasonScreen
                    case .createNewIdeals:
                        createNewIdealsScreen
                }
            }
            // Don't use .id(currentScreen) here: it recreates the view when screen changes and can retrigger onAppear, showing the reason screen again.
            // Neumorphic redesign: every screen draws its own HH Samuel header, so the system nav bar is hidden.
            .toolbar(.hidden, for: .navigationBar)
            .background(LCColor.surface.ignoresSafeArea())
        }
        .alert(planningAlertTitle, isPresented: $showPlanningAlert) {
            Button("OK") {
                if dismissAfterPlanningAlert {
                    dismissAfterPlanningAlert = false
                    onDismissedAfterSave()
                    isPresented = false
                }
            }
        } message: {
            Text(planningAlertMessage)
        }
        .alert("Save this week's plan?", isPresented: $showCategoryCoverageWarning) {
            // Same actions as before — only the wording is clearer so users know
            // that "Save Now" is what actually saves, and going back to add more
            // does NOT save on its own.
            Button("Save Now") {
                let action = pendingMissedAnythingSave
                pendingMissedAnythingSave = nil
                action?()
            }
            Button("Keep Adding", role: .cancel) {
                pendingMissedAnythingSave = nil
            }
        } message: {
            Text("No ideal yet for: \(missingCategoryNames.joined(separator: ", ")).\n\nTap “Save Now” to save this week's plan as it is. “Keep Adding” just goes back to the list — nothing is saved until you tap Save Now.")
        }
        .onChange(of: viewModel.currentScreen) { oldValue, newValue in
            viewModel.recordScreenShown(newValue)
            AppLogger.debug(AppLogger.ui, "[PlanningSheetView] screen changed \(oldValue) -> \(newValue)")
        }
        .onAppear {
            // Only set initial screen on FIRST appearance to prevent resetting user navigation
            guard !hasAppeared else { return }
            hasAppeared = true

            fetchReviewScoreAverages()

            // Defer to avoid "Publishing changes from within view updates" error
            DispatchQueue.main.async {
                // Only Missed Anything? step (plan exists, not in planning window): start at createNewIdeals, no Back.
                if showOnlyMissedAnythingStep {
                    viewModel.currentScreen = .createNewIdeals
                    if viewModel.newIdealsToCreate.isEmpty {
                        viewModel.addNewIdealDraft()
                    }
                    viewModel.recordScreenShown(viewModel.currentScreen)
                    return
                }
                // Weekly prompt with existing plan from Next? tab: exclude Again? list completely. Show wishlist step only if there are wishlist items not yet in the plan, then Missed Anything?
                if weeklyPromptWithExistingPlan {
                    routeFromSelectionToNextAvailableScreen()
                    viewModel.recordScreenShown(viewModel.currentScreen)
                    return
                }
                if viewModel.currentScreen == .selection {
                    // Next? tab unlocked with PIN: show "Why plan early?" once only (never if they already continued from it or answered in a previous sheet open)
                    if unlockedWithPin && !viewModel.reasonAlreadyProvided && !reasonAlreadyProvidedFromParent {
                        viewModel.currentScreen = .reason
                        viewModel.recordScreenShown(viewModel.currentScreen)
                        return
                    }
                    // Both weekly prompt and Next? tab: route to Priority (success) first, then More (rest), then Next/Missed.
                    routeWeeklyPromptInitial()
                    viewModel.recordScreenShown(viewModel.currentScreen)
                    return
                }
                // Stayed on Again? (selection) – user will actually see this screen
                viewModel.recordScreenShown(viewModel.currentScreen)
            }
        }
    }

    private func showSkippedDuplicatesAlert(_ skipped: [String], dismissOnAcknowledge: Bool = true) {
        guard !skipped.isEmpty else { return }
        var seen: Set<String> = []
        let uniqueSkipped = skipped.filter { seen.insert($0).inserted }
        let lines = uniqueSkipped.map { "- \($0)" }.joined(separator: "\n")
        planningAlertTitle = "Some ideals were not added"
        planningAlertMessage = "These already exist and were skipped:\n\n\(lines)"
        dismissAfterPlanningAlert = dismissOnAcknowledge
        showPlanningAlert = true
    }

    private func showValidationDuplicatesAlert(_ duplicates: [String]) {
        guard !duplicates.isEmpty else { return }
        var seen: Set<String> = []
        let uniqueDuplicates = duplicates.filter { seen.insert($0).inserted }
        let lines = uniqueDuplicates.map { "- \($0)" }.joined(separator: "\n")
        planningAlertTitle = "Fix duplicates before saving"
        planningAlertMessage = "You are adding multiple ideals with the same title and category:\n\n\(lines)\n\nPlease edit, remove, or change category so each is unique."
        dismissAfterPlanningAlert = false
        showPlanningAlert = true
    }
    
    @ViewBuilder
    private var selectionScreen: some View {
        VStack(spacing: 0) {
            sheetHeader(viewModel.currentScreen == .selectionSuccess ? "Priority" : "More") {
                if viewModel.currentScreen == .selection && !successfulAgainIdeals.isEmpty {
                    NeuBackCircleButton {
                        withAnimation { viewModel.currentScreen = .selectionSuccess }
                    }
                } else {
                    NeuCloseButton { isPresented = false }
                        .accessibilityLabel("Cancel")
                }
            } trailing: {
                EmptyView()
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Content title for weekly prompt; subtitle for Next? tab.
                    if let title = againContentTitle {
                        Text(title)
                            .font(.hhSamuel(23))
                            .textCase(.uppercase)
                            .accentText(.pink)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                    } else {
                        Text("Pick ideals from this week to be carried over to the next week")
                            .font(.manrope(14, .medium))
                            .foregroundColor(LCColor.textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }

                    ForEach(sortedAgainIdeals) { ideal in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                Button(action: {
                                    viewModel.toggleIdeal(ideal.id)
                                }) {
                                    HStack(spacing: 12) {
                                        // Category icon (reflects chosen category when selected)
                                        let displayCategory = viewModel.selectedIdealIds.contains(ideal.id)
                                            ? viewModel.getPlannedCategory(for: ideal.id, defaultCategory: ideal.category)
                                            : ideal.category
                                        if let category = Category.allCases.first(where: { $0.rawValue == displayCategory }) {
                                            Image(category.lcCategoryIconV2())
                                                .resizable()
                                                .renderingMode(.template)
                                                .scaledToFit()
                                                .accentText(.blue)
                                                .frame(width: 24, height: 24)
                                        }

                                        // Ideal name + stats
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ideal.title)
                                                .font(.idealTitle(21))
                                                .foregroundColor(LCColor.ink)
                                                .imprinted()
                                            idealStatsLine(for: ideal)
                                        }

                                        Spacer(minLength: 8)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Heart select — heart-shaped raised, filled pink when selected
                                NeuHeartSelectButton(isSelected: viewModel.selectedIdealIds.contains(ideal.id)) {
                                    viewModel.toggleIdeal(ideal.id)
                                }
                            }
                            .padding(.vertical, 15)

                            // Move to later (weekly prompt — second Again? screen only)
                            if isWeeklyPrompt && viewModel.currentScreen == .selection {
                                Button(action: {
                                    HapticFeedback.impact()
                                    viewModel.moveToLater(ideal: ideal) { _ in }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("Move to later")
                                            .font(.manrope(13, .semibold))
                                    }
                                    .accentText(.pink)
                                    .padding(.leading, 36)
                                    .padding(.bottom, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            // Planned target input and schedule (only show if ideal is selected)
                            if viewModel.selectedIdealIds.contains(ideal.id) {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Category picker (Again? list – weekly prompt and Next? tab) — 56pt row
                                    categoryMenuRow(selection: Binding(
                                        get: { viewModel.getPlannedCategory(for: ideal.id, defaultCategory: ideal.category) },
                                        set: { viewModel.setPlannedCategory(for: ideal.id, value: $0) }
                                    ))

                                    // How Often counter — sunken number pill between chevrons, 56pt row
                                    howOftenRow(value: Binding(
                                        get: { viewModel.getPlannedTargetInt(for: ideal.id) },
                                        set: { newValue in
                                            HapticFeedback.impact()
                                            withAnimation {
                                                viewModel.setPlannedTargetInt(for: ideal.id, value: newValue)
                                            }
                                        }
                                    ))

                                    // Schedule reminder section (only show if in planning window)
                                    if isInPlanningWindow() {
                                        VStack(alignment: .leading, spacing: 0) {
                                            scheduleToggleRow(isOn: Binding(
                                                get: { viewModel.getPlannedSchedule(for: ideal.id).setReminder },
                                                set: { newValue in
                                                    viewModel.setPlannedReminderEnabled(for: ideal.id, enabled: newValue, prefillFrom: ideal)
                                                }
                                            ))

                                            // When toggle is off, show current week's schedule (read-only)
                                            if !viewModel.getPlannedSchedule(for: ideal.id).setReminder && !ideal.effectiveReminderSchedules.isEmpty {
                                                currentWeekScheduleLabel(ideal: ideal)
                                                    .frame(minHeight: 40, alignment: .leading)
                                            }

                                            if viewModel.getPlannedSchedule(for: ideal.id).setReminder {
                                                // Day selector - current week for weekly prompt, next week for Next? tab planning
                                                PlannedReminderGroupsEditor(
                                                    groups: viewModel.getPlannedSchedule(for: ideal.id).groups,
                                                    accentColor: accentColor,
                                                    days: scheduleDays,
                                                    dayTitle: plansCurrentWeek ? "Select Days (Current Week)" : "Select Days (Next Week)",
                                                    onToggleDay: { groupIndex, weekday in
                                                        viewModel.togglePlannedScheduledDay(for: ideal.id, groupIndex: groupIndex, weekday: weekday)
                                                    },
                                                    onSetTime: { groupIndex, time in
                                                        viewModel.setPlannedReminderTime(for: ideal.id, groupIndex: groupIndex, time: time)
                                                    },
                                                    onAddGroup: { viewModel.addPlannedReminderGroup(for: ideal.id) },
                                                    onRemoveGroup: { groupIndex in
                                                        viewModel.removePlannedReminderGroup(for: ideal.id, groupIndex: groupIndex)
                                                    }
                                                )
                                                .padding(.top, 4)
                                            }
                                        }
                                    }
                                }
                                .padding(.leading, 32)
                                .padding(.bottom, 8)
                                .onAppear {
                                    // Initialize with existing plannedTarget or targetCount if not already set
                                    if viewModel.getPlannedTarget(for: ideal.id) == nil {
                                        let initialValue = ideal.plannedTarget ?? ideal.targetCount
                                        // Convert to int, handling "6+" case and defaulting to 1 if invalid
                                        let initialInt: Int
                                        if initialValue == "6+" {
                                            initialInt = 6
                                        } else {
                                            initialInt = Int(initialValue) ?? 1
                                        }
                                        viewModel.setPlannedTargetInt(for: ideal.id, value: max(1, initialInt))
                                    }
                                }
                            }

                            NeuFeatheredDivider()
                        }
                        .padding(.horizontal, LCMetrics.screenMargin)
                    }
                }
                .padding(.bottom, 12)
            }

            // Continue button - kept outside the scroll content to ensure it's tappable
            VStack {
                Button(action: {
                    HapticFeedback.impact()
                    if viewModel.currentScreen == .selectionSuccess {
                        // From Priority (success) → More (rest) if any, else Next/Missed
                        continueFromSelectionSuccess()
                    } else if weeklyPromptWithExistingPlan || (isWeeklyPrompt && wishlistIdeals.isEmpty) {
                        viewModel.currentScreen = .createNewIdeals
                        if viewModel.newIdealsToCreate.isEmpty {
                            viewModel.addNewIdealDraft()
                        }
                    } else {
                        viewModel.currentScreen = .wishlist
                    }
                }) {
                    Text("Continue")
                }
                .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink, font: .manrope(18, .heavy)))
            }
            .padding()
        }
    }
    
    private var wishlistScreen: some View {
        VStack(spacing: 0) {
            sheetHeader("Next") {
                if weeklyPromptWithExistingPlan {
                    NeuCloseButton { isPresented = false }
                        .accessibilityLabel("Cancel")
                } else {
                    NeuBackCircleButton {
                        withAnimation {
                            if !restAgainIdeals.isEmpty {
                                viewModel.currentScreen = .selection
                            } else if !successfulAgainIdeals.isEmpty {
                                viewModel.currentScreen = .selectionSuccess
                            } else {
                                isPresented = false
                            }
                        }
                    }
                }
            } trailing: {
                // Cancel (skipped when the leading control already cancels)
                if !weeklyPromptWithExistingPlan {
                    NeuCloseButton { isPresented = false }
                        .accessibilityLabel("Cancel")
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text("Any of these pieces fit this week?")
                        .font(.hhSamuel(23))
                        .textCase(.uppercase)
                        .accentText(.pink)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                    if wishlistIdeals.isEmpty {
                        Text("No items in your wishlist")
                            .font(.manrope(14, .medium))
                            .foregroundColor(LCColor.textSecondary)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(sortedNextWishlistIdeals) { ideal in
                            wishlistItemRow(ideal: ideal)
                                .padding(.horizontal, LCMetrics.screenMargin)
                        }
                    }

                    // Next? tab only: show create wishlist option. Weekly prompt does not.
                    if !isWeeklyPrompt {
                        Button(action: {
                            showNewWishlistItemSheet = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .heavy))
                                    .accentText(.pink)
                                    .frame(width: 30, height: 30)
                                    .neuRaisedCircle(cssOffset: LCNeumorphism.raisedOffsetSmall,
                                                     cssBlur: LCNeumorphism.raisedBlurSmall)
                                Text("Create New Wishlist Item")
                                    .font(.manrope(16, .heavy))
                                    .accentText(.pink)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.bottom, 12)
            }
            .id(wishlistIdeals.count) // Refresh when wishlist items change

            // Continue button: both weekly prompt and Next? tab go to Missed Anything? (create new ideals), then reason or save
            Button(action: {
                withAnimation {
                    viewModel.currentScreen = .createNewIdeals
                    if viewModel.newIdealsToCreate.isEmpty {
                        viewModel.addNewIdealDraft()
                    }
                }
            }) {
                Text("Continue")
            }
            .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink, font: .manrope(18, .heavy)))
            .disabled(!viewModel.canContinueFromWishlist())
            .opacity(viewModel.canContinueFromWishlist() ? 1 : 0.5)
            .padding()
        }
        .sheet(isPresented: $showNewWishlistItemSheet) {
            NewIdealView(newItemPresented: $showNewWishlistItemSheet, category: nil, wishlist: true)
        }
    }
    
    private var createNewIdealsScreen: some View {
        VStack(spacing: 0) {
            sheetHeader("Missed Anything?") {
                if !showOnlyMissedAnythingStep {
                    // Back — rendered as the standard close-style button (handoff 1f)
                    NeuCloseButton {
                        withAnimation {
                            if weeklyPromptWithExistingPlan {
                                if wishlistIdeals.isEmpty {
                                    isPresented = false
                                } else {
                                    viewModel.currentScreen = .wishlist
                                }
                            } else if !isWeeklyPrompt {
                                // Next? tab: wishlist screen always shown (has Create New button)
                                viewModel.currentScreen = .wishlist
                            } else if !wishlistIdeals.isEmpty {
                                viewModel.currentScreen = .wishlist
                            } else if !restAgainIdeals.isEmpty {
                                viewModel.currentScreen = .selection
                            } else if !successfulAgainIdeals.isEmpty {
                                viewModel.currentScreen = .selectionSuccess
                            } else {
                                isPresented = false
                            }
                        }
                    }
                    .accessibilityLabel("Back")
                }
            } trailing: {
                missedAnythingSaveButton
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // ADDING TO THIS WEEK section with added ideals (all except last)
                    let completedDrafts = viewModel.newIdealsToCreate.count > 1 ? Array(viewModel.newIdealsToCreate.dropLast()) : []
                    if !completedDrafts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Adding To This Week (\(completedDrafts.count))")
                                .font(.hhSamuel(23))
                                .textCase(.uppercase)
                                .accentText(.pink)
                                .padding(.horizontal, 20)

                            VStack(spacing: 10) {
                                ForEach(completedDrafts) { draft in
                                    addedIdealCard(draft: draft)
                                }
                            }
                            .padding(.horizontal, LCMetrics.screenMargin)
                        }
                    }

                    // Reactive coverage notice, sitting right above the "Add
                    // Another Ideal" form so it stays next to where the user adds
                    // ideals (not scrolled off the top as the added list grows).
                    // Only for users who landed here with gaps; shrinks as drafts
                    // cover each category.
                    if !missedOnArrival.isEmpty {
                        MissedCategoriesNotice(stillMissing: missingCategoriesIfSavedNow())
                    }

                    // Add another ideal section - always show form for last (current editing) draft
                    if !viewModel.newIdealsToCreate.isEmpty {
                        if let lastDraft = viewModel.newIdealsToCreate.last {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Add Another Ideal")
                                    .font(.hhSamuel(23))
                                    .textCase(.uppercase)
                                    .accentText(.pink)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 14)

                                NeuFeatheredDivider()
                                    .padding(.top, 12)

                                createNewIdealRow(draft: lastDraft)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                            }
                            .padding(.horizontal, LCMetrics.screenMargin)
                        }
                    }

                    // Add to week button — yellow raised CTA, deep-pink glyph + text
                    Button {
                        HapticFeedback.impact()
                        viewModel.addNewIdealDraft()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .heavy))
                            Text(addAnotherIdealLabel)
                        }
                    }
                    .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink, fill: LCColor.yellow, font: .manrope(18, .heavy)))
                    .padding(.horizontal, LCMetrics.screenMargin)

                    // Help text
                    let completedCount = viewModel.newIdealsToCreate.count > 1 ? viewModel.newIdealsToCreate.count - 1 : 0
                    HStack(spacing: 4) {
                        Text("\(completedCount) added")
                        Text("•")
                        Text("tap Save above when you're finished")
                    }
                    .font(.manrope(13, .medium))
                    .foregroundColor(LCColor.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    // Cancel scrolls with the page. It used to sit BELOW the
                    // ScrollView, so the keyboard's safe-area avoidance lifted it
                    // into a sticky bar above the keyboard — not wanted here.
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(.manrope(16, .heavy))
                            .accentText(.pink)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                // Tap anywhere off the fields to dismiss the keyboard.
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }
            }
            // Dragging the page also dismisses the keyboard.
            .scrollDismissesKeyboard(.interactively)
        }
        // Snapshot the gaps on landing: users who arrive fully covered never see
        // the notice, and "all caught up" only makes sense if there WAS a gap.
        .onAppear { missedOnArrival = missingCategoriesIfSavedNow() }
    }

    /// Resigns the first responder so any focused field (e.g. the new-ideal
    /// title) closes its keyboard — used for tap-off-to-dismiss.


    /// Save control for Missed Anything? — yellow raised check with a blue/pink
    /// count badge of items being saved (handoff 1f).
    @ViewBuilder
    private var missedAnythingSaveButton: some View {
        let missedCount = viewModel.newIdealsToCreate.count > 1 ? viewModel.newIdealsToCreate.count - 1 : 0
        let againCount = viewModel.selectedIdealIds.count
        let wishlistCount = viewModel.selectedWishlistIdealIds.count
        let totalCount = againCount + wishlistCount + missedCount

        if viewModel.isSaving {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: LCColor.pink))
                .scaleEffect(0.75)
                .frame(width: 40, height: 40)
                .neuRaisedCircle()
        } else {
            NeuCheckSaveButton(count: totalCount, diameter: 40) {
                performMissedAnythingSave()
            }
            .disabled(!viewModel.hasAnythingToSave() || viewModel.isSaving)
            .opacity(viewModel.hasAnythingToSave() ? 1 : 0.45)
        }
    }

    /// Save action for Missed Anything? — logic unchanged from the pre-redesign toolbar button.
    private func performMissedAnythingSave() {
        guard !viewModel.isSaving else { return }
        let proceedWithSave: () -> Void = {
        withAnimation {
            if isWeeklyPrompt {
                let selectedIdeals = ideals.filter { viewModel.selectedIdealIds.contains($0.id) }
                let selectedWishlistIdeals = wishlistIdeals.filter { viewModel.selectedWishlistIdealIds.contains($0.id) }
                viewModel.savePlanning(selectedIdeals: selectedIdeals, selectedWishlistIdeals: selectedWishlistIdeals, weekStartDay: weekStartDay, requireReason: false, isWeeklyPrompt: true) { result in
                    if !result.validationDuplicates.isEmpty {
                        showValidationDuplicatesAlert(result.validationDuplicates)
                        return
                    }
                    if result.success {
                        if !result.skippedDuplicates.isEmpty {
                            showSkippedDuplicatesAlert(result.skippedDuplicates, dismissOnAcknowledge: true)
                            return
                        }
                        onDismissedAfterSave()
                        isPresented = false
                    }
                }
            } else if shouldSkipReasonScreen() {
                let selectedIdeals = ideals.filter { viewModel.selectedIdealIds.contains($0.id) }
                let selectedWishlistIdeals = wishlistIdeals.filter { viewModel.selectedWishlistIdealIds.contains($0.id) }
                viewModel.savePlanning(selectedIdeals: selectedIdeals, selectedWishlistIdeals: selectedWishlistIdeals, weekStartDay: weekStartDay, requireReason: viewModel.reasonAlreadyProvided, isWeeklyPrompt: plansCurrentWeek) { result in
                    if !result.validationDuplicates.isEmpty {
                        showValidationDuplicatesAlert(result.validationDuplicates)
                        return
                    }
                    if result.success {
                        if !result.skippedDuplicates.isEmpty {
                            showSkippedDuplicatesAlert(result.skippedDuplicates, dismissOnAcknowledge: true)
                            return
                        }
                        onDismissedAfterSave()
                        isPresented = false
                    }
                }
            } else if !unlockedWithPin {
                viewModel.currentScreen = .reason
            } else {
                let selectedIdeals = ideals.filter { viewModel.selectedIdealIds.contains($0.id) }
                let selectedWishlistIdeals = wishlistIdeals.filter { viewModel.selectedWishlistIdealIds.contains($0.id) }
                viewModel.savePlanning(selectedIdeals: selectedIdeals, selectedWishlistIdeals: selectedWishlistIdeals, weekStartDay: weekStartDay, requireReason: viewModel.reasonAlreadyProvided, isWeeklyPrompt: plansCurrentWeek) { result in
                    if !result.validationDuplicates.isEmpty {
                        showValidationDuplicatesAlert(result.validationDuplicates)
                        return
                    }
                    if result.success {
                        if !result.skippedDuplicates.isEmpty {
                            showSkippedDuplicatesAlert(result.skippedDuplicates, dismissOnAcknowledge: true)
                            return
                        }
                        onDismissedAfterSave()
                        isPresented = false
                    }
                }
            }
        }
        }
        let willActuallySave = isWeeklyPrompt || shouldSkipReasonScreen() || unlockedWithPin
        if !willActuallySave {
            proceedWithSave()
        } else {
            let missing = missingCategoriesIfSavedNow()
            if missing.isEmpty {
                proceedWithSave()
            } else {
                missingCategoryNames = missing
                pendingMissedAnythingSave = proceedWithSave
                showCategoryCoverageWarning = true
            }
        }
    }

    @ViewBuilder
    private func createNewIdealRow(draft: PlanningSheetViewModel.NewIdealDraft) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title with same label as wishlist item creation
            Text("What piece might fit the puzzle next?")
                .font(.manrope(16, .heavy))
                .foregroundColor(LCColor.ink)
                .padding(.top, 6)
                .padding(.bottom, 10)
            // Title field extends full width (handoff 1f: no trash icon) — sunken capsule
            TextField("Title", text: Binding(
                get: { draft.title },
                set: { viewModel.updateNewIdealDraft(id: draft.id, title: $0) }
            ))
            .font(.manrope(16, .medium))
            .foregroundColor(LCColor.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .neuSunkenCapsule()
            // Category – 56pt row, label left, pink value + glyph right
            categoryMenuRow(selection: Binding(
                get: { draft.category },
                set: { viewModel.updateNewIdealDraft(id: draft.id, category: $0) }
            ))
            // How Often – sunken number pill between chevrons, 56pt row
            howOftenRow(value: Binding(
                get: { draft.targetCount == "6+" ? 6 : (Int(draft.targetCount) ?? 1) },
                set: { newValue in
                    HapticFeedback.impact()
                    withAnimation {
                        viewModel.updateNewIdealDraft(id: draft.id, targetCount: newValue >= 6 ? "6+" : "\(newValue)")
                    }
                }
            ))
            // Schedule – same format as Next? tab Again? list, 56pt row
            scheduleToggleRow(isOn: Binding(
                get: { draft.setReminder },
                set: { viewModel.updateNewIdealDraft(id: draft.id, setReminder: $0) }
            ))
            if draft.setReminder {
                PlannedReminderGroupsEditor(
                    groups: draft.groups,
                    accentColor: accentColor,
                    days: plansCurrentWeek ? getCurrentWeekRemainingDays(weekStartDay: weekStartDay) : getNextWeekDays(weekStartDay: weekStartDay),
                    dayTitle: plansCurrentWeek ? "Select Days (Current Week)" : "Select Days (Next Week)",
                    onToggleDay: { groupIndex, weekday in
                        viewModel.toggleNewIdealDraftScheduledDay(draftId: draft.id, groupIndex: groupIndex, weekday: weekday)
                    },
                    onSetTime: { groupIndex, time in
                        viewModel.setNewIdealDraftReminderTime(draftId: draft.id, groupIndex: groupIndex, time: time)
                    },
                    onAddGroup: { viewModel.addNewIdealDraftReminderGroup(draftId: draft.id) },
                    onRemoveGroup: { groupIndex in
                        viewModel.removeNewIdealDraftReminderGroup(draftId: draft.id, groupIndex: groupIndex)
                    }
                )
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }

    private func addedIdealCard(draft: PlanningSheetViewModel.NewIdealDraft) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.title.isEmpty ? "Untitled" : draft.title)
                    .font(.idealTitle(21))
                    .foregroundColor(LCColor.ink)
                    .imprinted()
                HStack(spacing: 6) {
                    Text(draft.category)
                    Text("•")
                    Text("x\(draft.targetCount)/week")
                }
                .font(.manrope(13))
                .foregroundColor(LCColor.textMuted)
            }
            Spacer()
            HStack(spacing: 12) {
                Button(action: {
                    HapticFeedback.impact()
                }) {
                    Text("Edit")
                        .font(.manrope(14, .heavy))
                        .accentText(.pink)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    HapticFeedback.impact()
                    viewModel.removeNewIdealDraft(id: draft.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(LCColor.dividerGrey)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var reasonScreen: some View {
        VStack(spacing: 20) {
            sheetHeader("Planning Reason") {
                if unlockedWithPin {
                    NeuCloseButton { isPresented = false }
                        .accessibilityLabel("Cancel")
                } else {
                    NeuBackCircleButton {
                        withAnimation {
                            viewModel.currentScreen = .createNewIdeals
                        }
                    }
                }
            } trailing: {
                EmptyView()
            }

            Spacer()

            Text("Why do you want to plan early?")
                .font(.manrope(20, .heavy))
                .foregroundColor(LCColor.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter your reason", text: $viewModel.planningReason, axis: .vertical)
                    .textFieldStyle(NeumorphicTextFieldStyle())
                    .lineLimit(3...6)
                    .focused($isPlanningReasonFieldFocused)
                    .onChange(of: viewModel.planningReason) { oldValue, newValue in
                        viewModel.showReasonError = false
                    }

                if viewModel.showReasonError {
                    Text("This field is mandatory")
                        .font(.manrope(12, .semibold))
                        .accentText(.pink)
                }
            }
            .padding(.horizontal)

            Spacer()

            // When shown after PIN: Continue to Again? list (reason saved in viewModel); don't show reason again after Missed Anything?
            if unlockedWithPin {
                Button(action: {
                    guard !viewModel.planningReason.trimmingCharacters(in: .whitespaces).isEmpty else {
                        viewModel.showReasonError = true
                        return
                    }
                    viewModel.showReasonError = false
                    viewModel.reasonAlreadyProvided = true
                    withAnimation {
                        routeWeeklyPromptInitial()
                    }
                    // Defer parent update so the sheet content isn't recreated before navigation completes (which would show reason screen again with empty field).
                    DispatchQueue.main.async { onReasonProvided() }
                }) {
                    Text("Continue")
                }
                .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink, fill: LCColor.yellow, font: .manrope(18, .heavy)))
                .disabled(viewModel.planningReason.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(viewModel.planningReason.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .padding()
            } else {
                Button(action: {
                    guard !viewModel.isSaving else { return }
                    let selectedIdeals = ideals.filter { viewModel.selectedIdealIds.contains($0.id) }
                    let selectedWishlistIdeals = wishlistIdeals.filter { viewModel.selectedWishlistIdealIds.contains($0.id) }
                    viewModel.savePlanning(selectedIdeals: selectedIdeals, selectedWishlistIdeals: selectedWishlistIdeals, weekStartDay: weekStartDay, requireReason: true, isWeeklyPrompt: plansCurrentWeek) { result in
                        if !result.validationDuplicates.isEmpty {
                            showValidationDuplicatesAlert(result.validationDuplicates)
                            return
                        }
                        if result.success {
                            if !result.skippedDuplicates.isEmpty {
                                showSkippedDuplicatesAlert(result.skippedDuplicates, dismissOnAcknowledge: true)
                                return
                            }
                            onDismissedAfterSave()
                            isPresented = false
                        }
                    }
                }) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(LCColor.pink)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink, fill: LCColor.yellow, font: .manrope(18, .heavy)))
                .disabled(!viewModel.canSave(requireReason: true) || viewModel.isSaving)
                .opacity(!viewModel.canSave(requireReason: true) || viewModel.isSaving ? 0.5 : 1)
                .padding()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isPlanningReasonFieldFocused = true
            }
        }
    }
    
    // Skip reason screen for weekly prompt; show "Why do you plan early?" only when user unlocked with PIN (reason collected on PIN screen, then shown once in sheet).
    private func shouldSkipReasonScreen() -> Bool {
        // Weekly prompt: never show the reason screen
        if isWeeklyPrompt {
            return true
        }
        // Next? tab: skip reason screen if they already answered it (this flow or a previous sheet open this session)
        if viewModel.reasonAlreadyProvided || reasonAlreadyProvidedFromParent {
            return true
        }
        // Next? tab, no PIN (Phase 1): never show the reason screen
        if !unlockedWithPin {
            return true
        }
        // Next? tab, unlocked with PIN and not yet provided: show reason screen (only at start, right after PIN)
        return false
    }
    
    @ViewBuilder
    private func wishlistItemRow(ideal: Ideal) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            wishlistItemHeader(ideal: ideal)

            if viewModel.selectedWishlistIdealIds.contains(ideal.id) {
                wishlistItemDetails(ideal: ideal)
            }

            NeuFeatheredDivider()
        }
    }

    @ViewBuilder
    private func wishlistItemHeader(ideal: Ideal) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                viewModel.toggleWishlistIdeal(ideal.id)
            }) {
                HStack {
                    Text(ideal.title)
                        .font(.idealTitle(21))
                        .foregroundColor(LCColor.ink)
                        .imprinted()
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Heart select — heart-shaped raised, filled pink when selected
            NeuHeartSelectButton(isSelected: viewModel.selectedWishlistIdealIds.contains(ideal.id)) {
                viewModel.toggleWishlistIdeal(ideal.id)
            }
        }
        .padding(.vertical, 15)
    }

    @ViewBuilder
    private func wishlistItemDetails(ideal: Ideal) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryMenuRow(selection: Binding(
                get: { viewModel.getWishlistCategory(for: ideal.id) },
                set: { viewModel.setWishlistCategory(for: ideal.id, value: $0) }
            ))
            howOftenRow(value: Binding(
                get: { viewModel.getWishlistTargetInt(for: ideal.id) },
                set: { newValue in
                    HapticFeedback.impact()
                    withAnimation {
                        viewModel.setWishlistTargetInt(for: ideal.id, value: newValue)
                    }
                }
            ))

            if isInPlanningWindow() {
                wishlistScheduleSection(ideal: ideal)
            }
        }
        .padding(.leading, 32)
        .padding(.bottom, 8)
        .onAppear {
            initializeWishlistItem(ideal: ideal)
        }
    }

    @ViewBuilder
    private func wishlistScheduleSection(ideal: Ideal) -> some View {
        let schedule = viewModel.getWishlistSchedule(for: ideal.id)

        VStack(alignment: .leading, spacing: 0) {
            scheduleToggleRow(isOn: Binding(
                get: { schedule.setReminder },
                set: { newValue in
                    viewModel.setWishlistReminderEnabled(for: ideal.id, enabled: newValue, prefillFrom: ideal)
                }
            ))

            if schedule.setReminder {
                PlannedReminderGroupsEditor(
                    groups: schedule.groups,
                    accentColor: accentColor,
                    days: plansCurrentWeek ? getCurrentWeekRemainingDays(weekStartDay: weekStartDay) : getNextWeekDays(weekStartDay: weekStartDay),
                    dayTitle: plansCurrentWeek ? "Select Days (Current Week)" : "Select Days (Next Week)",
                    onToggleDay: { groupIndex, weekday in
                        viewModel.toggleWishlistScheduledDay(for: ideal.id, groupIndex: groupIndex, weekday: weekday)
                    },
                    onSetTime: { groupIndex, time in
                        viewModel.setWishlistReminderTime(for: ideal.id, groupIndex: groupIndex, time: time)
                    },
                    onAddGroup: { viewModel.addWishlistReminderGroup(for: ideal.id) },
                    onRemoveGroup: { groupIndex in
                        viewModel.removeWishlistReminderGroup(for: ideal.id, groupIndex: groupIndex)
                    }
                )
                .padding(.top, 4)
            }
        }
    }

    private func initializeWishlistItem(ideal: Ideal) {
        // Initialize wishlist target if not already set
        if viewModel.wishlistTargets[ideal.id] == nil {
            let initialValue = ideal.targetCount
            let initialInt: Int
            if initialValue == "6+" {
                initialInt = 6
            } else {
                initialInt = Int(initialValue) ?? 1
            }
            viewModel.setWishlistTargetInt(for: ideal.id, value: max(1, initialInt))
        }

        // Pre-enable + pre-fill the schedule from the ideal's existing reminders (parity with prior behavior).
        let currentSchedule = viewModel.getWishlistSchedule(for: ideal.id)
        if !currentSchedule.setReminder && !ideal.effectiveReminderSchedules.isEmpty {
            viewModel.setWishlistReminderEnabled(for: ideal.id, enabled: true, prefillFrom: ideal)
        }
    }

    // MARK: - Neumorphic sheet chrome (handoff 1e/1f)

    /// Centered HH Samuel sheet title with the leading (close/back) and trailing
    /// (save) controls overlaid — replaces the system nav bar on every step.
    @ViewBuilder
    private func sheetHeader<Leading: View, Trailing: View>(
        _ title: String,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        ZStack {
            Text(title)
                .font(.hhSamuel(40))
                .textCase(.uppercase)
                .accentText(.pink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 64)
                .frame(maxWidth: .infinity)
            HStack {
                leading()
                Spacer()
                trailing()
            }
            .padding(.horizontal, LCMetrics.screenMargin)
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    /// Uniform 56pt "Category" row — Manrope 800 ink label, pink 800 value with
    /// an up/down glyph; drives the same Picker binding as the old inline picker.
    @ViewBuilder
    private func categoryMenuRow(selection: Binding<String>) -> some View {
        Menu {
            Picker("Category", selection: selection) {
                ForEach(Category.allCases, id: \.rawValue) { cat in
                    Text(cat.rawValue).tag(cat.rawValue)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("Category")
                    .font(.manrope(16, .heavy))
                    .foregroundColor(LCColor.ink)
                Spacer()
                Text(selection.wrappedValue)
                    .font(.manrope(16, .heavy))
                    .accentText(.pink)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .accentText(.pink)
            }
            .frame(maxWidth: .infinity, minHeight: LCMetrics.rowHeight)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Category")
        .accessibilityValue(selection.wrappedValue)
    }

    /// Uniform 56pt "How Often?" row — small sunken number pill between ‹ › chevrons.
    @ViewBuilder
    private func howOftenRow(value: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            Text("How Often?")
                .font(.manrope(16, .heavy))
                .foregroundColor(LCColor.ink)
            Spacer()
            NeuStepper(value: value, range: 1...6, maxLabel: "6+")
        }
        .frame(maxWidth: .infinity, minHeight: LCMetrics.rowHeight)
    }

    /// Uniform 56pt "Schedule a Reminder?" toggle row (pink on / sunken off).
    @ViewBuilder
    private func scheduleToggleRow(isOn: Binding<Bool>) -> some View {
        Toggle("Schedule a Reminder?", isOn: isOn)
            .font(.manrope(16, .heavy))
            .foregroundColor(LCColor.ink)
            .toggleStyle(NeuToggleStyle())
            .frame(minHeight: LCMetrics.rowHeight)
    }
}

#if DEBUG
#Preview {
    PreviewData.configureFirebaseIfNeeded()
    return PlanningSheetView(
        viewModel: PlanningSheetViewModel(),
        ideals: PreviewData.ideals,
        wishlistIdeals: PreviewData.wishlist,
        existingTargetWeekIdeals: [],
        accentColor: LCColor.pink,
        weekStartDay: PreviewData.weekStartDay,
        isPresented: .constant(true),
        unlockedWithPin: true,
        isWeeklyPrompt: false,
        weeklyPromptWithExistingPlan: false,
        showOnlyMissedAnythingStep: false,
        reasonAlreadyProvidedFromParent: false,
        onReasonProvided: {},
        onDismissedAfterSave: {}
    )
}
#endif
