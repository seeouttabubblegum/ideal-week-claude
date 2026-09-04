//
//  NewIdealViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import EventKit

class NewIdealViewViewModel: ObservableObject {
    private static let defaultCategory = Category.allCases.first?.rawValue ?? "Fix"

    @Published var title = ""
    @Published var category:String = defaultCategory
    @Published var notes = ""
    @Published var targetCount = "1"
    @Published var doneCount = 0
    @Published var scheduleDateTime = Date()
    @Published var showAlert = false
    @Published var alertMessage = "Please fill in all fields and select due date that is today and newer."
    @Published var active = true
    @Published var wishlistEnabled = false
    @Published var isSaving = false

    private let eventStore = EKEventStore()
    private let db = Firestore.firestore()
    
    var editingItemId: String? = nil // ID of item being edited, nil if creating new
    
    init(category:Category? = nil, wishlist: Bool = false, editingItem: Ideal? = nil){
        if let editingItem = editingItem {
            // Editing mode
            self.editingItemId = editingItem.id
            self.title = editingItem.title
            self.category = editingItem.category
            self.wishlistEnabled = editingItem.wishlistEnabled
            self.targetCount = editingItem.targetCount
        } else {
            // Creating mode
            self.category = category?.rawValue ?? Self.defaultCategory
            self.wishlistEnabled = wishlist
        }
    }
    
    /// Current week start timestamp (start of day) for the given week start day. Used for startDate on new ideals.
    private static func currentWeekStartTimestamp(weekStartDay: String?) -> TimeInterval {
        let day = weekStartDay ?? WeekdayUtility.defaultWeekStartDay
        return WeekdayUtility.weekStart(weekStartDay: day).timeIntervalSince1970
    }
    
    private func finishSave(_ success: Bool, completion: ((Bool) -> Void)?, alert: String? = nil) {
        DispatchQueue.main.async {
            self.isSaving = false
            if let alert {
                self.alertMessage = alert
                self.showAlert = true
            }
            completion?(success)
        }
    }

    private func shouldCheckCurrentWeekDuplicates() -> Bool {
        editingItemId == nil && !wishlistEnabled
    }

    func save(setReminder: Bool, weekStartDay: String? = nil, completion: ((Bool) -> Void)? = nil) {

        guard canSave else {
            finishSave(false, completion: completion)
            return
        }
        guard !isSaving else {
            // A save is already in flight and owns the UI outcome. Reporting a
            // failure here painted a bogus "Could not save ideal" alert over a
            // save that was actually succeeding, and the retry it invited wrote
            // a duplicate (client bug 2026-07-15) — swallow the extra tap.
            return
        }

        isSaving = true

        guard let uId = Auth.auth().currentUser?.uid else {
            finishSave(false, completion: completion, alert: "You need to be logged in to save this ideal.")
            return
        }

        let continueSave: () -> Void = { [weak self, uId, weekStartDay] in
            guard let self = self else {
                completion?(false)
                return
            }

            // Currently unreachable: NewIdealView.swift:15 holds setReminder as a
            // constant false and offers no UI to flip it. Anyone wiring up a
            // reminder toggle here must also bind scheduleDateTime, which that
            // view likewise leaves unbound (it would default to Date()).
            if setReminder {
                // Check authorization status first
                let authStatus = EKEventStore.authorizationStatus(for: .reminder)

                if authStatus == .denied || authStatus == .restricted {
                    self.finishSave(false, completion: completion, alert: "Reminder permission is disabled. Enable it in Settings or save without reminder.")
                    return
                }

                // Helper function to create and save reminder
                let createAndSaveReminder = { [weak self] in
                    guard let self = self else {
                        completion?(false)
                        return
                    }
                    // Decide the ideal id up-front so we can stamp the reminder
                    // with its ownership tag (used by the auto-expire sweep). For
                    // edits reuse the existing id; for new ideals mint one and
                    // pass it through to saveIdeal so the doc and tag agree.
                    let idealId = self.editingItemId ?? UUID().uuidString
                    let reminder = EKReminder(eventStore: self.eventStore)
                    reminder.title = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    reminder.notes = self.notes
                    reminder.url = NotificationManager.idealTagURL(idealId: idealId)
                    reminder.calendar = NotificationManager.idealWeekReminderCalendar(eventStore: self.eventStore)
                        ?? self.eventStore.defaultCalendarForNewReminders()
                    let alarm = EKAlarm(absoluteDate: self.scheduleDateTime)
                    reminder.addAlarm(alarm)

                    do {
                        try self.eventStore.save(reminder, commit: true)

                        let reminderId = reminder.calendarItemIdentifier
                        self.saveIdeal(withReminderId: reminderId, uId: uId, weekStartDay: weekStartDay, precomputedId: idealId)
                        self.finishSave(true, completion: completion)
                    } catch {
                        self.finishSave(false, completion: completion, alert: "Could not save reminder. Please try again.")
                    }
                }

                if #available(iOS 17.0, *) {
                    self.eventStore.requestFullAccessToReminders { [weak self] granted, error in
                        // EventKit calls back on a private queue; createAndSaveReminder
                        // reads @Published state, so hop to main before touching it.
                        DispatchQueue.main.async {
                            if granted && error == nil {
                                createAndSaveReminder()
                            } else {
                                self?.finishSave(false, completion: completion, alert: "Reminder permission was not granted.")
                            }
                        }
                    }
                } else {
                    // For iOS < 17
                    if authStatus == .authorized {
                        createAndSaveReminder()
                    } else {
                        self.eventStore.requestAccess(to: .reminder) { [weak self] granted, error in
                            DispatchQueue.main.async {
                                if granted && error == nil {
                                    createAndSaveReminder()
                                } else {
                                    self?.finishSave(false, completion: completion, alert: "Reminder permission was not granted.")
                                }
                            }
                        }
                    }
                }
            } else {
                self.saveIdeal(withReminderId: nil, uId: uId, weekStartDay: weekStartDay)
                self.finishSave(true, completion: completion)
            }
        }

