//
//  IdealListView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import SwiftData
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct IdealListView: View {


    private static let weekdayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    // One-shot flag used by menu/icon navigation to force Ideals back to All tab.
    private static let resetToAllTabOnNextAppearKey = "IdealListView.resetToAllTabOnNextAppear"
    static func requestResetToAllTabOnNextAppear() {
        UserDefaults.standard.set(true, forKey: resetToAllTabOnNextAppearKey)
    }
    
    
    
    @StateObject var viewModel = IdealListViewViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager()
    private let idealRepository = IdealRepository.shared
    
    
    @State private var showDrawer: Bool = false
    @State private var goToProgress = false
    @State private var goToIdeals = false
    @State private var showSubscriptionView = false
    @State private var showOfferCodeView = false
    @State private var selectedScheduleFilter: ScheduleFilter = .all
    /// "Next?" planning is its own page now (header NEXT pill), not a tab.
    @State private var showNextPage = false
    /// Set by the Next? screen's planning button: carries the plan-exists flag so
    /// the planning flow can be opened from the list after the Next? cover closes.
    /// Which Next?-screen planning button was tapped, carried across the cover's
    /// dismissal (see showNextPage).
    enum PendingNextPlanning: Equatable {
        case nextWeek(hasExistingPlan: Bool)
        case currentWeek
    }
    @State private var pendingPlanningFromNext: PendingNextPlanning? = nil
    /// Planning was opened by the "Plan Your Current Week" button, so this run
    /// sources the previous active week and saves into the CURRENT week. Reset
    /// whenever the planning cover dismisses.
    @State private var nextPlanningFillsCurrentWeek = false
    @State var showPlanningSheet = false
    @StateObject var planningViewModel = PlanningSheetViewModel()
    /// Provides "now" for weekly prompt logic; DEBUG panel can set virtual date override.
    @ObservedObject var dateProvider = DateProviderService.shared
    @State private var showAddIdealPinSheet = false
    @StateObject private var addIdealPinViewModel = AddIdealPinViewModel()
    @State private var pendingCategoryForNewIdeal: Category? = nil
    @State private var pendingPlanningAction = false
    @State private var planningUnlockedWithPin = false
    @State private var shouldShowPlanningAfterPinDismiss = false // Flag to show planning sheet after PIN sheet dismisses
    @State var isWeeklyPromptPlanningFlow = false // When true, planning sheet shows create-new-ideals screen and no create wishlist option
    /// When true (weekly prompt + plan already created from Next?): sheet shows only unselected Again? list if any, then Missed Anything? (skip wishlist).
    @State var weeklyPromptWithExistingPlan = false
    /// When true, planning sheet opens on Missed Anything? only (no Again?, no Wishlist); used when plan exists and not in planning window.
    @State var showOnlyMissedAnythingStep = false
    /// When true, Next? tab opened sheet to add more to existing next-week plan; do not run plan-table cleanup on save.
    /// When true, Test Weekly Plan Prompt was used: Again? = last week's ideals, save adds to current week only (no planned records).
    @State private var isTestWeeklyPromptMode = false
    @State private var planningSheetDismissedAt: Date? = nil // Throttle re-opening test prompt right after Save/Cancel
    /// Once user answers "Why plan early?" after PIN, skip that screen on any subsequent planning sheet open (same session).
    @State private var userHasProvidedPlanningReasonThisSession = false
    /// Weekly prompt "already offered in this app open" marker. Stored as the
    /// (open id, user id) it was stamped for — see `AppOpenSession` — NOT as
    /// view `@State`: a fresh IdealListView (My Progress → Ideals pushes a new
    /// instance) must not count as a second open, and closing/reopening the app
    /// must reset it. Static so every IdealListView instance in the process
    /// shares it; keyed by user so a sign-out → sign-in inside one open starts
    /// clean for the other account.
    private static var weeklyPromptPresentedOpenId: Int? = nil
    private static var weeklyPromptPresentedUserId: String? = nil
    /// True when the weekly choice/planning was already offered during the
    /// current app open for this account. Setting `true` stamps the current
    /// open + user; `false` clears.
    var hasPresentedWeeklyPlanningPromptThisSession: Bool {
        get {
            AppOpenSession.isCurrentOpen(Self.weeklyPromptPresentedOpenId)
                && Self.weeklyPromptPresentedUserId == userId
        }
        nonmutating set {
            Self.weeklyPromptPresentedOpenId = newValue ? AppOpenSession.currentId : nil
            Self.weeklyPromptPresentedUserId = newValue ? userId : nil
        }
    }
    /// Clears the "offered in this open" stamp. Called when this week's weekly
    /// prompt trackers are wiped (Test Mode reset / virtual-date change) — the
    /// UserDefaults sweep cannot reach a static, and a stale stamp would let the
    /// recap show while silently swallowing the choice that follows it.
    static func resetWeeklyPromptPresentedMarker() {
        weeklyPromptPresentedOpenId = nil
        weeklyPromptPresentedUserId = nil
    }
    /// True while this IdealListView instance is the visible page (set by the
    /// contentView onAppear/onDisappear pair). A NavigationStack keeps the root
    /// alive under a pushed page, and TopNav can push a second IdealListView on
    /// top — only the visible instance may react to a foreground event.
    @State private var isOnScreenForWeeklyFlow = false
    @State private var isRemovingDuplicates = false
    @State private var duplicateRemovalMessage: String? = nil
    /// Gates the automatic duplicate sweep to one run per app session.
    @State private var hasAutoDedupedThisSession = false
    /// Reason captured on PIN screen (planning flow) so we can apply it to planning VM after sheet opens (before PIN VM is reset).
    @State private var planningReasonFromPinVerification: String? = nil
    @State var isFirstWeeklyPromptShowing = false // True when this is the first weekly prompt showing (for last-week review)
    @State var showLastWeekReviewPrompt = false
    @State var showLastWeekReviewView = false
    @State var showWeeklyChoicePrompt = false
    @State private var itemOffsets: [String: CGFloat] = [:]
    @State private var itemWidths: [String: CGFloat] = [:]
    @State private var hapticTriggered: [String: Bool] = [:]
    /// Tracks whether a drag gesture is/was active, to suppress Button taps that fire on drag end.
    @State private var swipeActive = false
    /// Pending confirmation from left-swipe actions in Next? tab rows.
    @State private var nextTabSwipeAlert: NextTabSwipeAlert?
    /// Wishlist item selected for quick add prompt (category + how often).
    @State private var wishlistQuickAddIdeal: Ideal?
    @State private var wishlistQuickAddCategory: String = Category.fix.rawValue
    @State private var wishlistQuickAddTargetCount: Int = 1
    /// Ideal ids with an add-to-next-week write in flight. The duplicate check in
    /// addWishlistItemToNextWeekPlan reads nextWeekPlannedKeys, which cannot see the new planned
    /// record until the write round-trips to the server, so a second tap inside that window would
    /// re-run the add and re-stamp the record's createdDate.
    @State private var wishlistAddsInFlight: Set<String> = []
    /// Shows a debug-style sheet of all records in the planned ideals database.
    @State private var lastWeeklyPromptScreensShown: Set<PlanningSheetViewModel.PlanningScreen> = []
    /// True when the edit sheet was opened from a planned item (Next? tab) so we show planned-item-only fields.
    @State private var isEditingPlannedItem = false
    /// When false, show loader until first Firestore snapshot for current week's ideals.
    @State private var hasReceivedFirstItemsSnapshot = false
    /// Tracks when planned-record snapshot is ready so weekly-flow gating doesn't race items-only loading.
    @State private var hasReceivedFirstPlannedRecordsSnapshot = false
    /// Show the initial loader while waiting for the first Firestore snapshot.
    @State private var shouldShowInitialLoadOverlay = false
    /// Optional, route-specific force-show for initial loader to avoid brief flashes.
    @State private var isForcingInitialLoadOverlay = false
    @State private var hasStartedForcedInitialLoadOverlay = false
    @Namespace private var scheduleSubFilterNamespace

    /// True only when rendering inside an Xcode SwiftUI preview. No Firestore
    /// snapshot arrives there, so the initial loader would otherwise hang
    /// forever — we suppress it so the preview shows the list chrome instead.
    private var isRunningInXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private enum NextTabSwipeAlert: Identifiable {
        case deleteWishlist(Ideal)
        case removePlanned(Ideal)

        var id: String {
            switch self {
            case .deleteWishlist(let ideal):
                return "wishlist-\(ideal.id)"
            case .removePlanned(let ideal):
                return "planned-\(ideal.id)"
            }
        }
    }
    
    enum ScheduleFilter: String, CaseIterable {
        case all = "All"
        case schedule = "Schedule"
        case plan = "Next?"
    }
    
    /// Sub-filter for Schedule tab only: Unscheduled (default), Today, Tomorrow.
    enum ScheduleSubFilter: String, CaseIterable {
        case unscheduled = "Unscheduled"
        case today = "Today"
        case tomorrow = "Tomorrow"
    }
    
    @State private var selectedScheduleSubFilter: ScheduleSubFilter = .unscheduled
    @State private var itemToEdit: Ideal = Ideal(id: "", title: "")
    @State private var itemToReview: Ideal?
    @State private var itemForScheduleDetail: Ideal?

    @State private var categoryForNewIdeal: Category? = nil
    @State private var wishlistCreation: Bool = false
    
    
    @FirestoreQuery var items: [Ideal]
    @FirestoreQuery var plannedItemRecords: [PlannedIdealRecord]
    
    
    @Query var storedTempSettings: [MainSettings]

    @Environment(\.scenePhase) private var scenePhase

    /// Tracks which user's reminder-sync `lastSeenCompleted` state has been seeded in
    /// this view session. Storing the uid (not a Bool) defensively handles the rare case
    /// where the view identity is reused across users (e.g. auth gate keeps the same view
    /// alive). A different signed-in uid triggers a fresh seed for the new user's ideals.
    /// Without this, the new user's first external reminder toggle could be silently lost.
    @State private var seededReminderUid: String? = nil

    private var hasSubscriptionAccess: Bool {
        subscriptionManager.isLoading || subscriptionManager.hasActiveSubscription
    }
    
    var accentColor: Color {
        if let firstSettings = storedTempSettings.first{
            return Color(red: firstSettings.red, green: firstSettings.green, blue: firstSettings.blue, opacity: firstSettings.opacity)
        }else{
            return Color("default_color")
        }
   }
    var start_day: String {
        if let firstSettings = storedTempSettings.first{
            return firstSettings.week_start_day
        }else{
            return "Monday"
        }
    }
    var skip_reviews: Bool {
        if let firstSettings = storedTempSettings.first{
            return firstSettings.skip_reviews
        }else{
            return false
        }
    }
    private let userId: String
    private let initialLoaderMinVisibleDuration: TimeInterval
    init(userId: String, initialLoaderMinVisibleDuration: TimeInterval = 0) {
        self.userId = userId
        self.initialLoaderMinVisibleDuration = initialLoaderMinVisibleDuration
        // Configure FirestoreQuery only; avoid reading other property wrappers here
        self._items = FirestoreQuery(
            collectionPath: "users/\(userId)/ideals",
            predicates: [
                .order(by: "createdDate")
            ]
        )
        self._plannedItemRecords = FirestoreQuery(
            collectionPath: "users/\(userId)/\(PlannedIdealRecord.collectionName)",
            predicates: [
                .order(by: "createdDate")
            ]
        )
        // Initialize state objects/values without accessing other wrappers
        self._viewModel = StateObject(wrappedValue: IdealListViewViewModel())
    }
    /// Current week start and next week start timestamps (user's week_start_day). Used to filter ideals by startDate.
    private var currentWeekBoundaries: (start: TimeInterval, nextStart: TimeInterval)? {
        guard let firstSettings = storedTempSettings.first else { return nil }
        let weekStartDay = firstSettings.week_start_day
        let customCalendar = WeekdayUtility.calendar(firstWeekday: weekStartDay)
        let now = dateProvider.now()
        guard let currentWeekStart = customCalendar.date(from: customCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let nextWeekStart = customCalendar.date(byAdding: .day, value: 7, to: currentWeekStart) else { return nil }
        return (currentWeekStart.timeIntervalSince1970, nextWeekStart.timeIntervalSince1970)
    }
    
    /// Next week boundaries using user-configured week start day.
    private var nextWeekBoundaries: (start: TimeInterval, end: TimeInterval)? {
        guard let current = currentWeekBoundaries else { return nil }
        return (start: current.nextStart, end: current.nextStart + 7 * 24 * 3600)
    }
    
    private func isInRange(_ dateValue: TimeInterval, start: TimeInterval, endExclusive: TimeInterval) -> Bool {
        return dateValue >= start && dateValue < endExclusive
    }

    func duplicateKey(for item: Ideal) -> String? {
        IdealDuplicateGuard.duplicateKey(category: item.category, title: item.title)
    }
    
    /// True if the ideal belongs to the current week (by startDate). Used for All, Today, Tomorrow, Schedule tabs.
    func isInCurrentWeek(_ item: Ideal) -> Bool {
        guard let bounds = currentWeekBoundaries else { return false }
        guard item.startDate > 0 else { return false }
        return item.startDate >= bounds.start && item.startDate < bounds.nextStart
    }
    
    func isInNextWeek(_ item: Ideal) -> Bool {
        guard let bounds = nextWeekBoundaries else { return false }
        guard item.startDate > 0 else { return false }
        return isInRange(item.startDate, start: bounds.start, endExclusive: bounds.end)
    }
    
    // MARK: - "Plan exists" has two contexts:
    // 1) Weekly prompt (first open this week): plan exists = planned records with startDate in the CURRENT week (plan created last week for this week). Use plannedRecordIdsForCurrentWeek / hasPlanRecordForCurrentWeek.
    // 2) Next? tab: plan exists = planned records with startDate in the NEXT week. Use plannedRecordIdsForNextWeek / nextWeekPlannedItems.
    
    /// Planned record IDs whose startDate falls in the current week (used for weekly prompt: "plan from last week for this week").
    var plannedRecordIdsForCurrentWeek: Set<String> {
        guard let bounds = currentWeekBoundaries else { return [] }
        return Set(plannedItemRecords.filter {
            isInRange($0.startDate, start: bounds.start, endExclusive: bounds.nextStart)
        }.map(\.id))
    }
    
    /// Planned record IDs whose startDate falls in next week (used for Next? tab: "plan for next week").
    var plannedRecordIdsForNextWeek: Set<String> {
        guard let bounds = nextWeekBoundaries else { return [] }
        return Set(plannedItemRecords.filter {
            isInRange($0.startDate, start: bounds.start, endExclusive: bounds.end)
        }.map(\.id))
    }
    
    /// IDs of ideals planned for next week (cached for catItems filtering, avoids 7× Set creation per render).
    private var nextWeekPlannedIdSet: Set<String> {
        Set(nextWeekPlannedItems.map(\.id))
    }

    /// Next week planned ideals shown in Next? list.
    private var nextWeekPlannedItems: [Ideal] {
        let plannedIds = plannedRecordIdsForNextWeek
        guard !plannedIds.isEmpty else { return [] }
        return items.filter { item in
            guard !item.wishlistEnabled else { return false }
            guard plannedIds.contains(item.id) else { return false }
            return isInNextWeek(item)
        }
        .sorted { ($0.createdDate, $0.id) > ($1.createdDate, $1.id) }
    }



    /// (category,title) keys for items already planned for next week.
    var nextWeekPlannedKeys: Set<String> {
        Set(nextWeekPlannedItems.compactMap { duplicateKey(for: $0) })
    }

    /// (category,title) keys that already exist in the current week (non-wishlist).
    var currentWeekExistingKeys: Set<String> {
        Set(items.compactMap { item in
            guard !item.wishlistEnabled else { return nil }
            guard isInCurrentWeek(item) else { return nil }
            return duplicateKey(for: item)
        })
    }
    
    /// All ideals whose startDate falls in the current week (for duplicate detection). Uses user's week start.
    private var currentWeekIdealsForDuplicateCheck: [Ideal] {
        guard currentWeekBoundaries != nil else { return [] }
        return items.filter { isInCurrentWeek($0) }
    }
    
    /// Find duplicates in current week by (category, title), keep latest by createdDate, delete the rest. Updates isRemovingDuplicates and duplicateRemovalMessage.
    private func removeDuplicatesInCurrentWeek(silent: Bool = false) {
        guard !isRemovingDuplicates else { return }
        let currentWeek = currentWeekIdealsForDuplicateCheck
        guard !currentWeek.isEmpty else {
            guard !silent else { return }
            duplicateRemovalMessage = "No current week ideals to check."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { duplicateRemovalMessage = nil }
            return
        }
        // Keyed by IdealDuplicateGuard so the cleaner and the create-time guard
        // always agree on what counts as a duplicate.
        let toDelete = IdealDuplicateGuard.duplicatesToRemove(from: currentWeek)
        guard !toDelete.isEmpty else {
            guard !silent else { return }
            duplicateRemovalMessage = "No duplicates found."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { duplicateRemovalMessage = nil }
            return
        }
        isRemovingDuplicates = true
        if !silent { duplicateRemovalMessage = "Removing \(toDelete.count) duplicate(s)..." }
        AppLogger.info(AppLogger.firestore, "[Dedup] removing \(toDelete.count) duplicate ideal(s) in current week")

        let group = DispatchGroup()
        var firstError: Error?
        for ideal in toDelete {
            group.enter()
            // The doc is only half the ideal — its reminders live in EventKit and
            // would keep firing for an ideal that no longer exists.
            NotificationManager.removeRemindersForIdeal(reminderIds: ideal.reminderIds,
                                                        legacyReminderId: ideal.reminderId)
            deletePlannedRecord(for: ideal.id)
            viewModel.delete(id: ideal.id) { error in
                // viewModel.delete hops to the main actor before calling back,
                // so `firstError` is only ever touched on one thread.
                if let error = error, firstError == nil { firstError = error }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            isRemovingDuplicates = false
            if let firstError {
                AppLogger.error(AppLogger.firestore, "[Dedup] failed: \(firstError.localizedDescription)")
            }
            guard !silent else { return }
            if let firstError {
                duplicateRemovalMessage = "Error: \(firstError.localizedDescription)"
            } else {
                duplicateRemovalMessage = "Removed \(toDelete.count) duplicate(s)."
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { duplicateRemovalMessage = nil }
        }
    }

    /// One silent pass per app session: clear duplicate copies that a pre-fix
    /// build (or a retried save on a slow uplink) already wrote to the account.
    /// The create-time guard stops NEW duplicates; this heals data that already
    /// has them, so users never have to hunt for a cleanup button.
    private func autoRemoveDuplicatesOnce() {
        guard !hasAutoDedupedThisSession else { return }
        // Needs real data: a settled snapshot and a resolved week window, else
        // "current week" is guesswork.
        guard hasReceivedFirstItemsSnapshot, !items.isEmpty else { return }
        guard currentWeekBoundaries != nil else { return }
        hasAutoDedupedThisSession = true
        removeDuplicatesInCurrentWeek(silent: true)
    }
    
    /// Single-pass grouping: filters all items once and buckets by Category.
    /// Previous implementation called catItems() 7× (one per category), each doing O(n).
    /// This does O(n) once and catItems() becomes O(1) dictionary lookup.
    private var itemsByCategory: [Category: [Ideal]] {
        let bounds = currentWeekBoundaries  // compute once; avoids O(n) calendar arithmetic
        var result: [Category: [Ideal]] = [:]
        let plannedIds = selectedScheduleFilter == .plan ? nextWeekPlannedIdSet : []
        for item in items {
            guard !item.wishlistEnabled else { continue }
            guard let cat = Category(rawValue: item.category) else { continue }
            let included: Bool
            switch selectedScheduleFilter {
            case .all, .schedule:
                if let b = bounds, item.startDate > 0 {
                    included = item.startDate >= b.start && item.startDate < b.nextStart
                } else {
                    included = false
                }
            case .plan:
                included = plannedIds.contains(item.id)
            }
            if included {
                result[cat, default: []].append(item)
            }
        }
        
        // Sort each category: incomplete items first (sorted by createdDate descending),
        // then completed items (also sorted by createdDate descending)
        for cat in result.keys {
            result[cat] = result[cat]?.sorted { item1, item2 in
                // Determine completion status for each item
                let target1 = item1.targetCount == "6+" ? 6 : (Int(item1.targetCount) ?? 1)
                let target2 = item2.targetCount == "6+" ? 6 : (Int(item2.targetCount) ?? 1)
                let completed1 = item1.doneCount >= target1
                let completed2 = item2.doneCount >= target2
                
                // If completion status differs, incomplete items come first
                if completed1 != completed2 {
                    return !completed1
                }
                
                // If both have same completion status, sort by creation date (newest first)
                return item1.createdDate > item2.createdDate
            }
        }
        
        return result
    }

    func catItems(_ cat: Category) -> [Ideal] {
        return itemsByCategory[cat] ?? []
    }

    /// Aggregate completion (0…1) for the header progress-rings icon, grouped by
    /// the book's official "3 Fs" structure (order matters, outer → inner):
    ///   F THIS = Fix · F ME = Fitness, Feelings, Faculties · F EVERYTHING ELSE = Family, Finance, Fun
    private var groupProgressRings: [Double] {
        // Outer → center. Client decision 2026-07-15: F THIS (Fix) sits at the
        // CENTER pie, F EVERYTHING ELSE on the outer ring.
        let groups: [[Category]] = [
            [.family, .finance, .fun],           // F EVERYTHING ELSE (outer ring)
            [.fitness, .feelings, .faculties],   // F ME (inner ring)
            [.fix]                               // F THIS (center pie)
        ]
        return groups.map { group in
            var done = 0, total = 0
            for cat in group {
                for ideal in catItems(cat) {
                    let target = ideal.targetCount == "6+" ? 6 : (Int(ideal.targetCount) ?? 0)
                    guard target > 0 else { continue }
                    total += target
                    done += min(max(0, ideal.doneCount), target)
                }
            }
            return total > 0 ? Double(done) / Double(total) : 0
        }
    }
    
    // "Skip Reviews This Week?" applies to the week it was enabled in. The rule
    // itself lives on MainSettings so every completion path expires the flag the
    // same way — see `expireSkipReviewsIfWeekElapsed`.
    private func checkAndResetSkipReviews() {
        storedTempSettings.first?.expireSkipReviewsIfWeekElapsed(weekStartDay: start_day,
                                                                 now: dateProvider.now())
    }
    
    // Handle right swipe - increment done count and conditionally show review
    private func handleRightSwipe(for item: Ideal) {
        HapticFeedback.impact()
        viewModel.incrementDoneCount(for: item)

        // Check and reset skip_reviews if it's the start of the week
        checkAndResetSkipReviews()

        // Update weekly notification if enabled (get week start day from settings)
        if let firstSettings = storedTempSettings.first, firstSettings.weekly_notifications {
            NotificationManager.shared.calculateAndUpdateWeeklyNotification(weekStartDay: firstSettings.week_start_day)
        }

        // Only show review view if skip_reviews is false or doesn't exist yet
        let shouldShowReview = storedTempSettings.first?.skip_reviews != true
        if shouldShowReview {
            itemToReview = item
        }
    }
    
    // Handle left swipe - open Schedule detail sheet (Schedule tab) or edit screen (All / Next?)
    private func handleLeftSwipe(for item: Ideal) {
        HapticFeedback.impact()
        if selectedScheduleFilter == .schedule {
            itemForScheduleDetail = item
        } else {
            itemToEdit = item
            isEditingPlannedItem = false
            viewModel.showingEditItemView = true
        }
    }
    
    // Handle tap on ideal - open Schedule detail sheet (Schedule tab) or edit screen (All / Next?)
    private func handleEditTap(for item: Ideal) {
        HapticFeedback.impact()
        if selectedScheduleFilter == .schedule {
            itemForScheduleDetail = item
        } else {
            itemToEdit = item
            isEditingPlannedItem = false
            viewModel.showingEditItemView = true
        }
    }
    
    // Handle planning button tap. If plan exists for next week, always require PIN (re-plan = wipe + fresh start).
    // No plan + in window = open directly. No plan + outside window = require PIN.
    /// "Plan / Re-plan / Unlock Next Week" — unchanged behaviour.
    private func handlePlanningButtonTap(hasExistingPlanForNextWeek: Bool) {
        planningViewModel.reset()
        nextPlanningFillsCurrentWeek = false

        if nextPlanningLayout(hasExistingPlanForNextWeek: hasExistingPlanForNextWeek).nextWeek.requiresPin {
            // Plan exists (wipe before re-planning) or outside the window.
            addIdealPinViewModel.reset()
            showAddIdealPinSheet = true
            pendingCategoryForNewIdeal = nil
            pendingPlanningAction = true
            planningUnlockedWithPin = true
        } else {
            planningUnlockedWithPin = false
            isWeeklyPromptPlanningFlow = false
            showPlanningSheet = true
        }
    }

    /// "Plan Your Current Week" — only offered on an empty current week. No PIN,
    /// no window lock; sources the previous active week and saves into this one.
    private func handleFillCurrentWeekButtonTap() {
        planningViewModel.reset()
        nextPlanningFillsCurrentWeek = true
        planningUnlockedWithPin = false
        isWeeklyPromptPlanningFlow = false
        showPlanningSheet = true
    }

    /// Ideals offered on the Next? screen's Again? step — this week's, or the
    /// last active week's when this week is empty.
    private var againSourceIdeals: [Ideal] {
        NextPlanningDecision.againSourceIdeals(currentWeek: currentWeekIdeals,
                                               lastActiveWeek: previousWeekIdealsForWeeklyPrompt)
    }

    /// Which planning buttons the Next? screen shows right now.
    private func nextPlanningLayout(hasExistingPlanForNextWeek: Bool) -> NextPlanningDecision.Layout {
        let weekStartDay = storedTempSettings.first?.week_start_day ?? viewModel.start_day
        // Only trust "the week is empty" once the data backing it has actually
        // arrived — `currentWeekIdeals` returns [] both for a genuinely empty
        // week and for "settings/ideals not loaded yet", and the second must not
        // conjure a button.
        let weekIsKnownEmpty = hasReceivedFirstItemsSnapshot
            && storedTempSettings.first != nil
            && currentWeekIdeals.isEmpty
        return NextPlanningDecision.layout(
            currentWeekIsEmpty: weekIsKnownEmpty,
            hasPlanForNextWeek: hasExistingPlanForNextWeek,
            isWithinPlanningWindow: WeekdayUtility.isWithinPlanningWindow(from: dateProvider.now(), weekStartDay: weekStartDay)
        )
    }

    // MARK: - Next? cover shared presentations
    //
    // The "Next?" page is a fullScreenCover over the list. A sheet whose modifier
    // lives on the covered list can't present while the cover is up — SwiftUI
    // defers it until the cover is dismissed (the "nothing happens, then the
    // screens appear one after another once you close Next?" bug). So the light
    // add/edit sheets are hosted in BOTH places and each binding is gated to the
    // one context that's actually on screen: the list when Next? is down, the
    // cover's own content when it's up. Exactly one ever presents — no deferral,
    // no double-presentation.

    private func nextContextGated(_ base: Binding<Bool>, inNextCover: Bool) -> Binding<Bool> {
        Binding(
            get: { (inNextCover ? showNextPage : !showNextPage) && base.wrappedValue },
            set: { base.wrappedValue = $0 }
        )
    }

    private func nextContextGated<T>(_ base: Binding<T?>, inNextCover: Bool) -> Binding<T?> {
        Binding(
            get: { (inNextCover ? showNextPage : !showNextPage) ? base.wrappedValue : nil },
            set: { base.wrappedValue = $0 }
        )
    }

    private func newIdealSheetDidDismiss() {
        categoryForNewIdeal = nil
        // Reset wishlist creation flag when the sheet dismisses
        wishlistCreation = false
        // Clear itemToEdit if it was a wishlist item being edited
        if itemToEdit.wishlistEnabled {
            itemToEdit = Ideal(id: "", title: "")
        }
    }

    @ViewBuilder private var newIdealSheetContent: some View {
        // If editing a wishlist item, pass it; otherwise create new
        let editingItem = (wishlistCreation && itemToEdit.wishlistEnabled) ? itemToEdit : nil
        NewIdealView(newItemPresented: $viewModel.showingNewItemView, category: categoryForNewIdeal, wishlist: wishlistCreation, editingItem: editingItem)
    }

    @ViewBuilder private var editIdealSheetContent: some View {
        IdealEditView(item: itemToEdit, editItemPresented: $viewModel.showingEditItemView, plannedItemMode: isEditingPlannedItem)
    }

    @ViewBuilder private func wishlistQuickAddSheetContent(for ideal: Ideal) -> some View {
        WishlistQuickAddSheet(
            idealTitle: ideal.title,
            selectedCategory: $wishlistQuickAddCategory,
            selectedTargetCount: $wishlistQuickAddTargetCount,
            onCancel: { wishlistQuickAddIdeal = nil },
            onAdd: { confirmWishlistQuickAdd() }
        )
    }

    /// Hosts the list's add / edit / quick-add sheets. Applied to the base list
    /// (`inNextCover: false`) and to the Next? cover's content (`inNextCover:
    /// true`); the gated bindings guarantee only the on-screen context presents.
    @ViewBuilder
    private func idealSharedNextSheets<C: View>(_ content: C, inNextCover: Bool) -> some View {
        content
            .sheet(isPresented: nextContextGated($viewModel.showingNewItemView, inNextCover: inNextCover),
                   onDismiss: newIdealSheetDidDismiss) {
                newIdealSheetContent
            }
            .sheet(isPresented: nextContextGated($viewModel.showingEditItemView, inNextCover: inNextCover),
                   onDismiss: { viewModel.showingEditItemView = false }) {
                editIdealSheetContent
            }
            .sheet(item: nextContextGated($wishlistQuickAddIdeal, inNextCover: inNextCover),
                   onDismiss: { wishlistQuickAddIdeal = nil }) { ideal in
                wishlistQuickAddSheetContent(for: ideal)
            }
    }


    // Planning button: locked when plan exists for next week OR outside planning window. PIN required to unlock.
    /// The Next? screen's planning buttons: next week always, plus a current-week
    /// button while this week is still empty.
    @ViewBuilder
    private func planningButton(hasExistingPlanForNextWeek: Bool) -> some View {
        let layout = nextPlanningLayout(hasExistingPlanForNextWeek: hasExistingPlanForNextWeek)
        VStack(spacing: 12) {
            planningCTA(label: layout.nextWeek.buttonLabel,
                        isLocked: layout.nextWeek.isLocked,
                        route: .nextWeek(hasExistingPlan: hasExistingPlanForNextWeek))
            if layout.showsFillCurrentWeek {
                planningCTA(label: NextPlanningDecision.fillCurrentWeekLabel,
                            isLocked: NextPlanningDecision.fillCurrentWeekIsLocked,
                            route: .currentWeek)
                Text("This week has no ideals yet. Fill it from your last active week.")
                    .font(.manrope(14, .medium))
                    .foregroundColor(LCColor.pink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// One planning pill. Both buttons live inside the Next? cover, so presenting
    /// the planning flow directly would defer behind the cover — dismiss Next?
    /// first and open planning from the cover's onDismiss (see showNextPage).
    private func planningCTA(label: String, isLocked: Bool, route: PendingNextPlanning) -> some View {
        Button {
            HapticFeedback.impact()
            pendingPlanningFromNext = route
            showNextPage = false
        } label: {
            HStack(spacing: 10) {
                Text(label)
                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 16, weight: .bold))
            }
        }
        // 1d: neutral raised pill, pink Manrope-800 label + pink lock glyph.
        .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink, font: .manrope(18, .heavy)))
    }
    
    private func categorySection(for cat: Category) -> some View {
        let filteredItems = catItems(cat)
        
        return Section {
            // 6a: full-width pink BANDED header delineates each category — a 24pt
            // gap above the band replaces the old multicolor separator.
            categoryHeader(for: cat)

            ForEach(filteredItems, id: \.id) { item in
                idealItemRow(item: item, filteredItems: filteredItems,
                             isLastSection: cat == Category.allCases.last)
            }
        }
        .tag(cat)
        .padding(.vertical,0)
    }

    @ViewBuilder
    private func categoryHeader(for cat: Category) -> some View {
        IdealListCategoryLabel(
            cat: cat,
            onePlusTapped: {
                handlePlusIconTap(for: cat)
            }
        )
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        // Gap between the previous section's last row and this band (handoff 24px).
        .padding(.top, 24)
        .padding(.bottom, 0)
    }
    
    @ViewBuilder
    private func idealItemRow(item: Ideal, filteredItems: [Ideal], isLastSection: Bool = false) -> some View {
        let itemOffset = itemOffsets[item.id] ?? 0
        let isFirst = item.id == filteredItems.first?.id
        let isLast = item.id == filteredItems.last?.id

        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                swipeOverlay(item: item, itemOffset: itemOffset)

                // Main item content
                IdealListItemLabelV2(
                    item: item,
                    background: accentColor,
                    viewModel: viewModel,
                    itemToEdit: $itemToEdit,
                    onTap: {
                        handleEditTap(for: item)
                    },
                    swipeActive: swipeActive,
                    showCategoryIcon: false,
                    showSchedule: true,
                    weekStartDay: start_day,
                    onScheduleTap: {
                        handleEditTap(for: item)
                    }
                )
                .background(itemWidthGeometryReader(item: item))
                .offset(x: itemOffset)
            }

            // Feathered ~66% divider between consecutive ideals — a break, not a
            // track line (handoff: 30px above and below).
            if !isLast {
                NeuFeatheredDivider()
                    .padding(.vertical, 30)
            }
        }
        // Handoff 6a spacing:
        //  • first ideal: band bottom → title, finger-friendly gap (~28pt).
        //  • last ideal: dots' bottom → next band handled by the band's own
        //    24pt top gap; give the row a small tail so the shadowed dots
        //    never touch the band. Last section gets extra trailing space.
        .padding(.top, isFirst ? 28 : 0)
        .padding(.bottom, isLast ? (isLastSection ? 45 : 8) : 0)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .accessibilityAction(named: "Mark done") {
            handleRightSwipe(for: item)
        }
        .accessibilityAction(named: selectedScheduleFilter == .schedule ? "Schedule" : "Edit") {
            handleLeftSwipe(for: item)
        }
        .simultaneousGesture(itemDragGesture(item: item))
    }
    
    @ViewBuilder
    private func swipeOverlay(item: Ideal, itemOffset: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Right swipe overlay (Done with heart) - appears on LEFT when swiping right
            if itemOffset > 0 {
                rightSwipeOverlay(item: item, itemOffset: itemOffset)
            }
            
            Spacer()
            
            // Left swipe overlay (Details) - appears on RIGHT when swiping left
            if itemOffset < 0 {
                leftSwipeOverlay(itemOffset: itemOffset)
            }
        }
    }
    
    @ViewBuilder
    private func rightSwipeOverlay(item: Ideal, itemOffset: CGFloat) -> some View {
        let itemWidth = itemWidths[item.id] ?? UIScreen.main.bounds.width
        let maxOffset = itemWidth / 4.0
        let progress = min(itemOffset / maxOffset, 1.0)
        
        HStack(spacing: 0) {
            Spacer()
            // Official LC hand-drawn heart + "DONE!" (per KRISTA design rough).
            // The heart traces on (trim-stroke) as the swipe progresses.
            DoneHeartView(progress: progress)
            Spacer()
        }
        .frame(width: itemOffset)
    }
    
    @ViewBuilder
    private func leftSwipeOverlay(itemOffset: CGFloat) -> some View {
        HStack(spacing: 8) {
            Spacer()
            Text(selectedScheduleFilter == .schedule ? "Schedule" : "Details")
                .font(.manrope(16, .heavy))
                .foregroundColor(LCColor.ink)
                .lineLimit(1)
                .fixedSize()
            Spacer()
        }
        .frame(width: abs(itemOffset))
    }
    
    @ViewBuilder
    private func itemWidthGeometryReader(item: Ideal) -> some View {
        GeometryReader { itemGeometry in
            Color.clear
                .onAppear {
                    itemWidths[item.id] = itemGeometry.size.width
                }
                .onChange(of: itemGeometry.size.width) { oldValue, newValue in
                    itemWidths[item.id] = newValue
                }
        }
    }
    
    private func itemDragGesture(item: Ideal) -> some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onChanged { value in
                swipeActive = true
                let horizontalAmount = value.translation.width
                let verticalAmount = abs(value.translation.height)

                // Only animate if horizontal movement is greater than vertical (horizontal swipe)
                if abs(horizontalAmount) > verticalAmount {
                    let itemWidth = itemWidths[item.id] ?? UIScreen.main.bounds.width
                    let maxOffset = itemWidth / 4.0 // Maximum 1/4 of width

                    // Clamp the offset to 1/4 of width
                    let clampedOffset = max(-maxOffset, min(maxOffset, horizontalAmount))
                    itemOffsets[item.id] = clampedOffset

                    // Light haptic feedback when crossing threshold (only once per gesture)
                    if abs(horizontalAmount) > 40 && hapticTriggered[item.id] != true {
                        HapticFeedback.impact(style: .light)
                        hapticTriggered[item.id] = true
                    }
                }
            }
            .onEnded { value in
                let horizontalAmount = value.translation.width
                let verticalAmount = abs(value.translation.height)

                // Reset haptic trigger flag
                hapticTriggered[item.id] = false

                // Animate back to original position
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    itemOffsets[item.id] = 0
                }

                // Only trigger if horizontal movement is greater than vertical (horizontal swipe)
                if abs(horizontalAmount) > verticalAmount && abs(horizontalAmount) > 50 {
                    if horizontalAmount > 50 {
                        // Right swipe - complete action
                        handleRightSwipe(for: item)
                    } else if horizontalAmount < -50 {
                        // Left swipe - edit action
                        handleLeftSwipe(for: item)
                    }
                }

                // Clear swipeActive after a short delay so the Button tap
                // (which fires on .onEnded of the same touch) is still suppressed.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    swipeActive = false
                }
            }
    }
    
    // MARK: - Next? page row label (handoff 1d)
    // Newsreader-italic imprinted title (slightly smaller than 6a so titles stay
    // single-line), optional inline yellow ADD circle, feathered divider below.
    // Wishlist rows stay bare; PLANNED rows opt into the category icon and the
    // target wells (client, 2026-09-02).

    /// Section heading for the Next? page, shown only when the plan and the
    /// wishlist are both listed.
    @ViewBuilder
    private func nextSectionTitle(_ text: String) -> some View {
        // Same treatment as the page's own "NEXT?" header (HH Samuel 40, deep
        // pink, centred) — with a plan on screen these ARE the page's headings,
        // since the top one is hidden (client, 2026-09-02).
        Text(text)
            .font(.hhSamuel(40))
            .textCase(.uppercase)
            .foregroundColor(LCColor.deepPink)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LCMetrics.screenMargin)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
    }

    /// Target wells for a planned ideal — one empty well per target, the same
    /// sunken dots the ideal list uses. Nothing is done yet next week, so they
    /// are all empty by definition.
    @ViewBuilder
    private func plannedTargetWells(for item: Ideal) -> some View {
        let raw = item.plannedTarget ?? item.targetCount
        let target = raw == "6+" ? 6 : max(0, Int(raw) ?? 0)
        if target > 0 {
            HStack(spacing: 6) {
                ForEach(0..<target, id: \.self) { _ in
                    NeumorphicCompletionDot(state: .empty, size: 17)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(target) planned")
        }
    }

    private func nextPageRowLabel(item: Ideal,
                                  onTap: @escaping () -> Void,
                                  onAdd: (() -> Void)? = nil,
                                  showsCategoryIcon: Bool = false,
                                  showsTargetWells: Bool = false) -> some View {
        VStack(spacing: 0) {
            Button {
                guard !swipeActive else { return }
                HapticFeedback.impact(style: .light)
                onTap()
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    if showsCategoryIcon, let category = Category(rawValue: item.category) {
                        Image(category.lcCategoryIconV2())
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(LCColor.blue)
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.idealTitle(22))
                            .foregroundColor(LCColor.ink)
                            .imprinted()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if showsTargetWells {
                            plannedTargetWells(for: item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let onAdd = onAdd {
                        Button {
                            HapticFeedback.impact()
                            onAdd()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundColor(Color(hex: 0x181818))
                                .contentShape(Circle())
                        }
                        .buttonStyle(NeuCircleButtonStyle(fill: LCColor.yellow, diameter: 40))
                        .accessibilityLabel("Add \"\(item.title)\" to plan")
                    }
                }
                .frame(minHeight: LCMetrics.rowHeight)   // finger-friendly hard rule
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            NeuFeatheredDivider()
        }
        .padding(.horizontal, 22)
    }

    /// Swipe-reveal caption behind Next? rows (Details / Delete zones).
    @ViewBuilder
    private func nextPageSwipeCaption(itemOffset: CGFloat, detailsEnd: CGFloat) -> some View {
        HStack(spacing: 0) {
            Spacer()
            if itemOffset < 0 {
                HStack(spacing: 0) {
                    Text("Details")
                        .font(.manrope(16, .heavy))
                        .foregroundColor(LCColor.ink)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: min(detailsEnd, abs(itemOffset)), alignment: .center)
                    if abs(itemOffset) > detailsEnd {
                        Text("Delete")
                            .font(.manrope(16, .heavy))
                            .foregroundColor(LCColor.pink)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(width: abs(itemOffset) - detailsEnd, alignment: .center)
                    }
                }
                .frame(width: abs(itemOffset))
            }
        }
    }

    // MARK: - Planned item row (Next? tab): left swipe max 60%; 0–30% = Details, 31–60% = Delete; Delete text only visible after 30%
    @ViewBuilder
    private func plannedItemRow(item: Ideal, filteredItems: [Ideal]) -> some View {
        let itemOffset = itemOffsets[item.id] ?? 0
        let isFirst = item.id == filteredItems.first?.id
        let isLast = item.id == filteredItems.last?.id
        let w = itemWidths[item.id] ?? UIScreen.main.bounds.width
        let detailsEnd = w * 0.30

        ZStack(alignment: .leading) {
            nextPageSwipeCaption(itemOffset: itemOffset, detailsEnd: detailsEnd)

            nextPageRowLabel(item: item, onTap: {
                itemToEdit = item
                isEditingPlannedItem = true
                viewModel.showingEditItemView = true
            }, showsCategoryIcon: true, showsTargetWells: true)
            .background(itemWidthGeometryReader(item: item))
            .offset(x: itemOffset)
        }
        .padding(.top, isFirst ? 10 : 0)
        .padding(.bottom, isLast ? 10 : 10)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .accessibilityAction(named: "Edit") {
            itemToEdit = item
            isEditingPlannedItem = true
            viewModel.showingEditItemView = true
        }
        .accessibilityAction(named: "Delete") {
            nextTabSwipeAlert = .removePlanned(item)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onChanged { value in
                    swipeActive = true
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    if abs(horizontal) > vertical {
                        let w = itemWidths[item.id] ?? UIScreen.main.bounds.width
                        let maxSwipe = w * 0.60
                        let clamped = max(-maxSwipe, min(0, horizontal))
                        itemOffsets[item.id] = clamped
                    }
                }
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    let w = itemWidths[item.id] ?? UIScreen.main.bounds.width
                    let detailsEnd = w * 0.30
                    let maxSwipe = w * 0.60
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        itemOffsets[item.id] = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        swipeActive = false
                    }
                    guard abs(horizontal) > vertical && horizontal < -50 else { return }
                    let clamped = max(-maxSwipe, min(0, horizontal))
                    if clamped > -detailsEnd {
                        itemToEdit = item
                        isEditingPlannedItem = true
                        viewModel.showingEditItemView = true
                    } else {
                        nextTabSwipeAlert = .removePlanned(item)
                    }
                }
        )
    }

    // MARK: - Wishlist row (Next? tab, no plan): left swipe max 60%; 0–30% = Details, 31–60% = Delete; Delete text only after 30%
    @ViewBuilder
    private func wishlistItemRowNoPlan(item: Ideal, filteredItems: [Ideal]) -> some View {
        let itemOffset = itemOffsets[item.id] ?? 0
        let isFirst = item.id == filteredItems.first?.id
        let isLast = item.id == filteredItems.last?.id
        let w = itemWidths[item.id] ?? UIScreen.main.bounds.width
        let detailsEnd = w * 0.30
        
        ZStack(alignment: .leading) {
            nextPageSwipeCaption(itemOffset: itemOffset, detailsEnd: detailsEnd)

            // Main content: 1d row — title + feathered divider, no circles, no
            // category icon. No ADD circle: there is no plan to add this into
            // yet, so the row only opens details.
            nextPageRowLabel(item: item, onTap: {
                categoryForNewIdeal = nil
                wishlistCreation = true
                itemToEdit = item
                viewModel.showingNewItemView = true
            })
            .background(itemWidthGeometryReader(item: item))
            .offset(x: itemOffset)
        }
        .padding(.top, isFirst ? 10 : 0)
        .padding(.bottom, isLast ? 10 : 10)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .accessibilityAction(named: "Details") {
            categoryForNewIdeal = nil
            wishlistCreation = true
            itemToEdit = item
            viewModel.showingNewItemView = true
        }
        .accessibilityAction(named: "Delete") {
            nextTabSwipeAlert = .deleteWishlist(item)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onChanged { value in
                    swipeActive = true
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    if abs(horizontal) > vertical {
                        let w = itemWidths[item.id] ?? UIScreen.main.bounds.width
                        let maxSwipe = w * 0.60
                        let clamped = max(-maxSwipe, min(0, horizontal))
                        itemOffsets[item.id] = clamped
                    }
                }
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    let w = itemWidths[item.id] ?? UIScreen.main.bounds.width
                    let detailsEnd = w * 0.30
                    let maxSwipe = w * 0.60
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        itemOffsets[item.id] = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        swipeActive = false
                    }
                    guard abs(horizontal) > vertical && horizontal < -50 else { return }
                    let clamped = max(-maxSwipe, min(0, horizontal))
                    if clamped > -detailsEnd {
                        categoryForNewIdeal = nil
                        wishlistCreation = true
                        itemToEdit = item
                        viewModel.showingNewItemView = true
                    } else {
                        nextTabSwipeAlert = .deleteWishlist(item)
                    }
                }
        )
    }

    // MARK: - Wishlist row (Next? tab, with plan): left swipe max 60%; 0–30% = Details, 31–60% = Delete; Delete text only after 30%
    @ViewBuilder
    private func wishlistItemRowWithPlan(item: Ideal, filteredItems: [Ideal]) -> some View {
        let itemOffset = itemOffsets[item.id] ?? 0
        let isFirst = item.id == filteredItems.first?.id
        let isLast = item.id == filteredItems.last?.id
        let w = itemWidths[item.id] ?? UIScreen.main.bounds.width
        let detailsEnd = w * 0.30
        
        ZStack(alignment: .leading) {
            nextPageSwipeCaption(itemOffset: itemOffset, detailsEnd: detailsEnd)

            // 1d row with the inline yellow ADD circle (adds this wishlist ideal
            // to next week's plan via the quick-add prompt).
            nextPageRowLabel(item: item, onTap: {
                categoryForNewIdeal = nil
                wishlistCreation = true
                itemToEdit = item
                viewModel.showingNewItemView = true
            }, onAdd: {
                presentWishlistQuickAddPrompt(for: item)
            })
            .background(itemWidthGeometryReader(item: item))
            .offset(x: itemOffset)
        }
        .padding(.top, isFirst ? 10 : 0)
        .padding(.bottom, isLast ? 10 : 10)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .accessibilityAction(named: "Details") {
            categoryForNewIdeal = nil
            wishlistCreation = true
            itemToEdit = item
            viewModel.showingNewItemView = true
        }
        .accessibilityAction(named: "Add to plan") {
            presentWishlistQuickAddPrompt(for: item)
        }
        .accessibilityAction(named: "Delete") {
            nextTabSwipeAlert = .deleteWishlist(item)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onChanged { value in
                    swipeActive = true
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    if abs(horizontal) > vertical {
                        let w = itemWidths[item.id] ?? UIScreen.main.bounds.width
                        let maxSwipe = w * 0.60
                        let clamped = max(-maxSwipe, min(0, horizontal))
                        itemOffsets[item.id] = clamped
                    }
                }
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    let w = itemWidths[item.id] ?? UIScreen.main.bounds.width
                    let detailsEnd = w * 0.30
                    let maxSwipe = w * 0.60
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        itemOffsets[item.id] = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        swipeActive = false
                    }
                    guard abs(horizontal) > vertical && horizontal < -50 else { return }
                    let clamped = max(-maxSwipe, min(0, horizontal))
                    if clamped > -detailsEnd {
                        categoryForNewIdeal = nil
                        wishlistCreation = true
                        itemToEdit = item
                        viewModel.showingNewItemView = true
                    } else {
                        nextTabSwipeAlert = .deleteWishlist(item)
                    }
                }
        )
    }

    // Helper function to check if an ideal is scheduled
    private func isScheduled(_ item: Ideal) -> Bool {
        // New multi-group system: scheduled if any group has at least one day.
        if !item.reminderSchedules.isEmpty {
            return item.reminderSchedules.contains { !$0.days.isEmpty }
        }
        // Legacy single-schedule: must have reminderTime set (> 0) to count as scheduled.
        if !item.scheduledDays.isEmpty {
            return item.reminderTime > 0
        }
        // Oldest legacy fallback - scheduleDateTime + reminderId.
        guard item.scheduleDateTime > 0 else { return false }
        guard let reminderId = item.reminderId, !reminderId.isEmpty else { return false }
        return true
    }

    // Helper function to check if an ideal is unscheduled
    private func isUnscheduled(_ item: Ideal) -> Bool {
        if !item.reminderSchedules.isEmpty {
            return !item.reminderSchedules.contains { !$0.days.isEmpty }
        }
        if !item.scheduledDays.isEmpty {
            return item.reminderTime <= 0
        }
        if item.scheduleDateTime == 0 { return true }
        return item.reminderId == nil || item.reminderId?.isEmpty == true
    }

    private func isScheduledForToday(_ item: Ideal) -> Bool {
        guard isScheduled(item) else { return false }
        let calendar = Calendar.current
        let now = dateProvider.now()
        let todayWeekday = calendar.component(.weekday, from: now)
        let groups = item.effectiveReminderSchedules
        if !groups.isEmpty {
            let today = calendar.startOfDay(for: now)
            // Scheduled for today if ANY group has today selected with a still-future time.
            for group in groups where group.days.contains(todayWeekday) {
                let hour = Int(group.time) / 3600
                let minute = (Int(group.time) % 3600) / 60
                if let reminderDateTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today),
                   reminderDateTime > now {
                    return true
                }
            }
            return false
        }
        guard item.scheduleDateTime > 0, let rid = item.reminderId, !rid.isEmpty else { return false }
        let scheduleDate = Date(timeIntervalSince1970: item.scheduleDateTime)
        return Calendar.current.isDateInToday(scheduleDate) && scheduleDate > now
    }

    private func isScheduledForTomorrow(_ item: Ideal) -> Bool {
        guard isScheduled(item) else { return false }
        let calendar = Calendar.current
        guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: dateProvider.now()) else { return false }
        let tomorrowWeekday = calendar.component(.weekday, from: tomorrowDate)
        let groups = item.effectiveReminderSchedules
        if !groups.isEmpty {
            return groups.contains { $0.days.contains(tomorrowWeekday) }
        }
        guard item.scheduleDateTime > 0, let rid = item.reminderId, !rid.isEmpty else { return false }
        let scheduleDate = Date(timeIntervalSince1970: item.scheduleDateTime)
        return Calendar.current.isDateInTomorrow(scheduleDate)
    }
    
    /// Items for Schedule tab, filtered by selectedScheduleSubFilter (unscheduled / today / tomorrow).
    private func scheduleSubFilteredItems() -> [Ideal] {
        let all = scheduleFilteredItems()
        switch selectedScheduleSubFilter {
        case .unscheduled: return all.filter { isUnscheduled($0) }
        case .today: return all.filter { isScheduledForToday($0) }
        case .tomorrow: return all.filter { isScheduledForTomorrow($0) }
        }
    }
    
    // Get all items filtered by schedule filter (for schedule view) — current week by startDate only
    private func scheduleFilteredItems() -> [Ideal] {
        return items.filter { item in
            guard !item.wishlistEnabled else { return false }
            return isInCurrentWeek(item)
        }
    }
    
    // Helper to get text color from settings
    private var textColor: Color {
        if let firstSettings = storedTempSettings.first {
            return Color(red: firstSettings.textColorRed, green: firstSettings.textColorGreen, blue: firstSettings.textColorBlue, opacity: firstSettings.textColorOpacity)
        } else {
            return Color.black
        }
    }
    
    
    
    




    private var categorySections: some View {
        ForEach(Category.allCases) { cat in
            categorySection(for: cat)
        }
    }
    
    // Delete an ideal from Firestore (helper moved outside of @ViewBuilder)
    private func deleteWishlistIdeal(_ ideal: Ideal) {
        let itemId = ideal.id
        guard !itemId.isEmpty else {
            AppLogger.error(AppLogger.firestore, "[IdealListView] Cannot delete wishlist ideal: empty id")
            return
        }

        idealRepository.deleteIdeal(userId: userId, idealId: itemId) { error in
            if let error {
                AppLogger.error(AppLogger.firestore, "[IdealListView] Failed to delete wishlist ideal \(itemId): \(error.localizedDescription)")
            } else {
                AppLogger.debug(AppLogger.firestore, "[IdealListView] Deleted wishlist ideal \(itemId)")
            }
        }
    }
    
    private func deletePlannedRecord(for idealId: String) {
        guard !idealId.isEmpty else { return }
        idealRepository.deletePlannedRecord(userId: userId, idealId: idealId)
    }

    /// Batch-delete all next-week planned records and their corresponding next-week ideals from Firestore.
    /// Calls completion on the main queue when done (or on error).
    /// Add a wishlist ideal to next week's plan (in-place update + planned record).
    /// Checks for duplicates in existing next-week plan before adding.
    private func addWishlistItemToNextWeekPlan(_ ideal: Ideal, category: String, targetCount: String) {
        guard ideal.wishlistEnabled, !ideal.id.isEmpty else { return }
        guard !wishlistAddsInFlight.contains(ideal.id) else { return }

        // Duplicate check: skip if same category+title already exists in next week's plan
        if let key = IdealDuplicateGuard.duplicateKey(category: category, title: ideal.title),
           nextWeekPlannedKeys.contains(key) {
            AppLogger.debug(AppLogger.firestore, "[IdealListView] Skipped adding wishlist to plan — duplicate key: \(key)")
            return
        }

        let weekStartDay = storedTempSettings.first?.week_start_day ?? viewModel.start_day
        wishlistAddsInFlight.insert(ideal.id)
        idealRepository.addWishlistIdealToNextWeekPlan(
            userId: userId,
            idealId: ideal.id,
            weekStartDay: weekStartDay,
            category: category,
            targetCount: targetCount
        ) { error in
            wishlistAddsInFlight.remove(ideal.id)
            if let error = error {
                AppLogger.error(AppLogger.firestore, "[IdealListView] Failed to add wishlist to plan: \(error.localizedDescription)")
            }
        }
    }

    private func presentWishlistQuickAddPrompt(for ideal: Ideal) {
        let defaultCategory = Category(rawValue: ideal.category)?.rawValue ?? Category.fix.rawValue
        let parsedTarget: Int
        if ideal.targetCount == "6+" {
            parsedTarget = 6
        } else {
            parsedTarget = Int(ideal.targetCount) ?? 1
        }
        
        wishlistQuickAddCategory = defaultCategory
        wishlistQuickAddTargetCount = max(1, min(6, parsedTarget))
        wishlistQuickAddIdeal = ideal
    }
    
    private func confirmWishlistQuickAdd() {
        guard let ideal = wishlistQuickAddIdeal else { return }
        let targetCount = wishlistQuickAddTargetCount == 6 ? "6+" : "\(wishlistQuickAddTargetCount)"
        addWishlistItemToNextWeekPlan(ideal, category: wishlistQuickAddCategory, targetCount: targetCount)
        wishlistQuickAddIdeal = nil
    }
    
    @ViewBuilder
    private var planSection: some View {
        // Next? tab: "plan exists" = items in plan DB with start dates for NEXT week (nextWeekPlannedItems).
        let plannedItems = nextWeekPlannedItems
        let wishlistItems = items
            .filter { $0.wishlistEnabled }
            .sorted { ($0.createdDate, $0.id) > ($1.createdDate, $1.id) }

        // With a plan on screen the page's own "NEXT?" header is hidden, so these
        // section titles become the headings and must always be present. Without
        // a plan there is only one list and the page header still shows, so no
        // section titles are needed (client, 2026-09-02).
        let showsSectionTitles = !plannedItems.isEmpty

        Group {
            // 1. Planned items list (the page header lives on the fullScreenCover).
            //    With a plan the rows carry the category icon and the target
            //    wells; left swipe Details/Delete only.
            Section {
                if !plannedItems.isEmpty {
                    if showsSectionTitles {
                        nextSectionTitle("Next Week")
                    }
                    VStack(spacing: 14) {
                        ForEach(plannedItems, id: \.id) { item in
                            plannedItemRow(item: item, filteredItems: plannedItems)
                        }
                    }
                    .padding(.bottom, 14)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                } else {
                    // Empty state message
                    Text("You don't have any plan set yet")
                        .font(.manrope(15, .medium))
                        .foregroundColor(LCColor.textSecondary)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listSectionSpacing(.compact)

            // 2. Wishlist list: when no plan use custom row (no icon, no Done; left swipe Details/Delete). When plan exists use same rows + inline ADD circle.
            Section {
                if !wishlistItems.isEmpty {
                    if showsSectionTitles {
                        nextSectionTitle("Next?")
                    }
                    VStack(spacing: 14) {
                        ForEach(wishlistItems, id: \.id) { item in
                            if plannedItems.isEmpty {
                                wishlistItemRowNoPlan(item: item, filteredItems: wishlistItems)
                            } else {
                                wishlistItemRowWithPlan(item: item, filteredItems: wishlistItems)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }

                // "Add To The Next List" (add to wishlist) – scaled-up NEXT-style
                // yellow button (raised, pink label + blue puzzle piece).
                Button(action: {
                    HapticFeedback.impact()
                    categoryForNewIdeal = nil
                    wishlistCreation = true
                    viewModel.showingNewItemView = true
                }) {
                    HStack(spacing: 10) {
                        Text("Add To The Next List")
                            .font(.manrope(20, .heavy))
                            .foregroundColor(LCColor.deepPink)
                        Image("Next Puzzle_Blue")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(NextCTAButtonStyle())
                .padding(.horizontal, LCMetrics.screenMargin)
                .padding(.top, 20)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            // 3. Info text and plan button at the bottom – when no plan, show both buttons (this one + "Add To The Next List" above)
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(!plannedItems.isEmpty ?
                        "You can add more plans for the next week! Use the button below to pick your plans from your existing ideals or wishlist" :
                        "You can now start planning for the next week! Use the button below to pick existing ideals for the next week or use your wishlist.")
                        .font(.manrope(16, .medium))
                        .foregroundColor(LCColor.pink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

                // Plan button: always visible. When plan exists = "Add more to next week" (no PIN). Otherwise phase-based.
                planningButton(hasExistingPlanForNextWeek: !plannedItems.isEmpty)
                    .padding(.horizontal, LCMetrics.screenMargin)
                    .padding(.bottom, 30)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
        }
    }
    
    // Weekly prompt flow helpers extracted to IdealListView+WeeklyPrompt.swift.
    
//    }
    
    // Handle plus icon tap - now no PIN restriction for adding ideals
    private func handlePlusIconTap(for category: Category) {
        categoryForNewIdeal = category
        viewModel.showingNewItemView = true
    }
    
    // Handle successful PIN verification (called when Confirm is tapped on the reason screen)
    private func handlePinSuccess() {
        // Save PIN when user taps Confirm on the question screen (first-time PIN setup)
        if addIdealPinViewModel.isSettingPin {
            if let firstSettings = storedTempSettings.first {
                firstSettings.idealAddPin = addIdealPinViewModel.enteredPinFromDigits
            } else {
                // Create new settings if none exist (shouldn't happen, but just in case)
                // This would require modelContext which we don't have here
                // For now, we'll just proceed - user can set PIN in settings
            }
        }
        
        // Note: PIN is required every time the condition is met, not once per week
        // We don't track PIN verification per week anymore
        
        // Proceed with adding new ideal or planning
        // Defer ALL state changes to avoid "Publishing changes from within view updates" error
        DispatchQueue.main.async {
            if let category = self.pendingCategoryForNewIdeal {
                self.categoryForNewIdeal = category
                self.viewModel.showingNewItemView = true
                self.pendingCategoryForNewIdeal = nil
            } else if self.pendingPlanningAction {
                // Capture reason before reset so we can pass it to planning sheet (reason is on same screen as PIN now)
                self.planningReasonFromPinVerification = self.addIdealPinViewModel.reason
                // Show planning sheet after PIN verification
                self.shouldShowPlanningAfterPinDismiss = true
                // Close PIN sheet after a small delay to ensure current update completes
                DispatchQueue.main.async {
                    self.showAddIdealPinSheet = false
                }
            } else {
                // If no category or edit item pending, assume editing flow and show edit view
                if !self.viewModel.showingEditItemView {
                    self.viewModel.showingEditItemView = true
                }
            }
            
            // Reset state
            self.addIdealPinViewModel.reset()
            self.pendingCategoryForNewIdeal = nil
        }
    }

    /// Prevents weekly-flow branch decisions from using partial snapshot state.
    private func syncWeeklyFlowIfReady() {
        guard hasReceivedFirstItemsSnapshot else { return }
        guard hasReceivedFirstPlannedRecordsSnapshot else { return }
        syncStartDayAndCheckPreviousWeekSheet()
    }
    
    /// Extracted to reduce body type-check complexity.
    private var idealListContent: AnyView {
        AnyView(idealListList
            .listRowSeparator(.hidden)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(LCColor.surface)
            .onAppear{
                if UserDefaults.standard.bool(forKey: Self.resetToAllTabOnNextAppearKey) {
                    selectedScheduleFilter = .all
                    selectedScheduleSubFilter = .unscheduled
                    UserDefaults.standard.set(false, forKey: Self.resetToAllTabOnNextAppearKey)
                }
                
                // Re-evaluate loading state on each page entry:
                // show loader instantly if current list is empty, hide if already loaded.
                if !hasReceivedFirstItemsSnapshot {
                    hasReceivedFirstItemsSnapshot = !items.isEmpty
                }
                if !hasReceivedFirstPlannedRecordsSnapshot {
                    hasReceivedFirstPlannedRecordsSnapshot = !plannedItemRecords.isEmpty
                }
                shouldShowInitialLoadOverlay = !hasReceivedFirstItemsSnapshot
                
                if initialLoaderMinVisibleDuration > 0, !hasStartedForcedInitialLoadOverlay {
                    hasStartedForcedInitialLoadOverlay = true
                    isForcingInitialLoadOverlay = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + initialLoaderMinVisibleDuration) {
                        isForcingInitialLoadOverlay = false
                    }
                }
                
                if !hasReceivedFirstItemsSnapshot {
                    // Safety net: avoid a permanently blocking overlay if a snapshot callback
                    // isn't observed for any reason.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if !hasReceivedFirstItemsSnapshot {
                            hasReceivedFirstItemsSnapshot = true
                            shouldShowInitialLoadOverlay = false
                        }
                    }
                }
                if let firstSettings = storedTempSettings.first {
                    viewModel.start_day = firstSettings.week_start_day
                    NotificationManager.shared.schedulePlanningUnlockedNotification(
                        enabled: true,
                        weekStartDay: firstSettings.week_start_day
                    )
                }
                viewModel.fetchUser()
                syncWeeklyFlowIfReady()
                // Also try here, not just from the items listener: when the list
                // is re-entered with a warm cache, `items` may never change again
                // this session, so the listener alone could miss its one chance.
                autoRemoveDuplicatesOnce()
            }
            .onChange(of: items) { oldValue, newValue in
                if !hasReceivedFirstItemsSnapshot {
                    hasReceivedFirstItemsSnapshot = true
                }
                // First real snapshot — heal any duplicate copies already in the
                // account (silent, once per session).
                autoRemoveDuplicatesOnce()
                // Items arrived from Firestore with actual data — Firestore is responsive.
                // If planned records onChange hasn't fired yet, the collection is truly empty
                // (both listeners share the same Firestore connection and cache).
                if !newValue.isEmpty && !hasReceivedFirstPlannedRecordsSnapshot {
                    hasReceivedFirstPlannedRecordsSnapshot = true
                }
                shouldShowInitialLoadOverlay = false
                AppLogger.debug(AppLogger.ui, "[IdealListView] items changed \(oldValue.count) -> \(newValue.count)")
                syncWeeklyFlowIfReady()
                // Prune swipe/width caches to current item IDs only to avoid unbounded memory growth (OOM).
                let validIds = Set(newValue.map(\.id))
                if !itemWidths.isEmpty || !itemOffsets.isEmpty || !hapticTriggered.isEmpty {
                    itemWidths = itemWidths.filter { validIds.contains($0.key) }
                    itemOffsets = itemOffsets.filter { validIds.contains($0.key) }
                    hapticTriggered = hapticTriggered.filter { validIds.contains($0.key) }
                }
            }
            .onChange(of: plannedItemRecords) { _, _ in
                hasReceivedFirstPlannedRecordsSnapshot = true
                // Race correction: if choice prompt is already showing but plan
                // actually exists (records arrived late), dismiss the prompt and
                // mark the weekly flow complete — plan was created last week.
                reconcileWeeklyFlowIfPlanArrivedLate()
                syncWeeklyFlowIfReady()
            }
            .onChange(of: storedTempSettings.first?.week_start_day) { oldValue, newValue in
                if let newValue = newValue {
                    viewModel.start_day = newValue
                    NotificationManager.shared.schedulePlanningUnlockedNotification(
                        enabled: true,
                        weekStartDay: newValue
                    )
                }
                syncWeeklyFlowIfReady()
            }
        )
    }
    
    private var idealListList: AnyView {
        AnyView(List {
                        TopNav(pageTitle: "My Ideal Week", isIdealList: true, showDrawer: $showDrawer, showingNewItemView: $viewModel.showingNewItemView, userId: userId, externalGoToProgress: $goToProgress, externalGoToIdeals: $goToIdeals, onNextTapped: {
                            selectedScheduleFilter = .plan
                            showNextPage = true
                        }, progressRings: groupProgressRings)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(LCColor.surface)

                        // (Inspiration line now lives in TopNav's header quote box —
                        // the old full-width duplicate under NEXT was removed.)

                        // Test button: manually re-open the weekly prompt. Resets
                        // this week's "already opened" trackers, then triggers the
                        // flow. DEBUG-only — it bypasses every gate, so it must
                        // never ship to the App Store.
                        #if DEBUG
                        Button {
                            HapticFeedback.impact()
                            triggerWeeklyPromptForTesting()
                        } label: {
                            Text("🧪 Open Weekly Prompt (Test)")
                                .font(.manrope(14, .bold))
                                .foregroundColor(LCColor.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, pointsFromArtboardPixels(77))   // 77px side gutter
                                .padding(.bottom, 8)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(LCColor.surface)
                        #endif

                        // Tabs removed: the ideals page always shows the current-week
                        // ideals. "Next?" planning moved to its own page (header NEXT
                        // pill → showNextPage cover). The Schedule tab was dropped.
                        // (Debug buttons + plan-DB utilities removed from the main page.)
                        categorySections
                            .listRowBackground(LCColor.surface)
                    }
                    // Kill the List's implicit inter-row spacing + min row height
                    // so design gaps are controlled purely by explicit positive
                    // paddings (no negative-padding hacks needed to hit the px spec).
                    .listRowSpacing(0)
                    .environment(\.defaultMinListRowHeight, 1)
                    .scrollContentBackground(.hidden)
                    .background(LCColor.surface.ignoresSafeArea())
                    )
    }

    /// Extracted to reduce body type-check complexity.
    /// Extracted to Views/Components/SubscriptionRequiredView.swift; kept as an
    /// AnyView property so `mainContent`'s branch type is unchanged.
    private var subscriptionRequiredView: AnyView {
        AnyView(SubscriptionRequiredView(showSubscriptionView: $showSubscriptionView,
                                        showOfferCodeView: $showOfferCodeView))
    }
    
    var body: some View {
        IdealListRootView(contentView: contentView)
    }
    
    /// Explicit AnyView so compiler can verify View conformance.
    private var contentView: AnyView {
        AnyView(
            mainContent
                .tint(LCColor.pink)
                .onAppear {
                    Task {
                        await subscriptionManager.updatePurchasedProducts()
                    }
                    // Seed the VM snapshot with the current items so the very first
                    // EKEventStoreChanged after onAppear has fresh data.
                    viewModel.updateCurrentItemsSnapshot(items)
                    // Direction B: subscribe to EventKit external changes (e.g. user ticks a
                    // reminder in the system Reminders app) and reconcile doneCount. The
                    // observer reads from the VM's snapshot (not a stale closure capture).
                    IdealReminderSyncService.shared.startObserving { [weak viewModel] in
                        viewModel?.reconcileDoneCountsFromReminders()
                    }
                    // Auto-expire: delete EKReminders whose date is before the current
                    // week start so the user's Reminders list doesn't grow forever.
                    viewModel.pruneStaleRemindersForAllIdeals(weekStartDay: start_day)
                    isOnScreenForWeeklyFlow = true
                }
                .onDisappear {
                    IdealReminderSyncService.shared.stopObserving()
                    isOnScreenForWeeklyFlow = false
                }
                .onChange(of: items) { _, newItems in
                    // Keep the VM snapshot in sync with the live @FirestoreQuery so
                    // reconcile always sees fresh reminderIds / doneCount.
                    viewModel.updateCurrentItemsSnapshot(newItems)
                    // First items snapshot is a good moment to run the one-time legacy
                    // dueDateComponents backfill (gated by UserDefaults in the service —
                    // runs at most once per device install).
                    viewModel.backfillRemindersIfNeeded()
                    // One-time: stamp existing reminders with their ideal-ownership tag
                    // so the list-based auto-expire sweep can recognise legacy reminders.
                    // Self-gated + does its own all-ideals query; safe to call repeatedly.
                    viewModel.backfillIdealIdReminderTagsIfNeeded()
                    // Seed the reminder-sync lastSeen state on first non-empty items load
                    // per signed-in user. This runs reconcile once just to capture the
                    // current EventKit completed-count baseline. Without it, the first
                    // external reminder toggle after launch would be silently folded
                    // into the seed. Keyed by uid so a different user reusing the same
                    // view instance still triggers a fresh seed.
                    let currentUid = Auth.auth().currentUser?.uid
                    if let uid = currentUid, !newItems.isEmpty, seededReminderUid != uid {
                        seededReminderUid = uid
                        viewModel.reconcileDoneCountsFromReminders()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Report first (idempotent with the App-level report), so the
                    // weekly-flow evaluation below sees the new open id whichever
                    // observer SwiftUI happens to run first.
                    AppOpenSession.noteScenePhase(newPhase)
                    // When returning from background (e.g. after editing reminders in the
                    // system Reminders app), background EKEventStoreChanged notifications
                    // may have been missed. Force a reconcile on foreground.
                    if newPhase == .active {
                        viewModel.updateCurrentItemsSnapshot(items)
                        // Reconcile first, then prune. This used to be a correctness
                        // invariant — prune re-seeded lastSeen to an absolute count and
                        // would swallow an external completion that arrived during
                        // background. Prune now only subtracts the completions it deleted
                        // itself, so the order no longer decides the outcome (the onAppear
                        // path prunes without reconciling first and is equally safe). Kept
                        // as defence in depth: reconciling first still applies the delta at
                        // the earliest possible moment.
                        viewModel.reconcileDoneCountsFromReminders()
                        viewModel.pruneStaleRemindersForAllIdeals(weekStartDay: start_day)
                        // A return from background is a new "app open" — the weekly
                        // prompt's second chance (after a Skip / a cancelled planning
                        // sheet on the previous open) is offered here. Every gate in
                        // the decision engine still applies; established users whose
                        // week is already processed see nothing.
                        //
                        // If a weekly-prompt planning sheet is on screen while the
                        // open id moves underneath it, re-stamp: the offer belongs to
                        // this visit, and the cover's onDismiss re-stamp can land
                        // after the list's own onAppear evaluation on Cancel.
                        if showPlanningSheet && isWeeklyPromptPlanningFlow {
                            hasPresentedWeeklyPlanningPromptThisSession = true
                        }
                        // Only the VISIBLE instance evaluates (a hidden NavigationStack
                        // root would present into the void and burn a chance), and only
                        // when no sheet/cover is up: the recap is a presentation, and
                        // presenting over another modal defers/drops it after its
                        // "shown this week" flag is already latched. If we skip here,
                        // that open simply doesn't count — the next one will.
                        if isOnScreenForWeeklyFlow && !Self.isAnyModalPresented {
                            syncWeeklyFlowIfReady()
                        } else {
                            AppLogger.debug(AppLogger.ui, "[WeeklyPrompt] foreground: evaluation skipped (onScreen=\(isOnScreenForWeeklyFlow), modalUp=\(Self.isAnyModalPresented))")
                        }
                    }
                }
        )
    }
    
    private var mainContent: AnyView {
        AnyView(
            NavigationStack{
                ZStack{
                    Group {
                        if hasSubscriptionAccess {
                            idealListContent
                        } else {
                            subscriptionRequiredView
                        }
                    }
                    // Loader until current week's ideals are loaded (first Firestore snapshot).
                    // Skipped in Xcode previews, where no snapshot ever arrives.
                    if hasSubscriptionAccess && !isRunningInXcodePreview &&
                        (isForcingInitialLoadOverlay || (!hasReceivedFirstItemsSnapshot && shouldShowInitialLoadOverlay)) {
                        LCColor.ink.opacity(0.18)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(LCColor.pink)
                                .scaleEffect(1.2)
                            Text("Loading all the pieces for this week...")
                                .font(.manrope(17, .heavy))
                                .foregroundColor(LCColor.ink)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(28)
                        .neuRaised(cornerRadius: LCRadius.card)
                        .padding(.horizontal, 40)
                    }
                    // 7n Weekly Choice — styled modal over the dimmed list. Wires
                    // the SAME two actions the old .alert used; decision logic
                    // (open-count copy variant included) is untouched.
                    if showWeeklyChoicePrompt {
                        WeeklyChoicePromptOverlay(
                            subtitle: currentWeekWeeklyPromptOpenCount >= 2
                                ? "Forgot to add plans for this week? You can add now if you want."
                                : "Plan out your ideals for the week ahead, or skip straight to your list.",
                            onPick: {
                                showWeeklyChoicePrompt = false
                                handleWeeklyChoicePick()
                            },
                            onSkip: {
                                showWeeklyChoicePrompt = false
                                handleWeeklyChoiceSkip()
                            }
                        )
                        .zIndex(10)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeOut(duration: 0.25), value: showWeeklyChoicePrompt)
                .navigationBarBackButtonHidden(true)
                .navigationDestination(isPresented: $goToProgress) {
                    HistoryProgressView(userId: userId)
                }
                .navigationDestination(isPresented: $goToIdeals) {
                    IdealListView(userId: userId, initialLoaderMinVisibleDuration: 0.45)
                }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showNextPage, onDismiss: {
                selectedScheduleFilter = .all
                // Planning is a full-screen takeover, so the Next? cover is
                // dismissed first (the button just set this flag) and the planning
                // flow is opened here, from the now-visible list — otherwise it
                // would defer behind the Next? cover and never appear until close.
                if let route = pendingPlanningFromNext {
                    pendingPlanningFromNext = nil
                    DispatchQueue.main.async {
                        switch route {
                        case .nextWeek(let hasExistingPlan):
                            handlePlanningButtonTap(hasExistingPlanForNextWeek: hasExistingPlan)
                        case .currentWeek:
                            handleFillCurrentWeekButtonTap()
                        }
                    }
                }
            }) {
                idealSharedNextSheets(NavigationStack {
                    List {
                        // 1d header: standard close button top-left, "NEXT?" (HH
                        // Samuel, deep pink) centred inline with it, then a
                        // finger-friendly gap before the first row.
                        ZStack {
                            // Hidden once a plan exists: the "NEXT WEEK" /
                            // "NEXT?" section titles below take over as the
                            // page's headings (client, 2026-09-02). The close
                            // button always stays.
                            if nextWeekPlannedItems.isEmpty {
                                Text("NEXT?")
                                    .font(.hhSamuel(40))
                                    .foregroundColor(LCColor.deepPink)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            HStack {
                                NeuCloseButton(action: { showNextPage = false }, diameter: 36)
                                Spacer()
                            }
                        }
                        .padding(.horizontal, LCMetrics.screenMargin)
                        .padding(.top, 10)
                        .padding(.bottom, 26)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(LCColor.surface)

                        planSection
                            .listRowBackground(LCColor.surface)
                    }
                    .listRowSpacing(0)
                    .environment(\.defaultMinListRowHeight, 1)
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(LCColor.surface.ignoresSafeArea())
                    .toolbar(.hidden, for: .navigationBar)
                }
                .preferredColorScheme(.light), inNextCover: true)
            }
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView(subscriptionManager: subscriptionManager)
            }
            .sheet(isPresented: $showOfferCodeView) {
                OfferCodeView(subscriptionManager: subscriptionManager)
            }
            // Add / edit / quick-add sheets — gated to the list context so they
            // present here only while the Next? cover is down (the cover hosts its
            // own copies via idealSharedNextSheets, see below).
            .sheet(isPresented: nextContextGated($viewModel.showingNewItemView, inNextCover: false),
                   onDismiss: newIdealSheetDidDismiss) {
                newIdealSheetContent
            }
            .sheet(isPresented: nextContextGated($viewModel.showingEditItemView, inNextCover: false),
                   onDismiss: { viewModel.showingEditItemView = false }) {
                editIdealSheetContent
            }
            .sheet(item: $itemForScheduleDetail, onDismiss: { itemForScheduleDetail = nil }) { item in
                ScheduleDetailSheetView(item: item, onDismiss: { itemForScheduleDetail = nil })
            }
            .sheet(item: nextContextGated($wishlistQuickAddIdeal, inNextCover: false),
                   onDismiss: { wishlistQuickAddIdeal = nil }) { ideal in
                wishlistQuickAddSheetContent(for: ideal)
            }
            .sheet(item: $itemToReview, onDismiss: { itemToReview = nil }) { item in
                IdealReviewView(item: item)
            }
            // Full-screen cover (not a sheet): edge-to-edge with no blank space
            // above, and no swipe-down / tap-outside dismissal — so the planning
            // flow can only be left via the explicit Cancel or Save buttons.
            // This prevents accidentally losing an in-progress plan.
            .fullScreenCover(isPresented: $showPlanningSheet, onDismiss: {
                let dismissedWeeklyPrompt = isWeeklyPromptPlanningFlow
                if dismissedWeeklyPrompt {
                    lastWeeklyPromptScreensShown = planningViewModel.screensShownInSession
                    // Re-stamp "offered in this open" at dismiss time: if the app was
                    // backgrounded while the sheet was up, the open id moved on
                    // underneath it, and a snapshot right after Cancel would otherwise
                    // re-offer the choice inside what the user sees as one visit. The
                    // second chance belongs to the NEXT open.
                    hasPresentedWeeklyPlanningPromptThisSession = true
                    // If user saved a plan during the weekly prompt flow, mark the
                    // flow complete immediately so we don't rely on Firestore
                    // snapshot re-trigger (which may be delayed or never arrive
                    // if the app is killed).
                    if planningViewModel.didSaveThisSession {
                        markWeeklyFlowComplete()
                    }
                }
                // Reset planning view model state when dismissed (Save or Cancel)
                planningViewModel.reset()
                planningUnlockedWithPin = false // Reset flag when dismissed
                shouldShowPlanningAfterPinDismiss = false // Reset flag when dismissed
                isWeeklyPromptPlanningFlow = false
                weeklyPromptWithExistingPlan = false
                showOnlyMissedAnythingStep = false
                isTestWeeklyPromptMode = false
                nextPlanningFillsCurrentWeek = false
                planningSheetDismissedAt = Date() // Throttle test prompt from re-opening immediately

                isFirstWeeklyPromptShowing = false
            }) {
                PlanningSheetView(
                    viewModel: planningViewModel,
                    // Source list: the weekly prompt always re-offers LAST active
                    // week. Both Next? buttons repeat THIS week, falling back to
                    // the last active week when this week is empty — otherwise
                    // Again? would open blank with nothing to pick.
                    ideals: (isWeeklyPromptPlanningFlow || isTestWeeklyPromptMode) ? previousWeekIdealsForWeeklyPrompt : againSourceIdeals,
                    wishlistIdeals: (isWeeklyPromptPlanningFlow && !weeklyPromptWithExistingPlan) ? wishlistIdealsNotPlannedForCurrentWeek : wishlistIdealsForPlanning,
                    // Duplicate/"already there" comparison must look at whichever
                    // week is being written to.
                    existingTargetWeekIdeals: (isWeeklyPromptPlanningFlow || isTestWeeklyPromptMode || nextPlanningFillsCurrentWeek) ? currentWeekIdeals : items.filter { !$0.wishlistEnabled && isInNextWeek($0) },
                    accentColor: accentColor,
                    weekStartDay: start_day,
                    isPresented: $showPlanningSheet,
                    unlockedWithPin: planningUnlockedWithPin,
                    isWeeklyPrompt: isWeeklyPromptPlanningFlow,
                    targetsCurrentWeek: nextPlanningFillsCurrentWeek,
                    weeklyPromptWithExistingPlan: weeklyPromptWithExistingPlan,
                    showOnlyMissedAnythingStep: showOnlyMissedAnythingStep,
                    reasonAlreadyProvidedFromParent: userHasProvidedPlanningReasonThisSession,
                    onReasonProvided: { userHasProvidedPlanningReasonThisSession = true },
                    onDismissedAfterSave: { planningSheetDismissedAt = Date() }
                )
            }
            // 7n Weekly Choice is now a styled neumorphic modal over the dimmed
            // list (see weeklyChoicePromptOverlay in the ZStack above) — same two
            // actions the old alert wired (handleWeeklyChoicePick / Skip).
            .alert(item: $nextTabSwipeAlert) { pending in
                switch pending {
                case .deleteWishlist(let ideal):
                    return Alert(
                        title: Text("Delete Ideal?"),
                        message: Text("Are you sure you want to permanently delete \"\(ideal.title)\"? This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            deleteWishlistIdeal(ideal)
                            nextTabSwipeAlert = nil
                        },
                        secondaryButton: .cancel {
                            nextTabSwipeAlert = nil
                        }
                    )
                case .removePlanned(let ideal):
                    return Alert(
                        title: Text("Remove from plan?"),
                        message: Text("Remove \"\(ideal.title)\" from next week's plan? You can add it again later."),
                        primaryButton: .destructive(Text("Remove")) {
                            deletePlannedRecord(for: ideal.id)
                            nextTabSwipeAlert = nil
                        },
                        secondaryButton: .cancel {
                            nextTabSwipeAlert = nil
                        }
                    )
                }
            }
            .sheet(isPresented: $showLastWeekReviewView, onDismiss: {
                handleLastWeekReviewDismiss()
            }) {
                if let userId = Auth.auth().currentUser?.uid {
                    LastWeekReviewView(
                        lastWeekIdeals: getPreviousWeekItems(),
                        accentColor: accentColor,
                        textColor: textColor,
                        weekStartDay: start_day,
                        userId: userId
                    )
                }
            }
            .sheet(isPresented: $showAddIdealPinSheet, onDismiss: {
                // Reset PIN view model state when dismissed
                addIdealPinViewModel.reset()
                pendingCategoryForNewIdeal = nil
                
                // If flag is set, we'll show planning sheet via onChange observer
                // Don't do it here to avoid timing issues
                if !shouldShowPlanningAfterPinDismiss {
                    pendingPlanningAction = false
                }
            }) {
                AddIdealPinView(
                    viewModel: addIdealPinViewModel,
                    storedPin: storedTempSettings.first?.idealAddPin,
                    isPresented: $showAddIdealPinSheet,
                    onSuccess: {
                        handlePinSuccess()
                    },
                    accentColor: accentColor,
                    isForPlanning: pendingPlanningAction
                )
            }
            .onChange(of: showAddIdealPinSheet) { oldValue, newValue in
                // When PIN sheet is dismissed and flag is set, show planning sheet (Next? tab flow, not weekly prompt)
                if oldValue == true && newValue == false && shouldShowPlanningAfterPinDismiss {
                    let openSheet = {
                        DispatchQueue.main.async {
                            self.planningViewModel.reset()
                            if let reason = self.planningReasonFromPinVerification, !reason.isEmpty {
                                self.planningViewModel.planningReason = reason
                                self.planningViewModel.reasonAlreadyProvided = true
                            }
                            self.planningReasonFromPinVerification = nil
                            self.userHasProvidedPlanningReasonThisSession = true
                            self.isWeeklyPromptPlanningFlow = false
                            self.showPlanningSheet = true
                            self.shouldShowPlanningAfterPinDismiss = false
                            self.pendingPlanningAction = false
                        }
                    }
                    openSheet()
                }
            }
            .padding(.leading, MenuDrawer.contentInset)   // iPad sidebar inset (0 on iPhone)
            .overlay(
                MenuDrawer(showDrawer: $showDrawer,activeView:"ideal-list")
            )
        }
        )
    }
}


// MARK: - 7n Weekly Choice modal (replaces the old plain .alert presentation)

#Preview {
    IdealListView(userId: "UkZ5G6FlQePJc6yD2Py4hnnOw3i1")
}

