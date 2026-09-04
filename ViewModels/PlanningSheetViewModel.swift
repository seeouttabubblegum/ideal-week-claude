//
//  PlanningSheetViewModel.swift
//  The Ideal Week
//
//  Created on 1/15/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// One reminder group in the planning UI (days + its own time). Identifiable so SwiftUI
/// `ForEach` can add/remove groups. Mirrors `EditableSchedule` used by the edit views.
struct PlannedReminderGroup: Identifiable, Equatable {
    let id: UUID
    var days: Set<Int>
    var time: Date

    init(id: UUID = UUID(), days: Set<Int> = [], time: Date? = nil) {
        self.id = id
        self.days = days
        self.time = time ?? (Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
    }
}

class PlanningSheetViewModel: ObservableObject {
    private static let defaultCategory = Category.allCases.first?.rawValue ?? "Fix"

    struct SavePlanningResult {
        let success: Bool
        let skippedDuplicates: [String]
        let validationDuplicates: [String]
    }

    @Published var selectedIdealIds: Set<String> = []
    @Published var selectedWishlistIdealIds: Set<String> = []
    @Published var planningReason: String = ""
    @Published var showReasonError: Bool = false
    @Published var reasonAlreadyProvided: Bool = false // When true, "Why plan early?" was already shown (e.g. right after PIN); skip reason at end of flow
    @Published var isSaving: Bool = false
    @Published var currentScreen: PlanningScreen = .selection
    /// Screens visited this session (for debug summary: "Again? | Wishlist | Missed Anything?").
    @Published var screensShownInSession: Set<PlanningScreen> = []
    @Published var plannedTargets: [String: String] = [:] // Map of ideal ID to planned target
    @Published var plannedCategories: [String: String] = [:] // Map of ideal ID to category (Again? list)
    @Published var wishlistCategories: [String: String] = [:] // Map of wishlist ideal ID to category
    @Published var wishlistTargets: [String: String] = [:] // Map of wishlist ideal ID to target
    @Published var plannedSchedules: [String: (setReminder: Bool, groups: [PlannedReminderGroup])] = [:] // Map of ideal ID to schedule data
    @Published var wishlistSchedules: [String: (setReminder: Bool, groups: [PlannedReminderGroup])] = [:] // Map of wishlist ideal ID to schedule data
    /// True when save completed successfully this session (before reset). Checked on dismiss to mark weekly flow complete.
    var didSaveThisSession = false
    private let db = Firestore.firestore()

    enum PlanningScreen: Hashable {
        case selectionSuccess  // Weekly prompt: Again? (1/2) — successful previous-week ideals
        case selection         // Again? (2/2 weekly) or Again? (Next? tab single screen) — non-successful / all
        case wishlist
        case createNewIdeals
        case reason
    }

    /// Past-week ideals the user has tapped "Move to later" on (sent to wishlist). Hidden from the Again? lists.
    @Published var movedToLaterIds: Set<String> = []

    /// Ideals with a "Move to later" write still in flight. Keyed per ideal so moving a second
    /// ideal while the first is in flight still works. Deliberately not @Published — re-entry is a
    /// silent no-op and must not re-render the row.
    private var movingToLaterIds: Set<String> = []
    
    /// Draft for a new ideal to create in the weekly-prompt "create new ideals" screen.
    struct NewIdealDraft: Identifiable {
        let id: String
        var title: String
        var category: String
        var targetCount: String
        var setReminder: Bool
        var groups: [PlannedReminderGroup]

        init(id: String = UUID().uuidString, title: String = "", category: String = PlanningSheetViewModel.defaultCategory, targetCount: String = "1", setReminder: Bool = false, groups: [PlannedReminderGroup] = [PlannedReminderGroup()]) {
            self.id = id
            self.title = title
            self.category = category
            self.targetCount = targetCount
            self.setReminder = setReminder
            self.groups = groups
        }
    }
    
    @Published var newIdealsToCreate: [NewIdealDraft] = []
    
    func toggleIdeal(_ idealId: String) {
        if selectedIdealIds.contains(idealId) {
            selectedIdealIds.remove(idealId)
        } else {
            selectedIdealIds.insert(idealId)
        }
    }
    
    func toggleWishlistIdeal(_ idealId: String) {
        if selectedWishlistIdealIds.contains(idealId) {
            selectedWishlistIdealIds.remove(idealId)
        } else {
            selectedWishlistIdealIds.insert(idealId)
        }
    }
    
    func canContinue() -> Bool {
        return !selectedIdealIds.isEmpty
    }
    
    /// Allow continuing to Missed Anything? so the third step always appears; Save there is still gated by hasAnythingToSave().
    func canContinueFromWishlist() -> Bool {
        return true
    }
    
