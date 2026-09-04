//
//  MainSettings.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/10/25.
//

import SwiftData
import SwiftUI

@Model
class MainSettings {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double
    var textColorRed: Double = 0.0
    var textColorGreen: Double = 0.0
    var textColorBlue: Double = 0.0
    var textColorOpacity: Double = 1.0
    var week_start_day: String
    var skip_reviews: Bool = false
    var skip_reviews_last_reset_date: TimeInterval = 0
    
    // Notification settings (local only, SwiftData)
    var notification_time: String? = nil
    var daily_notifications: Bool = false
    var weekly_notifications: Bool = false
    
    // Security settings
    var biometric_login: Bool = false
    
    // PIN for adding ideals after 2 days
    var idealAddPin: String? = nil

    // Community / Apple Intelligence
    var useAppleIntelligence: Bool = false

    // Testing: persist "Reset Weekly Prompts on Date Change" toggle
    var resetWeeklyPromptsOnDateChange: Bool = false
    // Testing: when true, bypasses the planned-record check so the weekly prompt always re-evaluates
    var testModeEnabled: Bool = false

    init(red: Double, green: Double, blue: Double, opacity: Double, week_start_day: String, skip_reviews: Bool, skip_reviews_last_reset_date: TimeInterval = 0, textColorRed: Double = 0.0, textColorGreen: Double = 0.0, textColorBlue: Double = 0.0, textColorOpacity: Double = 1.0, notification_time: String? = nil, daily_notifications: Bool = false, weekly_notifications: Bool = false, biometric_login: Bool = false, idealAddPin: String? = nil, resetWeeklyPromptsOnDateChange: Bool = false, testModeEnabled: Bool = false, useAppleIntelligence: Bool = false) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
        self.textColorRed = textColorRed
        self.textColorGreen = textColorGreen
        self.textColorBlue = textColorBlue
        self.textColorOpacity = textColorOpacity
        self.week_start_day = week_start_day
        self.skip_reviews = skip_reviews
        self.skip_reviews_last_reset_date = skip_reviews_last_reset_date
        self.notification_time = notification_time
        self.daily_notifications = daily_notifications
        self.weekly_notifications = weekly_notifications
        self.biometric_login = biometric_login
        self.idealAddPin = idealAddPin
        self.resetWeeklyPromptsOnDateChange = resetWeeklyPromptsOnDateChange
        self.testModeEnabled = testModeEnabled
        self.useAppleIntelligence = useAppleIntelligence
    }
}

extension MainSettings {
    /// Turn "Skip Reviews This Week?" back off once the week it was enabled in
    /// has ended. Call this BEFORE reading `skip_reviews` to decide whether to
    /// present a review — otherwise that path honours a flag that has run out
    /// (the list swipe expired it, the recap did not).
    func expireSkipReviewsIfWeekElapsed(weekStartDay: String, now: Date) {
        guard SkipReviewsExpiry.shouldExpire(skipReviews: skip_reviews,
                                             lastResetDate: skip_reviews_last_reset_date,
                                             weekStartDay: weekStartDay,
                                             now: now) else { return }
        skip_reviews = false
        skip_reviews_last_reset_date = now.timeIntervalSince1970
    }
}
