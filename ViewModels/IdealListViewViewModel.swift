//
//  IdealListViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//
//view model for list of items view
//primary tab
import Foundation
import FirebaseFirestore
import FirebaseAuth
import EventKit
@MainActor
class IdealListViewViewModel: ObservableObject {
    @Published var showingNewItemView = false
    @Published var showingEditItemView = false
    @Published var start_day: String = WeekdayUtility.defaultWeekStartDay
    @Published var skip_reviews: Bool = false
    
    @Published var user: User? = nil
    private let idealRepository = IdealRepository.shared
    private let db = Firestore.firestore()

    /// Latest in-memory snapshot of ideals fed by the view's @FirestoreQuery via onChange.
    /// Used by Direction B reconcile so the observer reads fresh state instead of a closure
    /// capture from onAppear time (which would be stale forever).
    @Published var currentItemsSnapshot: [Ideal] = []

    /// Update the in-memory snapshot used by reconcile flows. Called from the view on
    /// every items change.
    func updateCurrentItemsSnapshot(_ items: [Ideal]) {
        currentItemsSnapshot = items
    }

    func fetchUser(){
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(), error == nil else { return }
            Task { @MainActor [weak self] in
                self?.user = User(
                    id: data["id"] as? String ?? "",
                    first_name: data["first_name"] as? String ?? "",
                    last_name: data["last_name"] as? String ?? "",                    email: data["email"] as? String ?? "",
                    joined: data["joined"] as? TimeInterval ?? 0
                )
            }
        }
        
        
    }
    
    /// Delete to do list item
    /// - Parameter id: item id to delete
    func delete (id: String){
        guard let uId = Auth.auth().currentUser?.uid else {
            AppLogger.error(AppLogger.firestore, "[IdealListViewViewModel] Not authenticated, cannot delete item \(id)")
            return
        }

        idealRepository.deleteIdeal(userId: uId, idealId: id) { error in
            if let error {
                AppLogger.error(AppLogger.firestore, "[IdealListViewViewModel] Error deleting item \(id): \(error.localizedDescription)")
            } else {
                AppLogger.debug(AppLogger.firestore, "[IdealListViewViewModel] Deleted item \(id)")
            }
        }
    }
    
    /// Delete an ideal and call completion on main queue (for batch operations like duplicate removal).
    func delete(id: String, completion: ((Error?) -> Void)? = nil) {
        guard let uId = Auth.auth().currentUser?.uid else {
            AppLogger.error(AppLogger.firestore, "[IdealListViewViewModel] Not authenticated, cannot delete item \(id)")
            Task { @MainActor in completion?(NSError(domain: "IdealListViewViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])) }
            return
        }

        idealRepository.deleteIdeal(userId: uId, idealId: id) { error in
            Task { @MainActor in
                if let error = error {
                    AppLogger.error(AppLogger.firestore, "[IdealListViewViewModel] Error deleting item \(id): \(error.localizedDescription)")
                }
                completion?(error)
            }
        }
    }
    
    
    
    func increaseDoneCount(item: Ideal) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }

        let currentDate = Date().timeIntervalSince1970

        // Fetch current ideal to get lastCompletedDate before updating
        let documentRef = db.collection("users")
            .document(uid)
            .collection("ideals")
            .document(item.id)

        // Read the CACHE first: it overlays this device's pending writes, so a second
        // completion tapped before the first one's ACK still sees tap #1's
        // lastCompletedDate. A server-first read cannot see that in-flight write and
        // returns the pre-tap value, which tap #2 then shifted into
        // secondCompletionDate — a stale date. Same precedent as IdealDuplicateGuard
        // (WeekdayUtility.swift). On cache miss/error fall through to the default read
        // so the date shift still happens rather than dropping to the count-only path.
        documentRef.getDocument(source: .cache) { [weak self] cacheSnapshot, cacheError in
            guard let self else { return } // View dismissed — skip orphaned write

            if cacheError == nil, cacheSnapshot?.data() != nil {
                Self.applyIncrement(
                    item: item,
                    currentDate: currentDate,
                    documentRef: documentRef,
                    snapshot: cacheSnapshot,
                    error: nil
                )
                return
            }

            documentRef.getDocument { [weak self] snapshot, error in
                guard self != nil else { return } // View dismissed — skip orphaned write
                Self.applyIncrement(
                    item: item,
                    currentDate: currentDate,
                    documentRef: documentRef,
                    snapshot: snapshot,
                    error: error
                )
            }
        }
        // UI updates flow through @FirestoreQuery — no separate optimistic state needed.
    }

    /// Writes the +1 increment from a snapshot read. Shared by `increaseDoneCount`'s
    /// cache-first read and its default-read fallback so both land identical writes.
    nonisolated private static func applyIncrement(
        item: Ideal,
        currentDate: TimeInterval,
        documentRef: DocumentReference,
        snapshot: DocumentSnapshot?,
        error: Error?
    ) {
        if let error = error {
            AppLogger.error(AppLogger.firestore, "[IdealListViewViewModel] Error fetching ideal for increment: \(error.localizedDescription)")
            // Fallback: just update without date shifting
            documentRef.updateData([
                "doneCount": FieldValue.increment(Int64(1)),
                "lastCompletedDate": currentDate
            ])
            applyReminderDelta(idealId: item.id, reminderIds: item.reminderIds, delta: 1)
            return
        }

        guard let data = snapshot?.data() else {
            // Fallback: just update without date shifting
            documentRef.updateData([
                "doneCount": FieldValue.increment(Int64(1)),
                "lastCompletedDate": currentDate
            ])
            applyReminderDelta(idealId: item.id, reminderIds: item.reminderIds, delta: 1)
            return
        }

        // Get current lastCompletedDate if it exists
        let currentLastCompletedDate = data["lastCompletedDate"] as? TimeInterval

        // Prepare update data: move lastCompletedDate to secondCompletionDate, set new lastCompletedDate
        var updateData: [String: Any] = [
            "doneCount": FieldValue.increment(Int64(1)),
            "lastCompletedDate": currentDate
        ]

        if let previousDate = currentLastCompletedDate {
            updateData["secondCompletionDate"] = previousDate
        }

        documentRef.updateData(updateData)

        // Direction A: apply +1 delta to EventKit reminders (mark next uncompleted).
        let reminderIds = (data["reminderIds"] as? [String]) ?? item.reminderIds
        applyReminderDelta(idealId: item.id, reminderIds: reminderIds, delta: 1)
    }

    /// Adjusts an ideal's doneCount by ±delta atomically via a Firestore transaction.
    /// Clamped at 0 (won't go negative). Used by Direction B (EventKit → Firestore) when
    /// an external reminder toggle is observed.
    /// Surfaces read errors to the Firestore SDK so it can retry on conflict (do NOT
    /// swallow inside the transaction body).
    func adjustDoneCount(for itemId: String, by delta: Int) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard delta != 0 else { return }
        let ref = db.collection("users").document(uid).collection("ideals").document(itemId)
        db.runTransaction({ txn, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try txn.getDocument(ref)
            } catch let err as NSError {
                errorPointer?.pointee = err
                return nil
            }
            let current = snapshot.data()?["doneCount"] as? Int ?? 0
            let next = max(0, current + delta)
            if next == current { return nil }
            txn.updateData([
                "doneCount": next,
                "lastCompletedDate": Date().timeIntervalSince1970
            ], forDocument: ref)
            return nil
        }, completion: { _, error in
            if let error = error {
                AppLogger.error(AppLogger.firestore, "[IdealListViewViewModel] adjustDoneCount transaction failed: \(error.localizedDescription)")
            }
        })
    }

    /// Reconcile all known ideals against EventKit reminder completion using delta semantics.
    /// Single batched pass: one permission check + one `eventStore.reset()` for the whole
    /// list, then per-ideal delta computation in memory. Reads ideals from
    /// `currentItemsSnapshot` so it always operates on fresh state.
    func reconcileDoneCountsFromReminders() {
        let payload = currentItemsSnapshot
            .filter { !$0.reminderIds.isEmpty }
            .map { (idealId: $0.id, reminderIds: $0.reminderIds) }
        guard !payload.isEmpty else { return }
        IdealReminderSyncService.shared.batchApplyExternalReminderDelta(payload) { [weak self] itemId, delta in
            self?.adjustDoneCount(for: itemId, by: delta)
        }
    }

    /// One-time legacy migration: populate `dueDateComponents` on existing EKReminders.
    /// Idempotent and gated by UserDefaults flag inside the service.
    /// Skips when `currentItemsSnapshot` is empty so a pre-first-snapshot `onChange(of: items)`
    /// fire doesn't prematurely mark backfill complete before real items load.
    func backfillRemindersIfNeeded() {
        guard !currentItemsSnapshot.isEmpty else { return }
        let allReminderIds = currentItemsSnapshot.flatMap { $0.reminderIds }
        IdealReminderSyncService.shared.backfillDueDateComponentsIfNeeded(reminderIds: allReminderIds)
    }

    /// Thin forwarder to the sync service. `nonisolated` because it has no instance state
    /// and the service itself hops to the main queue internally — safe to call from any
    /// thread (e.g. Firestore async callbacks). Removes Swift-6 actor-isolation warnings.
    nonisolated private static func applyReminderDelta(idealId: String, reminderIds: [String], delta: Int) {
        guard !reminderIds.isEmpty, delta != 0 else { return }
        IdealReminderSyncService.shared.applyDoneCountDelta(
            idealId: idealId,
            reminderIds: reminderIds,
            delta: delta
        )
    }

    // MARK: - Auto-expire stale reminders

    private static let lastPruneCutoffKeyPrefix = "IdealListVM.lastPruneCutoffEpoch."

    /// Prune past-week EKReminders for all currently-known ideals, and write the filtered
    /// reminderIds back to Firestore where the list shrunk.
    ///
    /// Throttled by cutoff per user: the cutoff is the current week start, which only
    /// changes once per week. If we already pruned for this user+cutoff, skip — no EventKit
    /// calls, no Firestore reads, no overhead. Per-user keying ensures sign-out / multi-
    /// account scenarios re-prune on first foreground for the new account.
    ///
    /// IMPORTANT: this is isolated from doneCount sync. Prune never calls applyDoneCountDelta
    /// or adjustDoneCount, only deletes EKReminders and updates `reminderIds` in Firestore.
    /// The service updates lastSeenCompleted explicitly + uses a suppress window so the
    /// Direction B observer can't misinterpret our delete as an external uncheck.
    func pruneStaleRemindersForAllIdeals(weekStartDay: String) {
        guard Auth.auth().currentUser?.uid != nil else { return }
        let uid = Auth.auth().currentUser!.uid
        let cutoff = WeekdayUtility.weekStart(weekStartDay: weekStartDay)
        let cutoffEpoch = cutoff.timeIntervalSince1970
        let throttleKey = Self.lastPruneCutoffKeyPrefix + uid
        let lastEpoch = UserDefaults.standard.double(forKey: throttleKey)
        if lastEpoch > 0, abs(lastEpoch - cutoffEpoch) < 1.0 {
            return // Already pruned for this week for this user — no-op.
        }
        UserDefaults.standard.set(cutoffEpoch, forKey: throttleKey)

        // List-based sweep: delete only OUR (tagged) reminders dated before the
        // current week start, then strip the deleted ids from each ideal's
        // Firestore reminderIds. lastSeen re-seeding (done inside the service)
        // guarantees no phantom doneCount change.
        IdealReminderSyncService.shared.pruneStaleRemindersInList(cutoff: cutoff) { [weak self] deletedByIdeal in
            guard let self = self, !deletedByIdeal.isEmpty else { return }
            for (idealId, deletedIds) in deletedByIdeal where !deletedIds.isEmpty {
                self.removeReminderIds(for: idealId, deleting: Set(deletedIds))
            }
        }
    }

    /// One-time: stamp every existing app reminder with its owning ideal's
    /// ownership tag so the list-based prune can recognise legacy reminders.
    /// Queries ALL of the user's ideals (not just the current week) so past-week
    /// reminders also get tagged. Gated by the service's backfill UserDefaults flag.
    /// Session in-flight guard: `backfillIdealIdReminderTagsIfNeeded()` is called
    /// from `onChange(of: items)`, which fires on every Firestore update. Without
    /// this, each update would kick off another full-collection `getDocuments`
    /// (the persistent UserDefaults flag is only set later, inside the async
    /// service callback). Gate per-session so at most one read is in flight.
    private var tagBackfillAttemptedThisSession = false

    func backfillIdealIdReminderTagsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: IdealReminderSyncService.idealIdTagBackfillDefaultsKey) else { return }
        guard !tagBackfillAttemptedThisSession else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        tagBackfillAttemptedThisSession = true
        db.collection("users").document(uid).collection("ideals").getDocuments { snapshot, error in
            if let error = error {
                AppLogger.error(AppLogger.firestore, "[IdealListViewViewModel] tag backfill fetch failed: \(error.localizedDescription)")
                return
            }
            let mapping: [(idealId: String, reminderIds: [String])] = (snapshot?.documents ?? []).compactMap { doc in
                let ids = doc.data()["reminderIds"] as? [String] ?? []
                return (idealId: doc.documentID, reminderIds: ids)
            }
            IdealReminderSyncService.shared.backfillIdealIdTagsIfNeeded(ideals: mapping)
        }
    }

    /// Transactionally remove a set of reminder ids from an ideal's Firestore
    /// `reminderIds`. No-op if the doc is gone (deleted ideal) or already clean.
    private func removeReminderIds(for itemId: String, deleting deletedIds: Set<String>) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = db.collection("users").document(uid).collection("ideals").document(itemId)
        db.runTransaction({ txn, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try txn.getDocument(ref)
            } catch let err as NSError {
                errorPointer?.pointee = err
                return nil
            }
            guard snapshot.exists else { return nil } // ideal deleted — nothing to clean
            let current = snapshot.data()?["reminderIds"] as? [String] ?? []
            let filtered = current.filter { !deletedIds.contains($0) }
            if filtered == current { return nil }
            txn.updateData(["reminderIds": filtered], forDocument: ref)
            return nil
        }, completion: { _, error in
            if let error = error {
                AppLogger.error(AppLogger.firestore, "[IdealListViewViewModel] removeReminderIds transaction failed: \(error.localizedDescription)")
            }
        })
    }

    /// Writes a filtered reminderIds list back to Firestore via transaction. Skips the
    /// write if the server-side list already matches. Surfaces read errors so the SDK can
    /// retry on conflict.
    private func updateReminderIds(for itemId: String, to newIds: [String]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = db.collection("users").document(uid).collection("ideals").document(itemId)
        db.runTransaction({ txn, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try txn.getDocument(ref)
            } catch let err as NSError {
                errorPointer?.pointee = err
                return nil
            }
            let current = snapshot.data()?["reminderIds"] as? [String] ?? []
            if current == newIds { return nil }
            txn.updateData(["reminderIds": newIds], forDocument: ref)
            return nil
        }, completion: { _, error in
            if let error = error {
                AppLogger.error(AppLogger.firestore, "[IdealListViewViewModel] updateReminderIds transaction failed: \(error.localizedDescription)")
            }
        })
    }
    /// Called from IdealListView when user taps to increment doneCount
    func incrementDoneCount(for item: Ideal) {
        increaseDoneCount(item: item)
    }
    
    
}
