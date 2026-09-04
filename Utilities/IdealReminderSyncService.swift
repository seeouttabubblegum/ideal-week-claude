//
//  IdealReminderSyncService.swift
//  The Ideal Week
//
//  Delta-based two-way sync between an Ideal's doneCount and its EventKit reminders.
//
//  Model:
//  - Each ideal-side action (increment/decrement) applies a DELTA of ±1 to one reminder
//    (mark next uncompleted as completed, or unmark last completed). Not aggregate count.
//  - Each reminder-side action (check/uncheck in the system Reminders app) translates to
//    ±1 on the ideal's doneCount via a delta computed from the previously observed state.
//  - doneCount and reminder completion count are NOT kept equal — they only move in
//    lockstep by deltas. One reminder action = one ideal action.
//
//  Loop prevention: 5s suppress window after every internal write; the observer ignores
//  EKEventStoreChanged events that arrive during the window. Last-seen state per ideal
//  is persisted in UserDefaults so the observer computes deltas reliably across restarts.
//
//  Threading: ALL public methods, observer callbacks, and EventKit access happen on the
//  main queue. EventKit work is serialized so the shared EKEventStore is never accessed
//  concurrently.
//

import Foundation
import EventKit

final class IdealReminderSyncService {
    static let shared = IdealReminderSyncService()

    private let eventStore = EKEventStore()
    private var observer: NSObjectProtocol?
    /// Latest `onChange` callback supplied by the view. Replaceable: re-calling
    /// `startObserving` updates this target so a new ViewModel (post-login) can take
    /// over without the singleton observer pointing at a dead/deallocated VM.
    private var onChangeCallback: (() -> Void)?
    private var suppressUntil: Date = .distantPast
    private let suppressWindow: TimeInterval = 5.0
    private let lastSeenKeyPrefix = "IdealReminderSync.lastSeenCompleted."

    private init() {}

    // MARK: - Direction A: ideal doneCount → reminders (DELTA)

