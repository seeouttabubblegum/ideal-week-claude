//
//  IdealEditViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//
//for each todo item in the row
import Foundation
import FirebaseAuth
import FirebaseFirestore
import EventKit

/// One editable reminder group in the edit UI: a set of weekdays + a time-of-day picker value.
/// An ideal's `schedules` is an ordered list of these. Identifiable so SwiftUI `ForEach` can
/// add/remove groups stably.
struct EditableSchedule: Identifiable, Equatable {
    let id: UUID
    var days: Set<Int>
    var time: Date

    init(id: UUID = UUID(), days: Set<Int> = [], time: Date? = nil) {
        self.id = id
        self.days = days
        self.time = time ?? (Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
    }
}

class IdealEditViewViewModel: ObservableObject {
    
    @Published var currentUserId: String = ""
    private var handler: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    init(){
        self.handler = Auth.auth().addStateDidChangeListener {[weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUserId = user?.uid ?? ""
            }
        }
    }
    
    private func removeAuthListener() {
        if let handler = handler {
            Auth.auth().removeStateDidChangeListener(handler)
            self.handler = nil
        }
    }
    
    @Published var showingEditItemView = false
    @Published var id = ""
    @Published var title = ""
    @Published var category = "Family"
    @Published var notes = ""
    @Published var targetCount = "1"
    @Published var doneCount = 0
    @Published var scheduleDateTime = TimeInterval()
    @Published var createdDate = TimeInterval()
    private var startDate: TimeInterval = 0
    private var wishlistEnabled: Bool = false
    private var plannedFromWishlistAt: TimeInterval = 0
    private var plannedTarget: String? = nil
    @Published var showAlert = false
    @Published var alertMessage = "Please fill in all required fields."
    @Published var reminderError: String? = nil
    @Published var active = true
    @Published var isSaving = false
    
    @Published var reminderId: String? = nil // Legacy - kept for backward compatibility
    @Published var setReminder: Bool = false
    @Published var scheduleDateTimeDate: Date = Date().addingTimeInterval(780) // Legacy - kept for backward compatibility
    /// Ordered list of reminder groups (each = days + its own time). Source of truth for the editor.
    @Published var schedules: [EditableSchedule] = []
    @Published var reminderIds: [String] = [] // Array of reminder IDs
    @Published var locationAddress: String? = nil // Optional address for map (Schedule detail)
    private var reviewScore: Int? = nil
    private var sourceIdealId: String? = nil
    private var preserveHiddenScheduleOnSave: Bool = false
    private let eventStore = EKEventStore()
    private var originalDoneCount: Int = 0 // Track original doneCount to detect decrements
    private var originalLastCompletedDate: TimeInterval? = nil // Store original dates
    private var originalSecondCompletionDate: TimeInterval? = nil
    private var originalSchedules: [ReminderSchedule] = [] // To detect schedule edits (vs doneCount-only saves)
    private var originalSetReminder: Bool = false
    private var originalTitle: String = ""
    private var originalNotes: String = ""
    /// `doneCount` recorded when the current schedule was set. Persisted on save so
    /// the row's schedule indicator counts completions relative to schedule-creation
    /// time (see Ideal.scheduleBaselineDoneCount).
    private var scheduleBaselineDoneCount: Int = 0

