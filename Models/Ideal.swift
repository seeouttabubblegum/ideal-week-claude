//
//  Ideal.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import Foundation

/// One reminder group: a set of weekdays sharing a single time-of-day. An ideal can carry
/// several of these (e.g. "Mon/Wed at 9 AM" and "Fri at 6 PM"). Each `(day, time)` pair
/// becomes one EKReminder in the flat `Ideal.reminderIds` list.
struct ReminderSchedule: Codable, Equatable {
    var days: [Int]          // 1=Sunday … 7=Saturday
    var time: TimeInterval   // seconds since midnight (local)

    init(days: [Int], time: TimeInterval) {
        self.days = days
        self.time = time
    }
}

struct Ideal: Codable, Identifiable, Equatable {
    let id: String
    var category: String = "Fix"
    var title: String = "My Piece"
    var notes: String = ""
    var scheduleDateTime: TimeInterval = TimeInterval() // Legacy - kept for backward compatibility
    var scheduledDays: [Int] = [] // Array of weekday numbers (1=Sunday, 2=Monday, etc.) for current week
    var reminderTime: TimeInterval = 0 // Time of day in seconds since midnight (legacy mirror = first schedule's time)
    var reminderSchedules: [ReminderSchedule] = [] // Multiple reminder groups (source of truth). Empty = fall back to legacy scheduledDays/reminderTime.
    var reminderIds: [String] = [] // Array of reminder IDs for multiple reminders
    var createdDate: TimeInterval = TimeInterval()
    var targetCount: String = "1"
    var doneCount: Int = 0
    var toNextWeek: Bool = false // Deprecated - kept for backward compatibility with existing ideals
    var active: Bool = true
    var platform: String = "iOS"
    var reviewScore: Int?
    var reminderId: String? // Legacy - kept for backward compatibility
    var wishlistEnabled: Bool = false // Hidden field to mark wishlist items
    var plannedFromWishlistAt: TimeInterval = 0 // Timestamp when item was moved from wishlist to planned (0 means not from wishlist)
    var plannedTarget: String? = nil // Target count for next week when planning (removed when next week starts)
    var lastCompletedDate: TimeInterval? = nil // Timestamp of the last completion action (when doneCount was incremented)
    var secondCompletionDate: TimeInterval? = nil // Timestamp of the second-to-last completion action (for rollback when decrementing)
    /// Week this ideal is "for" (start of that week). 0 = no start date (e.g. wishlist). History and "last week" use this.
    var startDate: TimeInterval = 0
    /// When set, this ideal is a clone for next week; value is the id of the source ideal (from Again? list). Used to hide already-planned ideals when reopening planning.
    var sourceIdealId: String? = nil
    /// Optional address for map (current or custom); used in Schedule detail to open in Apple/Google Maps.
    var locationAddress: String? = nil
    /// `doneCount` captured at the moment the current schedule was created/edited.
    /// The schedule indicator shows the (doneCount − scheduleBaselineDoneCount)-th
    /// upcoming occurrence, so completions made BEFORE the schedule existed don't
    /// wrongly consume scheduled days. Defaults to 0 (back-compat: pre-existing
    /// ideals behave as if scheduled from doneCount 0).
    var scheduleBaselineDoneCount: Int = 0

    /// Read accessor that bridges old and new schedule storage. Returns `reminderSchedules`
    /// when present; otherwise synthesizes a single group from the legacy
    /// `scheduledDays`/`reminderTime` pair (so old ideals and other clients keep working);
    /// `[]` when nothing is scheduled. All schedule read sites should use this.
    var effectiveReminderSchedules: [ReminderSchedule] {
        if !reminderSchedules.isEmpty { return reminderSchedules }
        if !scheduledDays.isEmpty { return [ReminderSchedule(days: scheduledDays, time: reminderTime)] }
        return []
    }