    /// Apply a ±N delta to the ideal's reminders.
    /// - `delta > 0`: mark the next |delta| uncompleted reminders (by due date asc) as completed.
    /// - `delta < 0`: unmark the last |delta| completed reminders (by due date asc, take from the end).
    /// - `delta == 0`: no-op.
    /// Idempotent in the sense that if there are no eligible reminders to change (e.g. all already
    /// completed for +delta), the call is a no-op.
    /// After the write, the per-ideal lastSeenCompleted is updated so Direction B doesn't double-apply.
    func applyDoneCountDelta(idealId: String, reminderIds: [String], delta: Int, completion: ((Bool) -> Void)? = nil) {
        Self.ensureMain { [weak self] in
            guard let self = self else { completion?(false); return }
            guard !reminderIds.isEmpty, delta != 0 else { completion?(true); return }

            self.requestAccessMain { [weak self] granted in
                guard let self = self else { completion?(false); return }
                guard granted else {
                    AppLogger.error(AppLogger.notifications, "[IdealReminderSync] access denied for delta apply")
                    completion?(false)
                    return
                }

                self.eventStore.reset()
                let reminders: [EKReminder] = reminderIds.compactMap {
                    self.eventStore.calendarItem(withIdentifier: $0) as? EKReminder
                }
                let sorted = reminders.sorted { Self.sortKey(for: $0) < Self.sortKey(for: $1) }
                let cal = Calendar.current

                // Pre-mark suppress window so EKEventStoreChanged from this write is ignored.
                self.suppressUntil = Date().addingTimeInterval(self.suppressWindow)

                let toChange: [EKReminder]
                let targetCompleted: Bool
                if delta > 0 {
                    targetCompleted = true
                    toChange = sorted.filter { !$0.isCompleted }.prefix(delta).map { $0 }
                } else {
                    targetCompleted = false
                    let pickCount = min(-delta, sorted.filter { $0.isCompleted }.count)
                    toChange = Array(sorted.filter { $0.isCompleted }.suffix(pickCount))
                }

                var didWrite = false
                var sawError = false
                for reminder in toChange {
                    // Preserve dueDateComponents from alarm before EventKit possibly strips alarms on completion.
                    if reminder.dueDateComponents == nil,
                       let alarmDate = reminder.alarms?.first?.absoluteDate {
                        reminder.dueDateComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: alarmDate)
                    }
                    reminder.isCompleted = targetCompleted
                    reminder.completionDate = targetCompleted ? Date() : nil
                    do {
                        try self.eventStore.save(reminder, commit: false)
                        didWrite = true
                    } catch {
                        sawError = true
                        AppLogger.error(AppLogger.notifications, "[IdealReminderSync] save reminder failed: \(error.localizedDescription)")
                    }
                }
                if didWrite {
                    do { try self.eventStore.commit() }
                    catch {
                        sawError = true
                        AppLogger.error(AppLogger.notifications, "[IdealReminderSync] commit failed: \(error.localizedDescription)")
                        self.eventStore.reset()
                    }
                } else {
                    // Nothing to write → drop suppress window so legitimate external changes still flow.
                    self.suppressUntil = .distantPast
                }

                // Update lastSeen to reflect the post-write completed count so the observer
                // doesn't re-apply this delta back to the ideal.
                let newCompletedCount = sorted.reduce(0) { acc, r in acc + (r.isCompleted ? 1 : 0) }
                self.setLastSeen(newCompletedCount, for: idealId)

                AppLogger.debug(AppLogger.notifications, "[IdealReminderSync] applied delta \(delta) → \(toChange.count) reminders toggled, completed now=\(newCompletedCount)")
                completion?(!sawError)
            }
        }
    }

    // MARK: - Direction B: reminders → ideal doneCount (DELTA via lastSeen)

    /// Compute the delta between current completed-reminder count and last-seen count for
    /// this ideal. Calls `onDelta(delta)` only when delta != 0. First observation seeds the
    /// stored state without producing a delta — so previously-completed reminders on launch
    /// don't spuriously bump doneCount.
    ///
    /// Prefer `batchApplyExternalReminderDelta(_:onDelta:)` for multi-ideal reconcile —
    /// this single-ideal entry point performs its own `eventStore.reset()` and access check,
    /// which is wasteful when reconciling many ideals at once.
    func applyExternalReminderDelta(idealId: String, reminderIds: [String], onDelta: @escaping (Int) -> Void) {
        batchApplyExternalReminderDelta([(idealId, reminderIds)]) { id, delta in
            if id == idealId { onDelta(delta) }
        }
    }

    /// Batched variant: runs a single access check + single `eventStore.reset()`, then
    /// computes deltas across all ideals in one pass. The per-ideal `onDelta(idealId, delta)`
    /// callback fires only for non-zero deltas. Use this when reconciling ≥ 2 ideals in
    /// the same tick (e.g. EKEventStoreChanged observer fallout).
    func batchApplyExternalReminderDelta(_ ideals: [(idealId: String, reminderIds: [String])], onDelta: @escaping (String, Int) -> Void) {
        Self.ensureMain { [weak self] in
            guard let self = self else { return }
            let filtered = ideals.filter { !$0.reminderIds.isEmpty }
            guard !filtered.isEmpty else { return }

            self.requestAccessMain { [weak self] granted in
                guard let self = self, granted else { return }
                // Reset once — invalidates the store cache so the upcoming reads see fresh state.
                self.eventStore.reset()

                for (idealId, reminderIds) in filtered {
                    let count = reminderIds.reduce(into: 0) { acc, id in
                        if let r = self.eventStore.calendarItem(withIdentifier: id) as? EKReminder, r.isCompleted {
                            acc += 1
                        }
                    }
                    let key = self.lastSeenKeyPrefix + idealId
                    if UserDefaults.standard.object(forKey: key) == nil {
                        UserDefaults.standard.set(count, forKey: key)
                        AppLogger.debug(AppLogger.notifications, "[IdealReminderSync] seeded lastSeen=\(count) for \(idealId)")
                        continue
                    }
                    let last = UserDefaults.standard.integer(forKey: key)
                    let delta = count - last
                    if delta != 0 {
                        UserDefaults.standard.set(count, forKey: key)
                        AppLogger.info(AppLogger.notifications, "[IdealReminderSync] external delta \(delta) for \(idealId) (last=\(last) now=\(count))")
                        onDelta(idealId, delta)
                    }
                }
            }
        }
    }

    // MARK: - One-time legacy migration: dueDateComponents backfill

    private let backfillCompletedKey = "IdealReminderSync.dueDateBackfillCompletedV1"

    /// One-time migration: populate `dueDateComponents` from each reminder's existing alarm
    /// date if missing. Legacy reminders created before the delta-sync refactor had only an
    /// alarm; EventKit can strip alarms on completion, leaving the reminder weekday
    /// unidentifiable. dueDateComponents persists across completion, so backfilling fixes
    /// the "stuck unknown" failure mode.
    ///
    /// Idempotent: gated by a UserDefaults flag, runs at most once per device install.
    /// Safe no-op for reminders that already have dueDateComponents.
    func backfillDueDateComponentsIfNeeded(reminderIds: [String]) {
        Self.ensureMain { [weak self] in
            guard let self = self else { return }
            guard !UserDefaults.standard.bool(forKey: self.backfillCompletedKey) else { return }
            guard !reminderIds.isEmpty else {
                // Nothing to migrate — mark complete so we don't retry forever for users with no reminders.
                UserDefaults.standard.set(true, forKey: self.backfillCompletedKey)
                return
            }

            self.requestAccessMain { [weak self] granted in
                guard let self = self, granted else { return }
                self.eventStore.reset()

                let cal = Calendar.current
                var didWrite = false
                var sawError = false
                self.suppressUntil = Date().addingTimeInterval(self.suppressWindow)

                for id in reminderIds {
                    guard let r = self.eventStore.calendarItem(withIdentifier: id) as? EKReminder else { continue }
                    if r.dueDateComponents != nil { continue }
                    guard let alarmDate = r.alarms?.first?.absoluteDate else { continue }
                    r.dueDateComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: alarmDate)
                    do {
                        try self.eventStore.save(r, commit: false)
                        didWrite = true
                    } catch {
                        sawError = true
                        AppLogger.error(AppLogger.notifications, "[IdealReminderSync] backfill save failed: \(error.localizedDescription)")
                    }
                }
                if didWrite {
                    do { try self.eventStore.commit() }
                    catch {
                        sawError = true
                        AppLogger.error(AppLogger.notifications, "[IdealReminderSync] backfill commit failed: \(error.localizedDescription)")
                        self.eventStore.reset()
                    }
                } else {
                    self.suppressUntil = .distantPast
                }

                // Mark complete even on partial failure — retry next launch isn't useful since
                // remaining failures are likely permanent (deleted reminders, permission edge cases).
                // Refresh worst case: user can edit a schedule to repopulate the affected reminder.
                if !sawError || !didWrite {
                    UserDefaults.standard.set(true, forKey: self.backfillCompletedKey)
                }
                AppLogger.info(AppLogger.notifications, "[IdealReminderSync] dueDate backfill done (wrote=\(didWrite), errors=\(sawError))")
            }
        }
    }

    // MARK: - Auto-expire: prune past-week reminders

    /// Delete EKReminders for `reminderIds` whose due date (or alarm date as fallback) is
    /// strictly before `cutoff` (typically the start of the current week per user setting).
    /// Returns the remaining reminderIds via `onPruned` so the caller can persist them back
    /// to Firestore. If no pruning happens, `onPruned` is called with the original list.
    /// EventKit has no built-in expiration; this is how we keep the user's Reminders list
    /// from accumulating week after week.
    func pruneStaleReminders(idealId: String, reminderIds: [String], cutoff: Date, onPruned: @escaping (_ remainingIds: [String]) -> Void) {
        Self.ensureMain { [weak self] in
            guard let self = self else { onPruned(reminderIds); return }
            guard !reminderIds.isEmpty else { onPruned([]); return }

            self.requestAccessMain { [weak self] granted in
                guard let self = self, granted else {
                    onPruned(reminderIds)
                    return
                }

                self.eventStore.reset()

                var keep: [String] = []
                var toDelete: [EKReminder] = []
                for id in reminderIds {
                    guard let r = self.eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
                        // Reminder no longer exists — drop the dangling id.
                        continue
                    }
                    let reminderDate: Date? = r.dueDateComponents?.date
                        ?? r.alarms?.first?.absoluteDate
                    if let date = reminderDate, date < cutoff {
                        toDelete.append(r)
                    } else {
                        keep.append(id)
                    }
                }

                if toDelete.isEmpty {
                    // No deletes, but list may have lost dangling ids — return filtered.
                    onPruned(keep)
                    return
                }

                self.suppressUntil = Date().addingTimeInterval(self.suppressWindow)
                var didWrite = false
                for r in toDelete {
                    do {
                        try self.eventStore.remove(r, commit: false)
                        didWrite = true
                    } catch {
                        AppLogger.error(AppLogger.notifications, "[IdealReminderSync] prune remove failed: \(error.localizedDescription)")
                    }
                }
                if didWrite {
                    do { try self.eventStore.commit() }
                    catch {
                        AppLogger.error(AppLogger.notifications, "[IdealReminderSync] prune commit failed: \(error.localizedDescription)")
                        self.eventStore.reset()
                    }
                }

                // The set of relevant reminders shrunk → re-seed lastSeen for fresh tracking.
                let key = self.lastSeenKeyPrefix + idealId
                if keep.isEmpty {
                    UserDefaults.standard.removeObject(forKey: key)
                } else {
                    let completed = keep.reduce(into: 0) { acc, id in
                        if let r = self.eventStore.calendarItem(withIdentifier: id) as? EKReminder, r.isCompleted {
                            acc += 1
                        }
                    }
                    UserDefaults.standard.set(completed, forKey: key)
                }

                AppLogger.info(AppLogger.notifications, "[IdealReminderSync] pruned \(toDelete.count) stale reminders for ideal \(idealId), \(keep.count) remain")
                onPruned(keep)
            }
        }
    }

    /// Reset the per-ideal last-seen count to the current EventKit state. Use after the
    /// reminderIds set changes (e.g. schedule edit) so the next observer fire doesn't
    /// produce a spurious delta from the diff between old and new sets.
    func resyncLastSeen(idealId: String, reminderIds: [String]) {
        Self.ensureMain { [weak self] in
            guard let self = self else { return }
            let key = self.lastSeenKeyPrefix + idealId
            guard !reminderIds.isEmpty else {
                UserDefaults.standard.removeObject(forKey: key)
                return
            }
            self.pullCompletedReminderCount(reminderIds: reminderIds) { count in
                if let count = count {
                    UserDefaults.standard.set(count, forKey: key)
                }
            }
        }
    }

    // MARK: - Internal: pull current state

    /// Reads reminders by id and counts how many are completed. Returns nil on access error.
    private func pullCompletedReminderCount(reminderIds: [String], completion: @escaping (Int?) -> Void) {
        Self.ensureMain { [weak self] in
            guard let self = self else { completion(nil); return }
            guard !reminderIds.isEmpty else { completion(0); return }
            self.requestAccessMain { [weak self] granted in
                guard let self = self else { completion(nil); return }
                guard granted else { completion(nil); return }
                self.eventStore.reset()
                let count = reminderIds.reduce(into: 0) { acc, id in
                    if let r = self.eventStore.calendarItem(withIdentifier: id) as? EKReminder,
                       r.isCompleted {
                        acc += 1
                    }
                }
                completion(count)
            }
        }
    }

    // MARK: - External change observer

    /// Subscribe to EventKit changes from external sources (e.g. system Reminders app).
    /// `onChange` is invoked on the main queue. Internal writes within the suppress window
    /// are filtered out to prevent feedback loops.
    ///
    /// Idempotent: safe to call multiple times. The latest `onChange` callback REPLACES
    /// any previous one — this lets a post-login ViewModel take over from a stale
    /// closure capturing a deallocated VM. The underlying NotificationCenter observer
    /// is registered exactly once.
    func startObserving(onChange: @escaping () -> Void) {
        Self.ensureMain { [weak self] in
            guard let self = self else { return }
            // Always update the callback so a new caller (e.g. fresh VM after login)
            // replaces the previous one — even if observer is already registered.
            self.onChangeCallback = onChange

            guard self.observer == nil else { return }
            self.requestAccessMain { granted in
                if !granted {
                    AppLogger.info(AppLogger.notifications, "[IdealReminderSync] observer installed without reminder access — events may not flow")
                }
            }
            self.observer = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                if Date() < self.suppressUntil {
                    AppLogger.debug(AppLogger.notifications, "[IdealReminderSync] EKEventStoreChanged suppressed (internal write)")
                    return
                }
                AppLogger.debug(AppLogger.notifications, "[IdealReminderSync] EKEventStoreChanged → reconciling")
                self.onChangeCallback?()
            }
        }
    }

    func stopObserving() {
        Self.ensureMain { [weak self] in
            guard let self = self else { return }
            self.onChangeCallback = nil
            if let observer = self.observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
        }
    }

    // MARK: - Permission

    private func requestAccessMain(_ completion: @escaping (Bool) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(iOS 17.0, *) {
            if status == .fullAccess {
                DispatchQueue.main.async { completion(true) }
                return
            }
            eventStore.requestFullAccessToReminders { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            if status == .authorized {
                DispatchQueue.main.async { completion(true) }
                return
            }
            eventStore.requestAccess(to: .reminder) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    // MARK: - Helpers

    private static func ensureMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func setLastSeen(_ count: Int, for idealId: String) {
        UserDefaults.standard.set(count, forKey: lastSeenKeyPrefix + idealId)
    }

    private static func sortKey(for reminder: EKReminder) -> (Date, String) {
        let date: Date = reminder.dueDateComponents?.date
            ?? reminder.alarms?.first?.absoluteDate
            ?? reminder.startDateComponents?.date
            ?? .distantFuture
        return (date, reminder.calendarItemIdentifier)
    }

    // MARK: - Hybrid list-based prune (tagged-only)

    /// UserDefaults flag gating the one-time idealId-tag backfill. Exposed so the
    /// caller can skip an expensive Firestore read once the backfill has run.
    static let idealIdTagBackfillDefaultsKey = "IdealReminderSync.idealIdTagBackfillV1"

    /// Resolve a reminder's effective date for pruning. Returns nil when neither a
    /// due date nor an alarm date exists — in that case we cannot prove the reminder
    /// is stale, so the caller MUST preserve it (never delete an undatable reminder).
    static func resolvedReminderDate(_ reminder: EKReminder) -> Date? {
        reminder.dueDateComponents?.date ?? reminder.alarms?.first?.absoluteDate
    }

    /// Pure prune decision — kept free of EventKit so it can be unit-tested.
    /// Deletes only when ALL hold:
    ///  - the reminder carries our ownership tag (`taggedIdealId != nil`) — never
    ///    touch untagged / user-created reminders;
    ///  - it has a resolvable date — undatable reminders are preserved;
    ///  - that date is strictly before the cutoff (current week start).
    static func shouldPrune(taggedIdealId: String?, resolvedDate: Date?, cutoff: Date) -> Bool {
        guard taggedIdealId != nil else { return false }
        guard let date = resolvedDate else { return false }
        return date < cutoff
    }

    /// Pure prune bookkeeping — what an ideal's `lastSeen` marker becomes after a
    /// prune deleted some of its reminders. Kept free of EventKit/UserDefaults so
    /// the arithmetic can be unit-tested.
    ///
    /// - Parameter current: the stored marker, or nil when the ideal has never
    ///   been observed. The nil case is load-bearing: writing any value for an
    ///   unseeded ideal (even 0) makes the next reconcile read its pre-existing
    ///   completions as a fresh delta and inflate doneCount — the reinstall path,
    ///   since reminders live in an iCloud calendar and outlive UserDefaults.
    /// - Returns: the new marker, or nil when the key must end up absent.
    static func lastSeenAfterPrune(current: Int?, completedDeleted: Int, hasRemainingReminders: Bool) -> Int? {
        guard hasRemainingReminders else { return nil }
        guard let current else { return nil }
        return max(0, current - completedDeleted)
    }

    /// One-time migration: stamp existing app reminders with their owning ideal's
    /// ownership tag (reminder.url), using the caller-supplied id→reminderIds map.
    /// The caller should pass ALL of the user's ideals (not just the current week)
    /// so legacy past-week reminders also become taggable/prunable.
    /// Idempotent: gated by `idealIdTagBackfillDefaultsKey`.
    func backfillIdealIdTagsIfNeeded(ideals: [(idealId: String, reminderIds: [String])]) {
        Self.ensureMain { [weak self] in
            guard let self = self else { return }
            guard !UserDefaults.standard.bool(forKey: Self.idealIdTagBackfillDefaultsKey) else { return }

            let work = ideals.filter { !$0.reminderIds.isEmpty }
            guard !work.isEmpty else {
                // No reminders to tag — mark done so we don't re-query forever.
                UserDefaults.standard.set(true, forKey: Self.idealIdTagBackfillDefaultsKey)
                return
            }

            self.requestAccessMain { [weak self] granted in
                guard let self = self, granted else { return } // retry next launch
                self.eventStore.reset()
                // url-only edits don't change completion state, but suppress anyway
                // so the observer never momentarily misreads our batch.
                self.suppressUntil = Date().addingTimeInterval(self.suppressWindow)

                var didWrite = false
                var sawError = false
                for (idealId, reminderIds) in work {
                    guard let tagURL = NotificationManager.idealTagURL(idealId: idealId) else { continue }
                    for rid in reminderIds {
                        guard let r = self.eventStore.calendarItem(withIdentifier: rid) as? EKReminder else { continue }
                        if r.url == tagURL { continue } // already tagged
                        r.url = tagURL
                        do {
                            try self.eventStore.save(r, commit: false)
                            didWrite = true
                        } catch {
                            sawError = true
                            AppLogger.error(AppLogger.notifications, "[IdealReminderSync] tag backfill save failed: \(error.localizedDescription)")
                        }
                    }
                }
                if didWrite {
                    do { try self.eventStore.commit() }
                    catch {
                        sawError = true
                        self.eventStore.reset()
                        AppLogger.error(AppLogger.notifications, "[IdealReminderSync] tag backfill commit failed: \(error.localizedDescription)")
                    }
                } else {
                    self.suppressUntil = .distantPast
                }
                // Only mark complete on clean success; a hard error retries next launch.
                if !sawError {
                    UserDefaults.standard.set(true, forKey: Self.idealIdTagBackfillDefaultsKey)
                }
                AppLogger.info(AppLogger.notifications, "[IdealReminderSync] idealId-tag backfill done (wrote=\(didWrite), errors=\(sawError))")
            }
        }
    }

    /// Sweep the "The Ideal Week" reminder list and delete only OUR reminders
    /// (tagged via reminder.url) whose resolvable date is strictly before `cutoff`.
    /// Untagged reminders (e.g. anything the user added to the list themselves) are
    /// never touched. Reports the deleted reminder ids grouped by ideal so the caller
    /// can strip them from each ideal's Firestore `reminderIds`.
    ///
    /// Safety (no phantom doneCount change):
    ///  - sets the suppress window before deleting so the observer ignores our writes;
    ///  - decrements each affected ideal's lastSeen by only the completions we ourselves
    ///    deleted, so a later reconcile computes a zero delta for the prune while an
    ///    external completion on a SURVIVING reminder still reads as a delta. An ideal
    ///    left with no reminders, or one never yet observed, stays unseeded.
    func pruneStaleRemindersInList(cutoff: Date, completion: @escaping (_ deletedByIdeal: [String: [String]]) -> Void) {
        Self.ensureMain { [weak self] in
            guard let self = self else { completion([:]); return }
            self.requestAccessMain { [weak self] granted in
                guard let self = self, granted else { completion([:]); return }
                guard let calendar = NotificationManager.idealWeekReminderCalendar(eventStore: self.eventStore) else {
                    completion([:]); return
                }
                self.eventStore.reset()
                let predicate = self.eventStore.predicateForReminders(in: [calendar])
                self.eventStore.fetchReminders(matching: predicate) { [weak self] fetched in
                    Self.ensureMain {
                        guard let self = self else { completion([:]); return }
                        let reminders = fetched ?? []

                        // Decide deletions (pure rule).
                        var toDelete: [(idealId: String, reminder: EKReminder)] = []
                        for r in reminders {
                            let tag = NotificationManager.idealId(fromTagURL: r.url)
                            let date = Self.resolvedReminderDate(r)
                            if Self.shouldPrune(taggedIdealId: tag, resolvedDate: date, cutoff: cutoff), let id = tag {
                                toDelete.append((id, r))
                            }
                        }
                        guard !toDelete.isEmpty else { completion([:]); return }

                        // Guard the observer against our own deletes.
                        self.suppressUntil = Date().addingTimeInterval(self.suppressWindow)

                        var deletedByIdeal: [String: [String]] = [:]
                        for (id, r) in toDelete {
                            let rid = r.calendarItemIdentifier
                            do {
                                try self.eventStore.remove(r, commit: false)
                                deletedByIdeal[id, default: []].append(rid)
                            } catch {
                                AppLogger.error(AppLogger.notifications, "[IdealReminderSync] list-prune remove failed: \(error.localizedDescription)")
                            }
                        }
                        guard !deletedByIdeal.isEmpty else {
                            self.suppressUntil = .distantPast
                            completion([:]); return
                        }
                        do { try self.eventStore.commit() }
                        catch {
                            AppLogger.error(AppLogger.notifications, "[IdealReminderSync] list-prune commit failed: \(error.localizedDescription)")
                            self.eventStore.reset()
                            // Don't report deletes we can't be sure landed — avoids
                            // desyncing Firestore from EventKit.
                            self.suppressUntil = .distantPast
                            completion([:]); return
                        }

                        // Adjust lastSeen per affected ideal for the reminders we removed.
                        let deletedIds = Set(deletedByIdeal.values.flatMap { $0 })
                        for id in deletedByIdeal.keys {
                            let hasRemaining = reminders.contains {
                                NotificationManager.idealId(fromTagURL: $0.url) == id
                                    && !deletedIds.contains($0.calendarItemIdentifier)
                            }
                            // Subtract only the completions we ourselves removed, so an external
                            // completion on a SURVIVING reminder that has not been reconciled yet
                            // still reads as a delta.
                            let completedDeleted = reminders.reduce(into: 0) { acc, r in
                                if NotificationManager.idealId(fromTagURL: r.url) == id,
                                   deletedIds.contains(r.calendarItemIdentifier), r.isCompleted { acc += 1 }
                            }
                            let key = self.lastSeenKeyPrefix + id
                            let current = UserDefaults.standard.object(forKey: key) as? Int
                            if let updated = Self.lastSeenAfterPrune(current: current,
                                                                     completedDeleted: completedDeleted,
                                                                     hasRemainingReminders: hasRemaining) {
                                self.setLastSeen(updated, for: id)
                            } else if current != nil {
                                UserDefaults.standard.removeObject(forKey: key)
                            }
                        }

                        AppLogger.info(AppLogger.notifications, "[IdealReminderSync] list-prune deleted \(deletedIds.count) reminders across \(deletedByIdeal.count) ideals")
                        completion(deletedByIdeal)
                    }
                }
            }
        }
    }
}