    init(ideal: Ideal){
        self.id = ideal.id
        self.title = ideal.title
        self.category = ideal.category
        self.notes = ideal.notes
        self.targetCount = ideal.targetCount
        self.doneCount = ideal.doneCount
        self.originalDoneCount = ideal.doneCount // Store original for comparison
        self.scheduleBaselineDoneCount = ideal.scheduleBaselineDoneCount
        self.originalLastCompletedDate = ideal.lastCompletedDate
        self.originalSecondCompletionDate = ideal.secondCompletionDate
        self.originalTitle = ideal.title
        self.originalNotes = ideal.notes
        self.scheduleDateTime = ideal.scheduleDateTime
        self.createdDate = ideal.createdDate
        self.startDate = ideal.startDate
        self.wishlistEnabled = ideal.wishlistEnabled
        self.plannedFromWishlistAt = ideal.plannedFromWishlistAt
        self.plannedTarget = ideal.plannedTarget
        self.active = ideal.active
        self.locationAddress = ideal.locationAddress
        self.sourceIdealId = ideal.sourceIdealId
        
        // Load new schedule system if available, otherwise fall back to legacy
        let loadedSchedules = ideal.effectiveReminderSchedules
        if !loadedSchedules.isEmpty {
            self.schedules = loadedSchedules.map { Self.editable(from: $0) }
            self.setReminder = true
            self.reminderIds = ideal.reminderIds
            self.originalSchedules = Self.normalizedSchedules(loadedSchedules)
            self.originalSetReminder = true
        } else {
            // Legacy support
            self.reminderId = ideal.reminderId
            self.setReminder = ideal.reminderId != nil
            
            // If reminder exists, use its date, otherwise default to 13 minutes from now
            if ideal.reminderId != nil && ideal.scheduleDateTime > 0 {
                let savedDate = Date(timeIntervalSince1970: ideal.scheduleDateTime)
                // Ensure saved date is at least 1 minute in the future, otherwise use default
                let oneMinuteFromNow = Date().addingTimeInterval(60)
                let thirteenMinutesFromNow = Date().addingTimeInterval(780)
                self.scheduleDateTimeDate = savedDate >= oneMinuteFromNow ? savedDate : thirteenMinutesFromNow
            } else {
                self.scheduleDateTimeDate = Date().addingTimeInterval(780)
            }
        }
        self.reviewScore = ideal.reviewScore
    }
    
    deinit {
        removeAuthListener()
    }

    func configurePlannedItemPresentation(defaultScheduleOff: Bool) {
        preserveHiddenScheduleOnSave = defaultScheduleOff
        if defaultScheduleOff {
            setReminder = false
        }
    }

    // MARK: - Schedule group helpers

    /// Append a new empty reminder group (defaults to 9:00 AM). Bound to "Add another reminder".
    func addSchedule() {
        schedules.append(EditableSchedule())
    }

    /// Remove a reminder group by id. Keeps at least one group present while `setReminder` is on
    /// so the UI never shows the toggle on with zero editable rows.
    func removeSchedule(id: UUID) {
        schedules.removeAll { $0.id == id }
        if setReminder && schedules.isEmpty {
            schedules = [EditableSchedule()]
        }
    }

    /// Toggle a weekday within a specific group.
    func toggleDay(_ day: Int, for id: UUID) {
        guard let idx = schedules.firstIndex(where: { $0.id == id }) else { return }
        if schedules[idx].days.contains(day) {
            schedules[idx].days.remove(day)
        } else {
            schedules[idx].days.insert(day)
        }
    }

    /// Ensure there's at least one editable group whenever the reminder toggle is on.
    func ensureAtLeastOneSchedule() {
        if setReminder && schedules.isEmpty {
            schedules = [EditableSchedule()]
        }
    }

    private static func editable(from model: ReminderSchedule) -> EditableSchedule {
        let hour = Int(model.time) / 3600
        let minute = (Int(model.time) % 3600) / 60
        let time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return EditableSchedule(days: Set(model.days), time: time)
    }