    enum CodingKeys: String, CodingKey {
        case id, category, title, notes, scheduleDateTime, scheduledDays, reminderTime, reminderSchedules, reminderIds
        case createdDate, targetCount, doneCount, toNextWeek, active, platform, reviewScore, reminderId, wishlistEnabled, plannedFromWishlistAt, plannedTarget, lastCompletedDate, secondCompletionDate, startDate, sourceIdealId, locationAddress, scheduleBaselineDoneCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all fields with defaults for missing ones
        let decodedId = try container.decode(String.self, forKey: .id)
        let decodedCategory = try container.decodeIfPresent(String.self, forKey: .category) ?? "Fix"
        let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title) ?? "My Piece"
        let decodedNotes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        let decodedScheduleDateTime = try container.decodeIfPresent(TimeInterval.self, forKey: .scheduleDateTime) ?? TimeInterval()
        let decodedScheduledDays = try container.decodeIfPresent([Int].self, forKey: .scheduledDays) ?? []
        let decodedReminderTime = try container.decodeIfPresent(TimeInterval.self, forKey: .reminderTime) ?? 0
        let decodedReminderSchedules = try container.decodeIfPresent([ReminderSchedule].self, forKey: .reminderSchedules) ?? []
        let decodedReminderIds = try container.decodeIfPresent([String].self, forKey: .reminderIds) ?? []
        let decodedCreatedDate = try container.decodeIfPresent(TimeInterval.self, forKey: .createdDate) ?? TimeInterval()
        let decodedTargetCount = try container.decodeIfPresent(String.self, forKey: .targetCount) ?? "1"
        let decodedDoneCount = try container.decodeIfPresent(Int.self, forKey: .doneCount) ?? 0
        let decodedToNextWeek = try container.decodeIfPresent(Bool.self, forKey: .toNextWeek) ?? false
        let decodedActive = try container.decodeIfPresent(Bool.self, forKey: .active) ?? true
        let decodedPlatform = try container.decodeIfPresent(String.self, forKey: .platform) ?? "iOS"
        let decodedReviewScore = try container.decodeIfPresent(Int.self, forKey: .reviewScore)
        let decodedReminderId = try container.decodeIfPresent(String.self, forKey: .reminderId)
        let decodedWishlist = try container.decodeIfPresent(Bool.self, forKey: .wishlistEnabled) ?? false
        let decodedPlannedFromWishlistAt = try container.decodeIfPresent(TimeInterval.self, forKey: .plannedFromWishlistAt) ?? 0
        let decodedPlannedTarget = try container.decodeIfPresent(String.self, forKey: .plannedTarget)
        let decodedLastCompletedDate = try container.decodeIfPresent(TimeInterval.self, forKey: .lastCompletedDate)
        let decodedSecondCompletionDate = try container.decodeIfPresent(TimeInterval.self, forKey: .secondCompletionDate)
        let decodedStartDate = try container.decodeIfPresent(TimeInterval.self, forKey: .startDate) ?? 0
        let decodedSourceIdealId = try container.decodeIfPresent(String.self, forKey: .sourceIdealId)
        let decodedLocationAddress = try container.decodeIfPresent(String.self, forKey: .locationAddress)
        let decodedScheduleBaseline = try container.decodeIfPresent(Int.self, forKey: .scheduleBaselineDoneCount) ?? 0