        guard shouldCheckCurrentWeekDuplicates() else {
            continueSave()
            return
        }

        let effectiveWeekStartDay = weekStartDay ?? WeekdayUtility.defaultWeekStartDay
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        IdealDuplicateGuard.fetchCurrentWeekKeys(userId: uId, weekStartDay: effectiveWeekStartDay) { [weak self] result in
            switch result {
            case .failure(let error):
                AppLogger.error(AppLogger.firestore, "Error checking duplicates for new ideal: \(error.localizedDescription)")
                self?.finishSave(false, completion: completion, alert: "Could not validate duplicates. Please try again.")
            case .success(let existingKeys):
                guard let self else {
                    completion?(false)
                    return
                }
                if let key = IdealDuplicateGuard.duplicateKey(category: self.category, title: trimmedTitle),
                   existingKeys.contains(key) {
                    self.finishSave(false, completion: completion, alert: "An ideal titled \"\(trimmedTitle)\" already exists in \(self.category) for this week.")
                    return
                }
                continueSave()
            }
        }
    }
    
    private func saveIdeal(withReminderId reminderId: String?, uId: String, weekStartDay: String? = nil, precomputedId: String? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editingId = editingItemId {
            // Editing existing item - only update title for wishlist items
            let idealRef = db.collection("users")
                .document(uId)
                .collection("ideals")
                .document(editingId)
            
            if wishlistEnabled {
                // For wishlist items, only update title
                idealRef.updateData([
                    "title": trimmedTitle
                ])
            } else {
                // For regular items, update all fields
                idealRef.updateData([
                    "title": trimmedTitle,
                    "category": category,
                    "targetCount": targetCount,
                    "notes": notes
                ])
            }
        } else {
            // Creating new item — reuse the id minted before reminder creation
            // (so the reminder's ownership tag matches the stored doc), else mint.
            let newId = precomputedId ?? UUID().uuidString
            // For wishlist items, use default category and targetCount (will be set when planning)
            let itemCategory = wishlistEnabled ? Self.defaultCategory : category
            let itemTargetCount = wishlistEnabled ? "1" : targetCount
            let now = Date().timeIntervalSince1970
            let startDateForNew = wishlistEnabled ? TimeInterval(0) : Self.currentWeekStartTimestamp(weekStartDay: weekStartDay)
            let newItem = Ideal(
                id: newId,
                category: itemCategory,
                title: trimmedTitle,
                notes: notes,
                scheduleDateTime: scheduleDateTime.timeIntervalSince1970,
                createdDate: now,
                targetCount: itemTargetCount,
                doneCount: doneCount,
                active: active,
                reminderId: reminderId,
                wishlistEnabled: wishlistEnabled,
                startDate: startDateForNew
            )
            db.collection("users")
                .document(uId)
                .collection("ideals")
                .document(newId)
                .setData(newItem.asDictionary())
        }
    }
    
    var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            return false
        }
        guard scheduleDateTime >= Date().addingTimeInterval(-86400) else {
            return false
        }
        return true
    }
    
    func validateAndSetAlertMessage() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if trimmedTitle.isEmpty {
            alertMessage = "Please enter a title for your ideal."
        } else if scheduleDateTime < Date().addingTimeInterval(-86400) {
            alertMessage = "Please select a due date that is today or newer."
        }
    }
}