    /// True if there is at least one new ideal draft with non-empty title.
    func hasNewIdealsToSave() -> Bool {
        return newIdealsToCreate.contains { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    /// True when user has selected ideals, selected wishlist, or new ideals to create.
    func hasAnythingToSave() -> Bool {
        return !selectedIdealIds.isEmpty || !selectedWishlistIdealIds.isEmpty || hasNewIdealsToSave()
    }
    
    func canSave(requireReason: Bool = true) -> Bool {
        guard hasAnythingToSave() else { return false }
        if requireReason {
            return !planningReason.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }
    
    /// Returns the planned category for an ideal, or the given default (e.g. ideal.category) if not set.
    func getPlannedCategory(for idealId: String, defaultCategory: String = PlanningSheetViewModel.defaultCategory) -> String {
        return plannedCategories[idealId] ?? defaultCategory
    }
    
    func setPlannedCategory(for idealId: String, value: String) {
        plannedCategories[idealId] = value
    }
    
    func getPlannedTarget(for idealId: String) -> String? {
        return plannedTargets[idealId]
    }
    
    
    // MARK: - Private target helpers

    /// Parse a target string dict entry to Int. "6+" → 6; missing/non-numeric → 1.
    private static func targetIntValue(in dict: [String: String], for id: String) -> Int {
        guard let s = dict[id] else { return 1 }
        return s == "6+" ? 6 : (Int(s) ?? 1)
    }

    /// Encode a clamped Int (1…6) to a target string. 6 → "6+".
    private static func targetStringValue(from value: Int) -> String {
        let v = max(1, min(6, value))
        return v == 6 ? "6+" : "\(v)"
    }

    // MARK: - Private schedule helper

    /// Returns a zeroed-out schedule with the reminder toggle off and one empty group (9:00 AM).
    private static func defaultSchedule() -> (setReminder: Bool, groups: [PlannedReminderGroup]) {
        (setReminder: false, groups: [PlannedReminderGroup()])
    }

    /// Build a planning group from an ideal's stored reminder group (for "pre-fill from this week").
    private static func plannedGroup(from model: ReminderSchedule) -> PlannedReminderGroup {
        let hour = Int(model.time) / 3600
        let minute = (Int(model.time) % 3600) / 60
        let time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return PlannedReminderGroup(days: Set(model.days), time: time)
    }

    /// Firestore payload for a set of planning groups: the multi-group `reminderSchedules`
    /// array plus the legacy `scheduledDays`/`reminderTime` mirror (union of days + first time).
    static func schedulePayload(groups: [PlannedReminderGroup]) -> (reminderSchedules: [[String: Any]], scheduledDays: [Int], reminderTime: TimeInterval) {
        let calendar = Calendar.current
        var model: [(days: [Int], time: TimeInterval)] = []
        for g in groups {
            let days = Array(g.days).sorted()
            guard !days.isEmpty else { continue }
            let hour = calendar.component(.hour, from: g.time)
            let minute = calendar.component(.minute, from: g.time)
            model.append((days, TimeInterval(hour * 3600 + minute * 60)))
        }
        let reminderSchedules = model.map { ["days": $0.days, "time": $0.time] as [String: Any] }
        let union = Array(Set(model.flatMap { $0.days })).sorted()
        let time = model.first?.time ?? 0
        return (reminderSchedules, union, time)
    }

    // Get planned target as integer (for counter)
    func getPlannedTargetInt(for idealId: String) -> Int {
        Self.targetIntValue(in: plannedTargets, for: idealId)
    }

    // Set planned target as integer (for counter) - minimum 1, maximum 6 stored as "6+"
    func setPlannedTargetInt(for idealId: String, value: Int) {
        plannedTargets[idealId] = Self.targetStringValue(from: value)
    }

    // Wishlist category methods
    func getWishlistCategory(for idealId: String) -> String {
        return wishlistCategories[idealId] ?? Self.defaultCategory
    }
    
    func setWishlistCategory(for idealId: String, value: String) {
        wishlistCategories[idealId] = value
    }
    
    
    func getWishlistTargetInt(for idealId: String) -> Int {
        Self.targetIntValue(in: wishlistTargets, for: idealId)
    }

    func setWishlistTargetInt(for idealId: String, value: Int) {
        wishlistTargets[idealId] = Self.targetStringValue(from: value)
    }
    
    // MARK: - Schedule methods for planned ideals

    func getPlannedSchedule(for idealId: String) -> (setReminder: Bool, groups: [PlannedReminderGroup]) {
        return plannedSchedules[idealId] ?? Self.defaultSchedule()
    }

    /// Ensures an ideal has a planned schedule entry with toggle off (so save clears reminders). Only sets when no entry exists.
    func ensurePlannedScheduleDefaultIfNeeded(for idealId: String) {
        guard plannedSchedules[idealId] == nil else { return }
        plannedSchedules[idealId] = Self.defaultSchedule()
    }

    /// Turn the planned reminder on/off. When turning on with no days yet, pre-fill the groups
    /// from the source ideal's existing schedule (the one we're cloning from).
    func setPlannedReminderEnabled(for idealId: String, enabled: Bool, prefillFrom ideal: Ideal) {
        var sched = getPlannedSchedule(for: idealId)
        sched.setReminder = enabled
        if enabled && !sched.groups.contains(where: { !$0.days.isEmpty }) {
            let prefill = ideal.effectiveReminderSchedules
            if !prefill.isEmpty {
                sched.groups = prefill.map { Self.plannedGroup(from: $0) }
            }
        }
        if sched.groups.isEmpty { sched.groups = [PlannedReminderGroup()] }
        plannedSchedules[idealId] = sched
    }

    func togglePlannedScheduledDay(for idealId: String, groupIndex: Int, weekday: Int) {
        var sched = getPlannedSchedule(for: idealId)
        guard sched.groups.indices.contains(groupIndex) else { return }
        if sched.groups[groupIndex].days.contains(weekday) {
            sched.groups[groupIndex].days.remove(weekday)
        } else {
            sched.groups[groupIndex].days.insert(weekday)
        }
        plannedSchedules[idealId] = sched
    }

    func setPlannedReminderTime(for idealId: String, groupIndex: Int, time: Date) {
        var sched = getPlannedSchedule(for: idealId)
        guard sched.groups.indices.contains(groupIndex) else { return }
        sched.groups[groupIndex].time = time
        plannedSchedules[idealId] = sched
    }

    func addPlannedReminderGroup(for idealId: String) {
        var sched = getPlannedSchedule(for: idealId)
        sched.groups.append(PlannedReminderGroup())
        plannedSchedules[idealId] = sched
    }

    func removePlannedReminderGroup(for idealId: String, groupIndex: Int) {
        var sched = getPlannedSchedule(for: idealId)
        guard sched.groups.indices.contains(groupIndex) else { return }
        sched.groups.remove(at: groupIndex)
        if sched.groups.isEmpty { sched.groups = [PlannedReminderGroup()] }
        plannedSchedules[idealId] = sched
    }

    // MARK: - Schedule methods for wishlist ideals

    func getWishlistSchedule(for idealId: String) -> (setReminder: Bool, groups: [PlannedReminderGroup]) {
        return wishlistSchedules[idealId] ?? Self.defaultSchedule()
    }

    func setWishlistReminderEnabled(for idealId: String, enabled: Bool, prefillFrom ideal: Ideal) {
        var sched = getWishlistSchedule(for: idealId)
        sched.setReminder = enabled
        if enabled && !sched.groups.contains(where: { !$0.days.isEmpty }) {
            let prefill = ideal.effectiveReminderSchedules
            if !prefill.isEmpty {
                sched.groups = prefill.map { Self.plannedGroup(from: $0) }
            }
        }
        if sched.groups.isEmpty { sched.groups = [PlannedReminderGroup()] }
        wishlistSchedules[idealId] = sched
    }

    func toggleWishlistScheduledDay(for idealId: String, groupIndex: Int, weekday: Int) {
        var sched = getWishlistSchedule(for: idealId)
        guard sched.groups.indices.contains(groupIndex) else { return }
        if sched.groups[groupIndex].days.contains(weekday) {
            sched.groups[groupIndex].days.remove(weekday)
        } else {
            sched.groups[groupIndex].days.insert(weekday)
        }
        wishlistSchedules[idealId] = sched
    }

    func setWishlistReminderTime(for idealId: String, groupIndex: Int, time: Date) {
        var sched = getWishlistSchedule(for: idealId)
        guard sched.groups.indices.contains(groupIndex) else { return }
        sched.groups[groupIndex].time = time
        wishlistSchedules[idealId] = sched
    }

    func addWishlistReminderGroup(for idealId: String) {
        var sched = getWishlistSchedule(for: idealId)
        sched.groups.append(PlannedReminderGroup())
        wishlistSchedules[idealId] = sched
    }

    func removeWishlistReminderGroup(for idealId: String, groupIndex: Int) {
        var sched = getWishlistSchedule(for: idealId)
        guard sched.groups.indices.contains(groupIndex) else { return }
        sched.groups.remove(at: groupIndex)
        if sched.groups.isEmpty { sched.groups = [PlannedReminderGroup()] }
        wishlistSchedules[idealId] = sched
    }

    // MARK: - New ideals to create (weekly prompt third screen)

    func addNewIdealDraft() {
        newIdealsToCreate.append(NewIdealDraft())
    }

    func updateNewIdealDraft(id: String, title: String? = nil, category: String? = nil, targetCount: String? = nil, setReminder: Bool? = nil) {
        guard let index = newIdealsToCreate.firstIndex(where: { $0.id == id }) else { return }
        var draft = newIdealsToCreate[index]
        if let title = title { draft.title = title }
        if let category = category { draft.category = category }
        if let targetCount = targetCount { draft.targetCount = targetCount }
        if let setReminder = setReminder {
            draft.setReminder = setReminder
            if draft.groups.isEmpty { draft.groups = [PlannedReminderGroup()] }
        }
        newIdealsToCreate[index] = draft
    }

    func removeNewIdealDraft(id: String) {
        newIdealsToCreate.removeAll { $0.id == id }
    }

    func toggleNewIdealDraftScheduledDay(draftId: String, groupIndex: Int, weekday: Int) {
        guard let index = newIdealsToCreate.firstIndex(where: { $0.id == draftId }) else { return }
        var draft = newIdealsToCreate[index]
        guard draft.groups.indices.contains(groupIndex) else { return }
        if draft.groups[groupIndex].days.contains(weekday) {
            draft.groups[groupIndex].days.remove(weekday)
        } else {
            draft.groups[groupIndex].days.insert(weekday)
        }
        newIdealsToCreate[index] = draft
    }

    func setNewIdealDraftReminderTime(draftId: String, groupIndex: Int, time: Date) {
        guard let index = newIdealsToCreate.firstIndex(where: { $0.id == draftId }) else { return }
        var draft = newIdealsToCreate[index]
        guard draft.groups.indices.contains(groupIndex) else { return }
        draft.groups[groupIndex].time = time
        newIdealsToCreate[index] = draft
    }

    func addNewIdealDraftReminderGroup(draftId: String) {
        guard let index = newIdealsToCreate.firstIndex(where: { $0.id == draftId }) else { return }
        newIdealsToCreate[index].groups.append(PlannedReminderGroup())
    }

    func removeNewIdealDraftReminderGroup(draftId: String, groupIndex: Int) {
        guard let index = newIdealsToCreate.firstIndex(where: { $0.id == draftId }) else { return }
        guard newIdealsToCreate[index].groups.indices.contains(groupIndex) else { return }
        newIdealsToCreate[index].groups.remove(at: groupIndex)
        if newIdealsToCreate[index].groups.isEmpty { newIdealsToCreate[index].groups = [PlannedReminderGroup()] }
    }
    
    /// Returns the start of next week (user's week start day) as TimeInterval since 1970.
    private func nextWeekStartTimestamp(weekStartDay: String) -> TimeInterval {
        WeekdayUtility.nextWeekRange(weekStartDay: weekStartDay).start.timeIntervalSince1970
    }
    
    /// Build Firestore data for a cloned ideal.
    /// - forCurrentWeek = true (weekly prompt): write into current week (week-start startDate).
    /// - forCurrentWeek = false (Next? tab): write into next week (next-week-start startDate).
    private func cloneData(for ideal: Ideal, weekStartDay: String, forCurrentWeek: Bool = false) -> [String: Any] {
        let targetStart = forCurrentWeek
            ? WeekdayUtility.weekStart(weekStartDay: weekStartDay).timeIntervalSince1970
            : nextWeekStartTimestamp(weekStartDay: weekStartDay)
        let createdTimestamp = forCurrentWeek ? Date().timeIntervalSince1970 : targetStart
        let idealId = ideal.id

        // Schedule does NOT carry forward from the source ideal — the user
        // must explicitly opt in via the planning sheet's "Schedule a
        // Reminder?" toggle. Previously the source schedule was copied
        // unconditionally, which surfaced stale "NEXT: 6:59 A TUE" labels on
        // freshly-planned ideals (often pointing at past times because the
        // user planned later in the day than the inherited reminder).
        var clonedScheduledDays: [Int] = []
        var clonedReminderTime: TimeInterval = 0
        var clonedReminderSchedules: [[String: Any]] = []
        if let schedule = plannedSchedules[idealId], schedule.setReminder {
            let payload = Self.schedulePayload(groups: schedule.groups)
            clonedScheduledDays = payload.scheduledDays
            clonedReminderTime = payload.reminderTime
            clonedReminderSchedules = payload.reminderSchedules
        }

        var data: [String: Any] = [
            "category": plannedCategories[idealId] ?? ideal.category,
            "title": ideal.title,
            "notes": ideal.notes,
            "scheduleDateTime": ideal.scheduleDateTime,
            "scheduledDays": clonedScheduledDays,
            "reminderTime": clonedReminderTime,
            "reminderSchedules": clonedReminderSchedules,
            "reminderIds": [String](),     // stale EventKit IDs — drop
            "createdDate": createdTimestamp,
            "startDate": targetStart,
            "targetCount": plannedTargets[idealId] ?? ideal.targetCount,
            "doneCount": 0,
            "toNextWeek": false,
            "active": true,
            "platform": ideal.platform,
            "wishlistEnabled": false,
            "scheduleBaselineDoneCount": 0   // fresh clone starts at doneCount 0
        ]
        if !forCurrentWeek {
            data["sourceIdealId"] = idealId
        }
        if let reviewScore = ideal.reviewScore { data["reviewScore"] = reviewScore }
        // Legacy single-reminder ID is intentionally NOT carried over.
        return data
    }
    
    func savePlanning(selectedIdeals: [Ideal], selectedWishlistIdeals: [Ideal], weekStartDay: String, requireReason: Bool = true, isWeeklyPrompt: Bool = false, completion: @escaping (SavePlanningResult) -> Void) {
        guard !isSaving else {
            completion(SavePlanningResult(success: false, skippedDuplicates: [], validationDuplicates: []))
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(SavePlanningResult(success: false, skippedDuplicates: [], validationDuplicates: []))
            return
        }
        
        guard canSave(requireReason: requireReason) else {
            if requireReason {
                showReasonError = true
            }
            completion(SavePlanningResult(success: false, skippedDuplicates: [], validationDuplicates: []))
            return
        }
        
        isSaving = true
        let idealsRef = db.collection("users").document(uid).collection("ideals")
        let plannedRecordsRef = db.collection("users").document(uid).collection(PlannedIdealRecord.collectionName)
        
        let forCurrentWeek = isWeeklyPrompt
        let currentWeekStart = WeekdayUtility.weekStart(weekStartDay: weekStartDay).timeIntervalSince1970
        let nextWeekStart = nextWeekStartTimestamp(weekStartDay: weekStartDay)
        let targetStart = forCurrentWeek ? currentWeekStart : nextWeekStart
        let targetEnd = targetStart + (7 * 24 * 3600)
        let newIdealCreatedDate = forCurrentWeek ? Date().timeIntervalSince1970 : targetStart
        
        // Next? flow fully replaces existing plan records before writing the new plan set.
        let flushAndSave: (Set<String>, [String], Set<String>) -> Void = { [weak self] existingTargetWeekKeys, existingPlannedRecordIds, existingTargetWeekPlannedIdealIds in
            guard let self = self else { return }
            let batch = db.batch()
            var newPlannedIds: Set<String> = []
            // For Next? tab (replace mode), start empty — old plan keys shouldn't block
            // re-creating the same ideals. For weekly prompt, use existing keys to avoid duplicates.
            var protectedKeys: Set<String> = forCurrentWeek ? existingTargetWeekKeys : []
            var skippedDuplicates: [String] = []
            var operationsCount = 0
            
            var requestedKeys: [String] = []
            var requestedLabelByKey: [String: String] = [:]
            func trackRequestedDuplicateKey(category: String, title: String) {
                guard let key = IdealDuplicateGuard.duplicateKey(category: category, title: title) else { return }
                requestedKeys.append(key)
                if requestedLabelByKey[key] == nil {
                    requestedLabelByKey[key] = IdealDuplicateGuard.displayLabel(title: title, category: category)
                }
            }

            for ideal in selectedIdeals {
                let plannedCategory = plannedCategories[ideal.id] ?? ideal.category
                let plannedTitle = ideal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                trackRequestedDuplicateKey(category: plannedCategory, title: plannedTitle)
            }

            for ideal in selectedWishlistIdeals {
                let idealId = ideal.id
                let finalCategory = wishlistCategories[idealId]?.isEmpty == false ? (wishlistCategories[idealId] ?? ideal.category) : ideal.category
                let finalTitle = ideal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                trackRequestedDuplicateKey(category: finalCategory, title: finalTitle)
            }

            for draft in newIdealsToCreate {
                let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { continue }
                trackRequestedDuplicateKey(category: draft.category, title: trimmedTitle)
            }

            let duplicateRequestedKeys = Set(Dictionary(grouping: requestedKeys, by: { $0 }).filter { $0.value.count > 1 }.keys)
            if !duplicateRequestedKeys.isEmpty {
                let validationDuplicates = duplicateRequestedKeys
                    .compactMap { requestedLabelByKey[$0] }
                    .sorted()

                DispatchQueue.main.async {
                    self.isSaving = false
                    completion(SavePlanningResult(success: false, skippedDuplicates: [], validationDuplicates: validationDuplicates))
                }
                return
            }
            
            // Create a clone for each selected existing ideal.
            for ideal in selectedIdeals {
                let plannedCategory = plannedCategories[ideal.id] ?? ideal.category
                let plannedTitle = ideal.title.trimmingCharacters(in: .whitespacesAndNewlines)

                if let key = IdealDuplicateGuard.duplicateKey(category: plannedCategory, title: plannedTitle) {
                    if protectedKeys.contains(key) {
                        skippedDuplicates.append(IdealDuplicateGuard.displayLabel(title: plannedTitle, category: plannedCategory))
                        continue
                    }
                    protectedKeys.insert(key)
                }

                var cloneDict = cloneData(for: ideal, weekStartDay: weekStartDay, forCurrentWeek: forCurrentWeek)
                let newRef = idealsRef.document()
                cloneDict["id"] = newRef.documentID
                cloneDict["category"] = plannedCategory
                cloneDict["title"] = plannedTitle
                batch.setData(cloneDict, forDocument: newRef)
                operationsCount += 1
                
                newPlannedIds.insert(newRef.documentID)
            }
            
            // Handle wishlist selections by moving the same wishlist item in-place.
            // (Only regular ideals use clone creation for Next? planning.)
            for ideal in selectedWishlistIdeals {
                let idealId = ideal.id
                let finalCategory = wishlistCategories[idealId]?.isEmpty == false ? (wishlistCategories[idealId] ?? ideal.category) : ideal.category
                let finalTitle = ideal.title.trimmingCharacters(in: .whitespacesAndNewlines)

                if let key = IdealDuplicateGuard.duplicateKey(category: finalCategory, title: finalTitle) {
                    if protectedKeys.contains(key) {
                        skippedDuplicates.append(IdealDuplicateGuard.displayLabel(title: finalTitle, category: finalCategory))
                        continue
                    }
                    protectedKeys.insert(key)
                }

                let idealRef = idealsRef.document(idealId)
                var updateData: [String: Any] = [
                    "wishlistEnabled": false,
                    "startDate": targetStart,
                    "plannedFromWishlistAt": Date().timeIntervalSince1970
                ]

                if let category = wishlistCategories[idealId], !category.isEmpty {
                    updateData["category"] = category
                }
                if let target = wishlistTargets[idealId], !target.isEmpty {
                    updateData["targetCount"] = target
                }

                if let schedule = wishlistSchedules[idealId], schedule.setReminder {
                    let payload = Self.schedulePayload(groups: schedule.groups)
                    if !payload.reminderSchedules.isEmpty {
                        updateData["scheduledDays"] = payload.scheduledDays
                        updateData["reminderTime"] = payload.reminderTime
                        updateData["reminderSchedules"] = payload.reminderSchedules
                        // Record the baseline at schedule-creation so the row counts
                        // completions relative to now (wishlist items are doneCount 0,
                        // but write it explicitly for robustness).
                        updateData["scheduleBaselineDoneCount"] = ideal.doneCount
                    }
                }

                batch.updateData(updateData, forDocument: idealRef)
                operationsCount += 1

                newPlannedIds.insert(idealId)
            }
            
            // Create new ideals from "Missed Anything?".
            for draft in newIdealsToCreate {
                let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { continue }

                if let key = IdealDuplicateGuard.duplicateKey(category: draft.category, title: trimmedTitle) {
                    if protectedKeys.contains(key) {
                        skippedDuplicates.append(IdealDuplicateGuard.displayLabel(title: trimmedTitle, category: draft.category))
                        continue
                    }
                    protectedKeys.insert(key)
                }

                let newRef = idealsRef.document()
                var data: [String: Any] = [
                    "id": newRef.documentID,
                    "category": draft.category,
                    "title": trimmedTitle,
                    "notes": "",
                    "scheduleDateTime": 0,
                    "scheduledDays": [],
                    "reminderTime": 0,
                    "reminderSchedules": [[String: Any]](),
                    "reminderIds": [],
                    "createdDate": newIdealCreatedDate,
                    "startDate": targetStart,
                    "targetCount": draft.targetCount,
                    "doneCount": 0,
                    "toNextWeek": false,
                    "active": true,
                    "platform": "iOS",
                    "wishlistEnabled": false
                ]
                if draft.setReminder {
                    let payload = Self.schedulePayload(groups: draft.groups)
                    if !payload.reminderSchedules.isEmpty {
                        data["scheduledDays"] = payload.scheduledDays
                        data["reminderTime"] = payload.reminderTime
                        data["reminderSchedules"] = payload.reminderSchedules
                    }
                }
                batch.setData(data, forDocument: newRef)
                operationsCount += 1
                
                newPlannedIds.insert(newRef.documentID)
            }

            if !forCurrentWeek && !newPlannedIds.isEmpty {
                // Replace mode for Next? tab: clear previous plan only when new items are being saved.
                for docId in existingPlannedRecordIds {
                    batch.deleteDocument(plannedRecordsRef.document(docId))
                    operationsCount += 1
                }

                // Also remove old target-week planned ideals referenced by previous plan records.
                for idealId in existingTargetWeekPlannedIdealIds {
                    batch.deleteDocument(idealsRef.document(idealId))
                    operationsCount += 1
                }
            }
            
            // Persist planned IDs: Next? flow and weekly prompt both write to Plan DB.
            let now = Date().timeIntervalSince1970
            for idealId in newPlannedIds {
                let record = PlannedIdealRecord(id: idealId, startDate: targetStart, createdDate: now)
                batch.setData(record.asDictionary(), forDocument: plannedRecordsRef.document(idealId))
                operationsCount += 1
            }
            
            // Save QA if reason is provided.
            if requireReason && !planningReason.trimmingCharacters(in: .whitespaces).isEmpty {
                let qa = QA(
                    userId: uid,
                    question: "Why Plan in Advance?",
                    answer: planningReason.trimmingCharacters(in: .whitespaces)
                )
                let qaRef = db.collection("users")
                    .document(uid)
                    .collection("QA")
                    .document(qa.id)
                
                batch.setData(qa.asDictionary(), forDocument: qaRef)
                operationsCount += 1
            }

            if operationsCount == 0 {
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.didSaveThisSession = true
                    var seen: Set<String> = []
                    let uniqueSkipped = skippedDuplicates.filter { seen.insert($0).inserted }
                    completion(SavePlanningResult(success: true, skippedDuplicates: uniqueSkipped, validationDuplicates: []))
                }
                return
            }

            batch.commit { [weak self] error in
                DispatchQueue.main.async {
                    guard let self = self else {
                        completion(SavePlanningResult(success: false, skippedDuplicates: [], validationDuplicates: []))
                        return
                    }
                    if let error = error {
                        AppLogger.error(AppLogger.firestore, "Error saving planning: \(error.localizedDescription)")
                        self.isSaving = false
                        completion(SavePlanningResult(success: false, skippedDuplicates: [], validationDuplicates: []))
                    } else {
                        self.didSaveThisSession = true
                        var seen: Set<String> = []
                        let uniqueSkipped = skippedDuplicates.filter { seen.insert($0).inserted }
                        Self.deletePlanRecordsOutsideCurrentAndNextWeek(
                            plannedRecordsRef: plannedRecordsRef,
                            currentWeekStart: currentWeekStart,
                            nextWeekStart: nextWeekStart
                        ) { [weak self] _ in
                            // The in-flight window must stay open until the caller is told, or a
                            // second launch can start the multi-write while the prune is still going.
                            // Firestore delivers this on main — an extra async hop here would re-open it.
                            self?.isSaving = false
                            completion(SavePlanningResult(success: true, skippedDuplicates: uniqueSkipped, validationDuplicates: []))
                        }
                    }
                }
            }
        }
        
        if forCurrentWeek {
            IdealDuplicateGuard.fetchCurrentWeekKeys(userId: uid, weekStartDay: weekStartDay) { [weak self] result in
                switch result {
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.isSaving = false
                        AppLogger.error(AppLogger.firestore, "Error loading current-week ideals for duplicate check: \(error.localizedDescription)")
                        completion(SavePlanningResult(success: false, skippedDuplicates: [], validationDuplicates: []))
                    }
                case .success(let keys):
                    flushAndSave(keys, [], [])
                }
            }
        } else {
            // Next? tab: duplicate guard must check against NEXT-week plan set only (not current week).
            plannedRecordsRef.getDocuments { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.isSaving = false
                        AppLogger.error(AppLogger.firestore, "Error loading planned records for flush: \(error.localizedDescription)")
                        completion(SavePlanningResult(success: false, skippedDuplicates: [], validationDuplicates: []))
                    }
                    return
                }
                let docs = snapshot?.documents ?? []
                // Only next-week plan records (startDate in [N, N+7)) for replace and duplicate check.
                let nextWeekPlanRecordIds = docs.filter { doc in
                    let startDate = doc.data()["startDate"] as? TimeInterval ?? 0
                    return startDate >= targetStart && startDate < targetEnd
                }.map(\.documentID)
                let nextWeekPlanRecordIdSet = Set(nextWeekPlanRecordIds)

                idealsRef
                    .whereField("startDate", isGreaterThanOrEqualTo: targetStart)
                    .whereField("startDate", isLessThan: targetEnd)
                    .getDocuments { [weak self] targetSnapshot, targetError in
                    if let targetError {
                        DispatchQueue.main.async {
                            self?.isSaving = false
                            AppLogger.error(AppLogger.firestore, "Error loading target-week ideals for duplicate check: \(targetError.localizedDescription)")
                            completion(SavePlanningResult(success: false, skippedDuplicates: [], validationDuplicates: []))
                        }
                        return
                    }

                    let targetWeekDocs = targetSnapshot?.documents ?? []
                    // Ideal IDs that are already planned for next week (have a plan record with startDate N).
                    let existingTargetWeekPlannedIdealIds = Set(targetWeekDocs.compactMap { doc -> String? in
                        nextWeekPlanRecordIdSet.contains(doc.documentID) ? doc.documentID : nil
                    })
                    // Duplicate keys = keys of ideals ALREADY IN the next-week plan (block clones with same title+category).
                    let existingPlanKeys = Set(targetWeekDocs.compactMap { doc -> String? in
                        guard existingTargetWeekPlannedIdealIds.contains(doc.documentID) else { return nil }
                        let data = doc.data()
                        let wishlistEnabled = data["wishlistEnabled"] as? Bool ?? false
                        guard !wishlistEnabled else { return nil }
                        let category = data["category"] as? String ?? ""
                        let title = data["title"] as? String ?? ""
                        return IdealDuplicateGuard.duplicateKey(category: category, title: title)
                    })

                    flushAndSave(existingPlanKeys, nextWeekPlanRecordIds, existingTargetWeekPlannedIdealIds)
                }
            }
        }
    }
    