        // Initialize using the memberwise initializer
        self.init(
            id: decodedId,
            category: decodedCategory,
            title: decodedTitle,
            notes: decodedNotes,
            scheduleDateTime: decodedScheduleDateTime,
            createdDate: decodedCreatedDate,
            targetCount: decodedTargetCount,
            doneCount: decodedDoneCount,
            toNextWeek: decodedToNextWeek,
            active: decodedActive,
            platform: decodedPlatform,
            reviewScore: decodedReviewScore,
            reminderId: decodedReminderId,
            scheduledDays: decodedScheduledDays,
            reminderTime: decodedReminderTime,
            reminderSchedules: decodedReminderSchedules,
            reminderIds: decodedReminderIds,
            wishlistEnabled: decodedWishlist,
            plannedFromWishlistAt: decodedPlannedFromWishlistAt,
            plannedTarget: decodedPlannedTarget,
            lastCompletedDate: decodedLastCompletedDate,
            secondCompletionDate: decodedSecondCompletionDate,
            startDate: decodedStartDate,
            sourceIdealId: decodedSourceIdealId,
            locationAddress: decodedLocationAddress,
            scheduleBaselineDoneCount: decodedScheduleBaseline
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(scheduleDateTime, forKey: .scheduleDateTime)
        try container.encode(scheduledDays, forKey: .scheduledDays)
        try container.encode(reminderTime, forKey: .reminderTime)
        try container.encode(reminderSchedules, forKey: .reminderSchedules)
        try container.encode(reminderIds, forKey: .reminderIds)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(targetCount, forKey: .targetCount)
        try container.encode(doneCount, forKey: .doneCount)
        try container.encode(toNextWeek, forKey: .toNextWeek) // Keep encoding for backward compatibility
        try container.encode(active, forKey: .active)
        try container.encode(platform, forKey: .platform)
        try container.encodeIfPresent(reviewScore, forKey: .reviewScore)
        try container.encodeIfPresent(reminderId, forKey: .reminderId)
        try container.encode(wishlistEnabled, forKey: .wishlistEnabled)
        try container.encode(plannedFromWishlistAt, forKey: .plannedFromWishlistAt)
        try container.encodeIfPresent(plannedTarget, forKey: .plannedTarget)
        try container.encodeIfPresent(lastCompletedDate, forKey: .lastCompletedDate)
        try container.encodeIfPresent(secondCompletionDate, forKey: .secondCompletionDate)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(sourceIdealId, forKey: .sourceIdealId)
        try container.encodeIfPresent(locationAddress, forKey: .locationAddress)
        try container.encode(scheduleBaselineDoneCount, forKey: .scheduleBaselineDoneCount)
    }
    
    init(id: String, title: String){
        self.id = id
        self.title = title
    }
    
    init(id: String, category: String, title: String, notes: String, scheduleDateTime: TimeInterval = 0, createdDate: TimeInterval, targetCount: String, doneCount: Int, toNextWeek: Bool = false, active: Bool, platform: String = "iOS", reviewScore: Int? = nil, reminderId: String? = nil, scheduledDays: [Int] = [], reminderTime: TimeInterval = 0, reminderSchedules: [ReminderSchedule] = [], reminderIds: [String] = [], wishlistEnabled: Bool = false, plannedFromWishlistAt: TimeInterval = 0, plannedTarget: String? = nil, lastCompletedDate: TimeInterval? = nil, secondCompletionDate: TimeInterval? = nil, startDate: TimeInterval = 0, sourceIdealId: String? = nil, locationAddress: String? = nil, scheduleBaselineDoneCount: Int = 0) {
        self.id = id
        self.category = category
        self.title = title
        self.notes = notes
        self.scheduleDateTime = scheduleDateTime
        self.scheduledDays = scheduledDays
        self.reminderTime = reminderTime
        self.reminderSchedules = reminderSchedules
        self.reminderIds = reminderIds
        self.createdDate = createdDate
        self.targetCount = targetCount
        self.doneCount = doneCount
        self.toNextWeek = toNextWeek
        self.active = active
        self.platform = platform
        self.reviewScore = reviewScore
        self.reminderId = reminderId
        self.wishlistEnabled = wishlistEnabled
        self.plannedFromWishlistAt = plannedFromWishlistAt
        self.plannedTarget = plannedTarget
        self.lastCompletedDate = lastCompletedDate
        self.secondCompletionDate = secondCompletionDate
        self.startDate = startDate
        self.sourceIdealId = sourceIdealId
        self.locationAddress = locationAddress
        self.scheduleBaselineDoneCount = scheduleBaselineDoneCount
    }
        
}