    private static func secondsSinceMidnight(_ date: Date) -> TimeInterval {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeInterval((c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60)
    }

    /// Convert the editor's groups into persistable model groups, dropping empty-day groups
    /// and normalizing (sorted unique days). Order preserved.
    private func modelSchedules() -> [ReminderSchedule] {
        schedules.compactMap { s in
            let days = Array(s.days).sorted()
            guard !days.isEmpty else { return nil }
            return ReminderSchedule(days: days, time: Self.secondsSinceMidnight(s.time))
        }
    }

    /// Normalize for equality comparison: drop empty groups, sort each group's days.
    private static func normalizedSchedules(_ list: [ReminderSchedule]) -> [ReminderSchedule] {
        list.compactMap { s in
            let days = s.days.sorted()
            guard !days.isEmpty else { return nil }
            return ReminderSchedule(days: days, time: s.time)
        }
    }

    /// Legacy mirror written alongside `reminderSchedules` for back-compat with read sites /
    /// other clients: union of all groups' days + the first group's time.
    private static func legacyMirror(from model: [ReminderSchedule]) -> (days: [Int], time: TimeInterval) {
        let union = Array(Set(model.flatMap { $0.days })).sorted()
        let time = model.first?.time ?? 0
        return (union, time)
    }
    
    func delete (){
        // Remove all reminders when deleting
        removeAllReminders()
        
        if let uId = Auth.auth().currentUser?.uid {
            db.collection("users")
                .document(uId)
                .collection("ideals")
                .document(self.id)
                .delete()

        }
    }
    
    // Helper function to get dates for selected weekdays in current week
    private func getDatesForWeekdays(_ weekdays: Set<Int>, weekStartDay: String) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let userCalendar = WeekdayUtility.calendar(firstWeekday: weekStartDay)
        
        // Get start of current week
        let weekStart = userCalendar.date(from: userCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let today = calendar.startOfDay(for: now)
        
        var dates: [Date] = []
        for weekday in weekdays {
            // Calculate date for this weekday in current week
            // We need to find the next occurrence of this weekday from week start
            let weekStartWeekday = calendar.component(.weekday, from: weekStart)
            var daysToAdd = weekday - weekStartWeekday
            if daysToAdd < 0 {
                daysToAdd += 7
            }
            guard let weekdayDate = calendar.date(byAdding: .day, value: daysToAdd, to: weekStart) else { continue }
            let dayStart = calendar.startOfDay(for: weekdayDate)
            
            // Only include dates that haven't passed (today or future)
            if dayStart >= today {
                dates.append(dayStart)
            }
        }
        
        return dates.sorted()
    }
    
    // Remove all reminders for this ideal
    private func removeAllReminders() {
        // Remove new system reminders
        for reminderId in reminderIds {
            if let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder {
                try? eventStore.remove(reminder, commit: false)
            }
        }
        
        // Remove legacy reminder
        if let legacyId = reminderId, let reminder = eventStore.calendarItem(withIdentifier: legacyId) as? EKReminder {
            try? eventStore.remove(reminder, commit: false)
        }
        
        try? eventStore.commit()
    }
    
    // Create/update reminders for selected days. Reminders are only removed when the user deselects a day or turns off reminders (never just because the date passed).
    private func updateReminders(weekStartDay: String, completion: @escaping (Bool) -> Void) {
        let targetCalendar = NotificationManager.idealWeekReminderCalendar(eventStore: eventStore)
            ?? eventStore.defaultCalendarForNewReminders()
        guard let calendarToUse = targetCalendar else {
            reminderError = "No reminder calendar available. Please check your Calendar app settings."
            completion(false)
            return
        }
        
        let calendar = Calendar.current

        // Source-of-truth groups (drops empty-day groups, normalized).
        let model = modelSchedules()
        guard !model.isEmpty else {
            // Reminder toggle on but no valid group → treat as "no reminder": clear all.
            removeAllReminders()
            self.reminderIds = []
            persistIdeal(scheduledDays: [], reminderTime: 0, reminderSchedules: [], reminderIds: [], uId: Auth.auth().currentUser?.uid ?? "")
            completion(true)
            return
        }

        // A reminder slot is uniquely a (weekday, hour, minute) so the same weekday can carry
        // several reminder times across groups.
        func slotKey(weekday: Int, hour: Int, minute: Int) -> Int { weekday * 10000 + hour * 100 + minute }

        struct DesiredOccurrence { let key: Int; let date: Date; let dueComps: DateComponents }
        var selectedKeys: Set<Int> = []   // all selected slots (incl. past-this-week) → decides keep vs remove
        var desired: [DesiredOccurrence] = []  // future occurrences to create/update
        let nowDate = Date()
        for schedule in model {
            let hour = Int(schedule.time) / 3600
            let minute = (Int(schedule.time) % 3600) / 60
            for weekday in schedule.days {
                selectedKeys.insert(slotKey(weekday: weekday, hour: hour, minute: minute))
            }
            let dates = getDatesForWeekdays(Set(schedule.days), weekStartDay: weekStartDay)
            for date in dates {
                guard let reminderDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) else { continue }
                if reminderDate < nowDate { continue }
                let weekday = calendar.component(.weekday, from: reminderDate)
                let dueComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
                desired.append(DesiredOccurrence(key: slotKey(weekday: weekday, hour: hour, minute: minute), date: reminderDate, dueComps: dueComps))
            }
        }

        let oldReminderIds = Set(reminderIds)
        var updatedReminderIds: [String] = []

        // Map existing reminders by slot key, detected via alarm date then dueDateComponents
        // (which persist even if EventKit strips the alarm on completion). Unidentifiable
        // reminders are PRESERVED — data loss is worse than keeping an orphan.
        var existingByKey: [Int: String] = [:]
        var preservedUnknownIds: [String] = []
        for oldId in oldReminderIds {
            guard let r = eventStore.calendarItem(withIdentifier: oldId) as? EKReminder else { continue }
            let detectedDate: Date? = r.alarms?.first?.absoluteDate ?? r.dueDateComponents?.date
            guard let d = detectedDate else {
                preservedUnknownIds.append(oldId)
                continue
            }
            let comps = calendar.dateComponents([.weekday, .hour, .minute], from: d)
            let key = slotKey(weekday: comps.weekday ?? 0, hour: comps.hour ?? 0, minute: comps.minute ?? 0)
            guard selectedKeys.contains(key) else { continue } // slot no longer selected → cleanup removes it
            if existingByKey[key] == nil { existingByKey[key] = oldId }
            // duplicate slot → falls through to cleanup
        }

        do {
            // Create/update one reminder per future slot (dedup overlapping groups by key).
            var handledKeys: Set<Int> = []
            for occ in desired {
                guard handledKeys.insert(occ.key).inserted else { continue }
                if let existingId = existingByKey[occ.key],
                   let existing = eventStore.calendarItem(withIdentifier: existingId) as? EKReminder {
                    existing.title = title
                    existing.notes = notes
                    existing.url = NotificationManager.idealTagURL(idealId: id)
                    existing.calendar = calendarToUse
                    existing.alarms?.removeAll()
                    existing.addAlarm(EKAlarm(absoluteDate: occ.date))
                    existing.dueDateComponents = occ.dueComps
                    try eventStore.save(existing, commit: false)
                    updatedReminderIds.append(existingId)
                } else {
                    let reminder = EKReminder(eventStore: eventStore)
                    reminder.title = title
                    reminder.notes = notes
                    reminder.url = NotificationManager.idealTagURL(idealId: id)
                    reminder.calendar = calendarToUse
                    reminder.addAlarm(EKAlarm(absoluteDate: occ.date))
                    reminder.dueDateComponents = occ.dueComps
                    try eventStore.save(reminder, commit: false)
                    updatedReminderIds.append(reminder.calendarItemIdentifier)
                }
            }

            // Keep existing reminders for still-selected slots whose date is in the past this
            // week (preserves historical record without re-creating).
            for (_, oldId) in existingByKey {
                if !updatedReminderIds.contains(oldId) { updatedReminderIds.append(oldId) }
            }

            // Preserve any reminders we couldn't identify.
            for oldId in preservedUnknownIds {
                if !updatedReminderIds.contains(oldId) { updatedReminderIds.append(oldId) }
            }

            // Remove: reminders for deselected slots AND duplicates.
            for oldId in oldReminderIds {
                if updatedReminderIds.contains(oldId) { continue }
                if let reminder = eventStore.calendarItem(withIdentifier: oldId) as? EKReminder {
                    try eventStore.remove(reminder, commit: false)
                }
            }

            // Remove legacy single reminder if it exists (migrating to new system).
            if let legacyId = reminderId {
                if let reminder = eventStore.calendarItem(withIdentifier: legacyId) as? EKReminder {
                    try eventStore.remove(reminder, commit: false)
                }
                reminderId = nil
            }

            try eventStore.commit()
            self.reminderIds = updatedReminderIds

            // Schedule was (re)created in this save → record the current doneCount as
            // the baseline so the row counts only completions made AFTER this point.
            self.scheduleBaselineDoneCount = self.doneCount

            // The reminderIds set changed (schedule edit) → re-seed lastSeen so the next
            // EKEventStoreChanged doesn't fire a spurious delta from comparing against
            // the OLD reminderIds' completion count.
            IdealReminderSyncService.shared.resyncLastSeen(idealId: self.id, reminderIds: updatedReminderIds)

            let mirror = Self.legacyMirror(from: model)
            self.persistIdeal(
                scheduledDays: mirror.days,
                reminderTime: mirror.time,
                reminderSchedules: model,
                reminderIds: updatedReminderIds,
                uId: Auth.auth().currentUser?.uid ?? ""
            )

            completion(true)
        } catch {
            reminderError = "Failed to save reminders: \(error.localizedDescription)"
            completion(false)
        }
    }
    
