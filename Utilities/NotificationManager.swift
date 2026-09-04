//
//  NotificationManager.swift
//  The Ideal Week
//
//  Created for managing notifications
//

import Foundation
import UserNotifications
import FirebaseAuth
import FirebaseFirestore
import SwiftData
import EventKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private let db = Firestore.firestore()

    private init() {}
    
    func requestAuthorization(modelContext: ModelContext? = nil, completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                AppLogger.info(AppLogger.notifications, "Notification permission granted")
                // Do NOT auto-enable notifications here — user sets preferences in Onboarding/Settings.
                // Calling enableNotificationsInSettings on every launch would override saved preferences.
                completion?(true)
            } else if let error = error {
                AppLogger.error(AppLogger.notifications, "Notification permission error: \(error.localizedDescription)")
                completion?(false)
            } else {
                completion?(false)
            }
        }
    }
    
    func enableNotificationsInSettings(context: ModelContext) {
        let descriptor = FetchDescriptor<MainSettings>()
        if let settings = try? context.fetch(descriptor).first {
            settings.daily_notifications = true
            settings.weekly_notifications = true
        }
    }
    
    func checkAndEnableNotificationsIfAuthorized(context: ModelContext) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    self.enableNotificationsInSettings(context: context)
                }
            }
        }
    }
    
    func scheduleDailyNotification(time: Date, enabled: Bool) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyTaskReminder"])
        
        guard enabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Are you ready for today?"
        content.body = "See what's on your plate!"
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        var dateComponents = DateComponents()
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyTaskReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.error(AppLogger.notifications, "Error scheduling daily notification: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleWeeklyNotification(enabled: Bool, weekStartDay: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weeklyTaskSummary"])
        
        guard enabled else { return }
        
        let startWeekday = WeekdayUtility.weekdayIndex(for: weekStartDay)
        
        // Calculate the day before start of week (one day earlier)
        var notificationWeekday = startWeekday - 1
        if notificationWeekday < 1 {
            notificationWeekday = 7 // Wrap to Saturday if start day is Sunday
        }
        
        // Schedule for one day before start of week at 9 PM
        var dateComponents = DateComponents()
        dateComponents.weekday = notificationWeekday
        dateComponents.hour = 21 // 9 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // We'll update the content when the notification fires, but for now set a placeholder
        let content = UNMutableNotificationContent()
        content.title = "Weekly Summary"
        content.body = "Check your weekly progress!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "weeklyTaskSummary", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.error(AppLogger.notifications, "Error scheduling weekly notification: \(error.localizedDescription)")
            }
        }
    }
    
    // Schedule a weekly notification 2 days before the start of the week
    // This notifies users that planning is unlocked and they can start planning
    func schedulePlanningUnlockedNotification(enabled: Bool, weekStartDay: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["planningUnlockedNotification"])
        
        guard enabled else { return }
        
        let startWeekday = WeekdayUtility.weekdayIndex(for: weekStartDay)
        
        // Calculate 2 days before start of week
        var notificationWeekday = startWeekday - 2
        if notificationWeekday < 1 {
            notificationWeekday += 7 // Wrap around if needed
        }
        
        // Schedule for 2 days before start of week at 9 AM (morning notification)
        var dateComponents = DateComponents()
        dateComponents.weekday = notificationWeekday
        dateComponents.hour = 9 // 9 AM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let content = UNMutableNotificationContent()
        content.title = "Got plans?"
        content.body = "Your next week is unlocked! How are you doing this week?"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "planningUnlockedNotification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.error(AppLogger.notifications, "[NotificationManager] Error scheduling planning unlocked notification: \(error.localizedDescription)")
            } else {
                AppLogger.debug(AppLogger.notifications, "[NotificationManager] Scheduled planning unlocked notification for weekday \(notificationWeekday)")
            }
        }
    }
    
    func updateWeeklyNotification(completedCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Summary"
        if completedCount == 0 {
            content.body = "A new week is coming soon. Best of luck with your ideals!"
        } else {
            content.body = "You have completed \(completedCount) pieces this week! Bravo!"
        }
        content.sound = .default
        
        // Update the existing notification
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            if let weeklyRequest = requests.first(where: { $0.identifier == "weeklyTaskSummary" }) {
                if let trigger = weeklyRequest.trigger as? UNCalendarNotificationTrigger {
                    let newRequest = UNNotificationRequest(
                        identifier: "weeklyTaskSummary",
                        content: content,
                        trigger: trigger
                    )
                    UNUserNotificationCenter.current().add(newRequest) { error in
                        if let error = error {
                            AppLogger.error(AppLogger.notifications, "Error updating weekly notification: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    func calculateAndUpdateWeeklyNotification(weekStartDay: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        db.collection("users")
            .document(userId)
            .collection("ideals")
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }

                // Pre-extract eligible non-wishlist startDates so we can resolve the last *active*
                // week — the most recent past week that actually had ideals. This avoids reporting
                // "0 completed" when the user has skipped a week or two without using the app.
                let nonWishlistStartDates: [TimeInterval] = documents.compactMap { doc -> TimeInterval? in
                    let data = doc.data()
                    let startDate = data["startDate"] as? TimeInterval ?? 0
                    let wishlistEnabled = data["wishlistEnabled"] as? Bool ?? false
                    guard startDate > 0, !wishlistEnabled else { return nil }
                    return startDate
                }

                guard let activeRange = WeekdayUtility.lastActiveWeekRange(
                    fromStartDates: nonWishlistStartDates,
                    weekStartDay: weekStartDay
                ) else {
                    // No history at all — nothing meaningful to report. Set count to 0 so the
                    // notification shows the "new week is coming" copy.
                    DispatchQueue.main.async { [weak self] in
                        self?.updateWeeklyNotification(completedCount: 0)
                    }
                    return
                }

                let lastWeekStartTimestamp = activeRange.start.timeIntervalSince1970
                let lastWeekEndTimestamp = activeRange.end.timeIntervalSince1970

                // Count completed ideals from last active week (startDate in range AND doneCount >= targetCount)
                var completedCount = 0
                for document in documents {
                    let data = document.data()
                    let startDate = data["startDate"] as? TimeInterval ?? 0
                    guard startDate > 0,
                          startDate >= lastWeekStartTimestamp && startDate <= lastWeekEndTimestamp else {
                        continue
                    }

                    // Check if ideal is completed (doneCount >= targetCount)
                    guard let doneCount = data["doneCount"] as? Int,
                          let targetCountString = data["targetCount"] as? String else {
                        continue
                    }

                    // Parse targetCount (handle "6+" case)
                    let targetCount: Int
                    if targetCountString == "6+" {
                        targetCount = 6
                    } else {
                        targetCount = Int(targetCountString) ?? 0
                    }

                    // Count only if doneCount >= targetCount (completed)
                    if doneCount >= targetCount {
                        completedCount += 1
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    self?.updateWeeklyNotification(completedCount: completedCount)
                }
            }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func getNotificationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    /// Name of the custom reminder list used for all ideal reminders.
    static let idealWeekReminderListTitle = "The Ideal Week"

    // MARK: - Ideal-ownership tag (reminder.url)

    /// URL scheme used to stamp an EKReminder with the id of the ideal that
    /// created it. The auto-expire sweep uses this tag to (a) prove a reminder
    /// is ours before deleting it, and (b) map a deleted reminder back to its
    /// ideal so Firestore's `reminderIds` can be cleaned. We use the otherwise
    /// unused `EKCalendarItem.url` field so we never touch user-visible notes.
    static let idealTagURLScheme = "theidealweek"

    /// Build the ownership tag URL for an ideal, e.g. `theidealweek://ideal/<id>`.
    static func idealTagURL(idealId: String) -> URL? {
        guard !idealId.isEmpty else { return nil }
        return URL(string: "\(idealTagURLScheme)://ideal/\(idealId)")
    }

    /// Extract the ideal id from a reminder's tag URL. Returns nil if the URL is
    /// missing, malformed, or not one of ours (so untagged / user-created
    /// reminders are never mistaken for ours).
    static func idealId(fromTagURL url: URL?) -> String? {
        guard let url, url.scheme == idealTagURLScheme else { return nil }
        // Path is "/<id>"; host is "ideal". Strip the leading slash.
        let id = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        return id.isEmpty ? nil : id
    }
    
    /// Returns the reminder calendar/list named "The Ideal Week", creating it if it doesn't exist.
    /// All ideal reminders should be created in this list. Returns nil if access is denied or creation fails.
    static func idealWeekReminderCalendar(eventStore: EKEventStore) -> EKCalendar? {
        let calendars = eventStore.calendars(for: .reminder)
        if let existing = calendars.first(where: { $0.title == idealWeekReminderListTitle }) {
            return existing
        }
        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        newCalendar.title = idealWeekReminderListTitle
        guard let source = eventStore.defaultCalendarForNewReminders()?.source
            ?? eventStore.sources.first(where: { $0.sourceType == .local })
            ?? eventStore.sources.first(where: { $0.sourceType == .calDAV }) else {
            return nil
        }
        newCalendar.source = source
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            return newCalendar
        } catch {
            AppLogger.error(AppLogger.notifications, "Failed to create 'The Ideal Week' reminder list: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Remove reminders for an ideal when it becomes inactive
    static func removeRemindersForIdeal(reminderIds: [String], legacyReminderId: String?) {
        let eventStore = EKEventStore()
        
        // Remove new system reminders
        for reminderId in reminderIds {
            if let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder {
                try? eventStore.remove(reminder, commit: false)
            }
        }
        
        // Remove legacy reminder
        if let legacyId = legacyReminderId, let reminder = eventStore.calendarItem(withIdentifier: legacyId) as? EKReminder {
            try? eventStore.remove(reminder, commit: false)
        }
        
        try? eventStore.commit()
    }
    
    // Reminders are NOT removed when their date/time has passed. They are only removed when:
    // - The ideal is deleted, or
    // - The user turns off reminders or changes the schedule (moved to new date/days).
    // (Previously removePastReminders() deleted past-due reminders; that behavior has been removed.)
}