    func recordScreenShown(_ screen: PlanningScreen) {
        screensShownInSession.insert(screen)
    }

    func reset() {
        selectedIdealIds.removeAll()
        selectedWishlistIdealIds.removeAll()
        planningReason = ""
        showReasonError = false
        reasonAlreadyProvided = false
        currentScreen = .selection
        screensShownInSession.removeAll()
        isSaving = false
        didSaveThisSession = false
        plannedTargets.removeAll()
        plannedCategories.removeAll()
        wishlistCategories.removeAll()
        wishlistTargets.removeAll()
        plannedSchedules.removeAll()
        wishlistSchedules.removeAll()
        newIdealsToCreate.removeAll()
        movedToLaterIds.removeAll()
        movingToLaterIds.removeAll()
    }

    /// Add a copy of `ideal` as a wishlist item, then mark it locally hidden from Again? lists.
    /// Silently treats existing wishlist duplicates as success.
    func moveToLater(ideal: Ideal, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else { completion(false); return }
        guard !movingToLaterIds.contains(ideal.id) else { return }
        movingToLaterIds.insert(ideal.id)
        let idealsRef = db.collection("users").document(userId).collection("ideals")
        idealsRef.whereField("wishlistEnabled", isEqualTo: true).getDocuments { [weak self] snapshot, _ in
            guard let self = self else { completion(false); return }
            let existingKeys: Set<String> = Set(snapshot?.documents.compactMap { doc -> String? in
                let cat = doc.data()["category"] as? String ?? ""
                let title = doc.data()["title"] as? String ?? ""
                return IdealDuplicateGuard.duplicateKey(category: cat, title: title)
            } ?? [])
            if let key = IdealDuplicateGuard.duplicateKey(category: ideal.category, title: ideal.title),
               existingKeys.contains(key) {
                DispatchQueue.main.async {
                    self.movingToLaterIds.remove(ideal.id)
                    self.movedToLaterIds.insert(ideal.id)
                    completion(true)
                }
                return
            }
            let newId = UUID().uuidString
            let now = Date().timeIntervalSince1970
            let data: [String: Any] = [
                "id": newId,
                "title": ideal.title,
                "category": ideal.category,
                "wishlistEnabled": true,
                "startDate": 0,
                "createdDate": now,
                "active": true,
                "platform": "iOS",
                "doneCount": 0,
                "targetCount": ideal.targetCount,
                "notes": "",
                "scheduledDays": [] as [Int],
                "reminderTime": 0,
                "reminderIds": [] as [String],
                "plannedFromWishlistAt": 0
            ]
            idealsRef.document(newId).setData(data) { err in
                DispatchQueue.main.async {
                    // Must clear on failure too, or the row is wedged for the rest of the session.
                    self.movingToLaterIds.remove(ideal.id)
                    if err == nil {
                        self.movedToLaterIds.insert(ideal.id)
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }
        }
    }

    /// Deletes plan records whose startDate is not in current week [S, S+7) and not in next week [N, N+7). Keeps only S and N weeks.
    private static func deletePlanRecordsOutsideCurrentAndNextWeek(
        plannedRecordsRef: CollectionReference,
        currentWeekStart: TimeInterval,
        nextWeekStart: TimeInterval,
        completion: @escaping (Error?) -> Void
    ) {
        let sEnd = currentWeekStart + 7 * 24 * 3600
        let nEnd = nextWeekStart + 7 * 24 * 3600
        plannedRecordsRef.getDocuments { snapshot, error in
            if let error = error {
                completion(error)
                return
            }
            let docs = snapshot?.documents ?? []
            let toDelete = docs.filter { doc in
                let startDate = doc.data()["startDate"] as? TimeInterval ?? 0
                guard startDate > 0 else { return true }
                if startDate < currentWeekStart { return true }
                if startDate >= sEnd && startDate < nextWeekStart { return true }
                if startDate >= nEnd { return true }
                return false
            }.map(\.reference)
            guard !toDelete.isEmpty else {
                completion(nil)
                return
            }
            let batchSize = 500
            var index = toDelete.startIndex
            func runBatch() {
                let end = toDelete.index(index, offsetBy: batchSize, limitedBy: toDelete.endIndex) ?? toDelete.endIndex
                let chunk = Array(toDelete[index..<end])
                index = end
                let batch = plannedRecordsRef.firestore.batch()
                for ref in chunk {
                    batch.deleteDocument(ref)
                }
                batch.commit { err in
                    if let err = err {
                        completion(err)
                        return
                    }
                    if index >= toDelete.endIndex {
                        completion(nil)
                    } else {
                        runBatch()
                    }
                }
            }
            runBatch()
        }
    }
}