    /// Did the user actually change the schedule (days / time / toggle) in this edit session?
    /// When false, save flow skips `updateReminders` (which recreates/touches EKReminders)
    /// — doneCount-only edits flow through delta sync without disturbing the reminders.
    private var scheduleChanged: Bool {
        if setReminder != originalSetReminder { return true }
        if !setReminder { return false }
        return modelSchedules() != originalSchedules
    }

    /// Did the user change cosmetic fields (title / notes) that are mirrored onto EKReminders?
    /// When true but `scheduleChanged` is false, we do a lightweight in-place patch of the
    /// existing reminders instead of running the full updateReminders recreation pass.
    private var reminderContentChanged: Bool {
        title != originalTitle || notes != originalNotes
    }

    /// Patch title/notes on each existing EKReminder without recreating them. Cheap;
    /// only runs when reminderContentChanged && !scheduleChanged. Idempotent.
    private func patchRemindersContent() {
        guard !reminderIds.isEmpty else { return }
        let store = self.eventStore
        for id in reminderIds {
            guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else { continue }
            var didChange = false
            if r.title != title { r.title = title; didChange = true }
            if r.notes != notes { r.notes = notes; didChange = true }
            if didChange { try? store.save(r, commit: false) }
        }
        try? store.commit()
    }

    /// Reset original-state snapshots to the current values. Call after a successful save
    /// so subsequent saves in the same edit session compute deltas relative to the new state.
    private func refreshOriginals() {
        originalDoneCount = doneCount
        originalSchedules = modelSchedules()
        originalSetReminder = setReminder
        originalTitle = title
        originalNotes = notes
    }

    func save(weekStartDay: String = WeekdayUtility.defaultWeekStartDay, completion: @escaping (Bool) -> Void = { _ in }){

        guard canSave else {
            completion(false)
            return
        }
        guard !isSaving else {
            // In-flight save owns the UI outcome — a second tap must not paint
            // an "Unable to save" alert over a save that is succeeding (same
            // race as the New Ideal duplicate bug, 2026-07-15).
            return
        }
        guard let uId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        isSaving = true

        // doneCount-only path: when setReminder is on but the schedule wasn't edited,
        // skip the heavy updateReminders pass entirely. Just persist + let the delta
        // sync in persistIdeal handle the doneCount change. This avoids the "undo
        // recreates reminders" bug — completion changes never touch reminderIds.
        // Cosmetic edits (title/notes) are mirrored onto existing reminders in-place.
        if setReminder && !scheduleChanged {
            if reminderContentChanged {
                patchRemindersContent()
            }
            let model = modelSchedules()
            let mirror = Self.legacyMirror(from: model)
            persistIdeal(
                scheduledDays: mirror.days,
                reminderTime: mirror.time,
                reminderSchedules: model,
                reminderIds: reminderIds,
                uId: uId
            )
            refreshOriginals()
            self.isSaving = false
            completion(true)
            return
        }

        // New reminder system
        if setReminder {
            // Check authorization status first
            let authStatus = EKEventStore.authorizationStatus(for: .reminder)
            
            if authStatus == .denied || authStatus == .restricted {
                self.reminderError = "Reminder access is denied. Please enable it in Settings > The Ideal Week > Reminders."
                self.isSaving = false
                completion(false)
                return
            }
            
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToReminders { [weak self] granted, error in
                    guard let self = self else {
                        DispatchQueue.main.async {
                            completion(false)
                        }
                        return
                    }
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else {
                            completion(false)
                            return
                        }
                        if granted && error == nil {
                            self.updateReminders(weekStartDay: weekStartDay) { [weak self] success in
                                if success { self?.refreshOriginals() }
                                self?.isSaving = false
                                completion(success)
                            }
                        } else {
                            let errorMsg = error?.localizedDescription ?? "Reminder access denied"
                            AppLogger.error(AppLogger.notifications, "Error requesting reminder access: \(errorMsg)")
                            self.reminderError = "Please grant reminder access in Settings to use this feature."
                            self.isSaving = false
                            completion(false)
                        }
                    }
                }
            } else {
                // For iOS < 17
                if authStatus == .authorized {
                    updateReminders(weekStartDay: weekStartDay) { [weak self] success in
                        if success { self?.refreshOriginals() }
                        self?.isSaving = false
                        completion(success)
                    }
                } else {
                    eventStore.requestAccess(to: .reminder) { [weak self] granted, error in
                        guard let self = self else {
                            DispatchQueue.main.async {
                                completion(false)
                            }
                            return
                        }
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else {
                                completion(false)
                                return
                            }
                            if granted && error == nil {
                                self.updateReminders(weekStartDay: weekStartDay) { [weak self] success in
                                    if success { self?.refreshOriginals() }
                                    self?.isSaving = false
                                    completion(success)
                                }
                            } else {
                                let errorMsg = error?.localizedDescription ?? "Reminder access denied"
                                AppLogger.error(AppLogger.notifications, "Error requesting reminder access: \(errorMsg)")
                                self.reminderError = "Please grant reminder access in Settings to use this feature."
                                self.isSaving = false
                                completion(false)
                            }
                        }
                    }
                }
            }
        } else {
            if preserveHiddenScheduleOnSave {
                let model = modelSchedules()
                let mirror = Self.legacyMirror(from: model)
                self.persistIdeal(
                    scheduledDays: mirror.days,
                    reminderTime: mirror.time,
                    reminderSchedules: model,
                    reminderIds: reminderIds,
                    uId: uId
                )
            } else {
                // No reminder selected - remove all existing reminders
                removeAllReminders()
                self.reminderIds = []
                // If ideal is being set to inactive, remove reminders
                if !self.active {
                    NotificationManager.removeRemindersForIdeal(reminderIds: self.reminderIds, legacyReminderId: self.reminderId)
                }
                self.persistIdeal(scheduledDays: [], reminderTime: 0, reminderSchedules: [], reminderIds: [], uId: uId)
            }
            refreshOriginals()
            self.isSaving = false
            completion(true)
        }
    }

    private func persistIdeal(reminderId: String? = nil, scheduledDays: [Int] = [], reminderTime: TimeInterval = 0, reminderSchedules: [ReminderSchedule] = [], reminderIds: [String] = [], uId: String) {
        let documentRef = db.collection("users")
            .document(uId)
            .collection("ideals")
            .document(self.id)
        
        // Capture delta + decrease flag synchronously at the top. Subsequent calls (some
        // async) must NOT re-read self.originalDoneCount — the caller may have already
        // run refreshOriginals() before our async Firestore callbacks fire, which would
        // collapse the delta to 0 and skip the reminder sync.
        let doneCountDelta = self.doneCount - originalDoneCount
        let doneCountDecreased = doneCountDelta < 0
        let capturedDoneCount = self.doneCount
        let idealId = self.id

        if doneCountDecreased {
            // Fetch current ideal to get secondCompletionDate
            documentRef.getDocument { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    AppLogger.error(AppLogger.firestore, "[IdealEditViewViewModel] Error fetching ideal for decrement: \(error.localizedDescription)")
                    // Fallback: still apply the decrement transformation using the locally-
                    // tracked originals (best-effort approximation of server state). Saving
                    // without this transformation would leave a stale rollback marker that
                    // corrupts future decrements.
                    self.saveDecrementFallback(reminderId: reminderId, scheduledDays: scheduledDays, reminderTime: reminderTime, reminderSchedules: reminderSchedules, reminderIds: reminderIds, capturedDoneCount: capturedDoneCount, uId: uId)
                    Self.applyDeltaIfNeeded(idealId: idealId, reminderIds: reminderIds, delta: doneCountDelta)
                    return
                }

                guard let data = snapshot?.data() else {
                    // Same fallback: do the decrement transformation with local originals.
                    self.saveDecrementFallback(reminderId: reminderId, scheduledDays: scheduledDays, reminderTime: reminderTime, reminderSchedules: reminderSchedules, reminderIds: reminderIds, capturedDoneCount: capturedDoneCount, uId: uId)
                    Self.applyDeltaIfNeeded(idealId: idealId, reminderIds: reminderIds, delta: doneCountDelta)
                    return
                }

                // Get current secondCompletionDate
                let secondCompletionDate = data["secondCompletionDate"] as? TimeInterval

                // Create ideal with secondCompletionDate copied to lastCompletedDate
                // When decrementing, copy secondCompletionDate to lastCompletedDate and clear secondCompletionDate
                let itemCopy = Ideal(
                    id: self.id,
                    category: self.category,
                    title: self.title,
                    notes: self.notes,
                    scheduleDateTime: self.scheduleDateTimeDate.timeIntervalSince1970,
                    createdDate: self.createdDate,
                    targetCount: self.targetCount,
                    doneCount: capturedDoneCount,
                    active: self.active,
                    reviewScore: self.reviewScore,
                    reminderId: reminderId,
                    scheduledDays: scheduledDays,
                    reminderTime: reminderTime,
                    reminderSchedules: reminderSchedules,
                    reminderIds: reminderIds,
                    wishlistEnabled: self.wishlistEnabled,
                    plannedFromWishlistAt: self.plannedFromWishlistAt,
                    plannedTarget: self.plannedTarget,
                    lastCompletedDate: secondCompletionDate,
                    secondCompletionDate: nil,
                    startDate: self.startDate,
                    sourceIdealId: self.sourceIdealId,
                    locationAddress: self.locationAddress,
                    scheduleBaselineDoneCount: self.scheduleBaselineDoneCount
                )

                // updateData (not setData): preserves unknown server fields. Use the
                // helper so nil-marked optional fields (e.g. secondCompletionDate cleared
                // on decrement) actually get deleted on the server instead of omitted.
                documentRef.updateData(Self.updateDictionary(from: itemCopy))
                Self.applyDeltaIfNeeded(idealId: idealId, reminderIds: reminderIds, delta: doneCountDelta)
            }
        } else {
            // No decrement, save normally
            saveIdealDirectly(reminderId: reminderId, scheduledDays: scheduledDays, reminderTime: reminderTime, reminderSchedules: reminderSchedules, reminderIds: reminderIds, uId: uId)
            Self.applyDeltaIfNeeded(idealId: idealId, reminderIds: reminderIds, delta: doneCountDelta)
        }
    }

    /// Helper: kick the EventKit delta apply for an ideal if the delta is non-zero.
    /// Static so it can be called from inside async callbacks without recapturing self.
    private static func applyDeltaIfNeeded(idealId: String, reminderIds: [String], delta: Int) {
        guard delta != 0, !reminderIds.isEmpty else { return }
        IdealReminderSyncService.shared.applyDoneCountDelta(
            idealId: idealId,
            reminderIds: reminderIds,
            delta: delta
        )
    }

    /// Decrement fallback: invoked when the live `getDocument` read fails. Performs the
    /// decrement transformation using locally-tracked originals (best approximation of
    /// server state at edit-open time): copies originalSecondCompletionDate to lastCompletedDate
    /// and clears secondCompletionDate. Otherwise the rollback marker would stay stale
    /// and corrupt the next decrement.
    private func saveDecrementFallback(reminderId: String? = nil, scheduledDays: [Int] = [], reminderTime: TimeInterval = 0, reminderSchedules: [ReminderSchedule] = [], reminderIds: [String] = [], capturedDoneCount: Int, uId: String) {
        let itemCopy = Ideal(
            id: self.id,
            category: self.category,
            title: self.title,
            notes: self.notes,
            scheduleDateTime: self.scheduleDateTimeDate.timeIntervalSince1970,
            createdDate: self.createdDate,
            targetCount: self.targetCount,
            doneCount: capturedDoneCount,
            active: self.active,
            reviewScore: self.reviewScore,
            reminderId: reminderId,
            scheduledDays: scheduledDays,
            reminderTime: reminderTime,
            reminderSchedules: reminderSchedules,
            reminderIds: reminderIds,
            wishlistEnabled: self.wishlistEnabled,
            plannedFromWishlistAt: self.plannedFromWishlistAt,
            plannedTarget: self.plannedTarget,
            lastCompletedDate: originalSecondCompletionDate, // shift originalSecond → last
            secondCompletionDate: nil,                       // clear rollback marker
            startDate: self.startDate,
            sourceIdealId: self.sourceIdealId,
            locationAddress: self.locationAddress,
            scheduleBaselineDoneCount: self.scheduleBaselineDoneCount
        )
        db.collection("users")
            .document(uId)
            .collection("ideals")
            .document(self.id)
            .updateData(Self.updateDictionary(from: itemCopy))
    }

    /// Build the Firestore update dictionary from an `Ideal`. `Ideal.encode(to:)` uses
    /// `encodeIfPresent` for nullable fields, which means a nil value is OMITTED from the
    /// dictionary rather than serialized. With `updateData`, omitted == "leave server value
    /// untouched", which silently breaks legitimate "clear this field" intents (e.g. the
    /// decrement path sets `secondCompletionDate = nil` to clear the rollback marker).
    ///
    /// This helper explicitly maps nil optionals to `FieldValue.delete()` so updateData
    /// actually clears them on the server. Pair with `updateData(_:)` for forward-compat
    /// (preserves unknown fields added by future schema migrations).
    private static func updateDictionary(from item: Ideal) -> [String: Any] {
        var dict = item.asDictionary()
        if item.reviewScore == nil { dict["reviewScore"] = FieldValue.delete() }
        if item.reminderId == nil { dict["reminderId"] = FieldValue.delete() }
        if item.plannedTarget == nil { dict["plannedTarget"] = FieldValue.delete() }
        if item.lastCompletedDate == nil { dict["lastCompletedDate"] = FieldValue.delete() }
        if item.secondCompletionDate == nil { dict["secondCompletionDate"] = FieldValue.delete() }
        if item.sourceIdealId == nil { dict["sourceIdealId"] = FieldValue.delete() }
        if item.locationAddress == nil { dict["locationAddress"] = FieldValue.delete() }
        return dict
    }
    
    private func saveIdealDirectly(reminderId: String? = nil, scheduledDays: [Int] = [], reminderTime: TimeInterval = 0, reminderSchedules: [ReminderSchedule] = [], reminderIds: [String] = [], uId: String) {
        // Preserve existing completion dates if doneCount hasn't changed
        let itemCopy = Ideal(
            id: self.id,
            category: self.category,
            title: self.title,
            notes: self.notes,
            scheduleDateTime: self.scheduleDateTimeDate.timeIntervalSince1970,
            createdDate: self.createdDate,
            targetCount: self.targetCount,
            doneCount: self.doneCount,
            active: self.active,
            reviewScore: self.reviewScore,
            reminderId: reminderId,
            scheduledDays: scheduledDays,
            reminderTime: reminderTime,
            reminderSchedules: reminderSchedules,
            reminderIds: reminderIds,
            wishlistEnabled: self.wishlistEnabled,
            plannedFromWishlistAt: self.plannedFromWishlistAt,
            plannedTarget: self.plannedTarget,
            lastCompletedDate: originalLastCompletedDate,
            secondCompletionDate: originalSecondCompletionDate,
            startDate: self.startDate,
            sourceIdealId: self.sourceIdealId,
            locationAddress: self.locationAddress,
            scheduleBaselineDoneCount: self.scheduleBaselineDoneCount
        )
        // Use updateData (not setData) — preserves unknown server fields. The helper maps
        // nil optionals to FieldValue.delete() so user-cleared fields (e.g. locationAddress
        // removed in edit view) propagate properly.
        db.collection("users")
            .document(uId)
            .collection("ideals")
            .document(self.id)
            .updateData(Self.updateDictionary(from: itemCopy))
    }
    
    var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return false }
        // If reminder is set, validate that at least one group has at least one day selected.
        if setReminder {
            guard schedules.contains(where: { !$0.days.isEmpty }) else { return false }
        }
        return true
    }
}
