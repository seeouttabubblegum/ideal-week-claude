//
//  PreviewSampleData.swift
//  The Ideal Week
//
//  Shared mock data + helpers for SwiftUI #Preview blocks across the app, so
//  every view can be previewed in Xcode without auth, Firestore, or live data.
//  DEBUG-only: excluded from release builds.
//

#if DEBUG
import SwiftUI
import FirebaseCore

enum PreviewData {

    // MARK: - Firebase

    /// Some view models touch `Firestore.firestore()` in their stored
    /// properties, which crashes if Firebase was never configured. Previews
    /// don't run the App's launch path, so call this before instantiating
    /// those view models. Safe to call repeatedly.
    static func configureFirebaseIfNeeded() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    // MARK: - Constants

    static let userId = "preview-user-id"
    static let weekStartDay = "Sunday"

    private static var weekStart: TimeInterval {
        WeekdayUtility.weekStart(weekStartDay: weekStartDay).timeIntervalSince1970
    }

    /// A weekday a few days ahead of "today" so NEXT / schedule indicators render.
    static var futureDay: Int {
        let wd = Calendar.current.component(.weekday, from: Date()) // 1=Sun..7=Sat
        return wd >= 6 ? 1 : wd + 1
    }

    // MARK: - Ideals

    /// Build a sample ideal in a chosen state.
    static func ideal(_ title: String,
                      category: Category = .fix,
                      done: Int = 0,
                      target: String = "5",
                      days: [Int] = [],
                      time: TimeInterval = 46_500, // 12:45
                      reviewScore: Int? = nil,
                      wishlist: Bool = false,
                      notes: String = "") -> Ideal {
        var i = Ideal(id: title, title: title)
        i.category = category.rawValue
        i.doneCount = done
        i.targetCount = target
        i.notes = notes
        i.reviewScore = reviewScore
        i.wishlistEnabled = wishlist
        i.startDate = weekStart
        i.createdDate = weekStart
        if !days.isEmpty {
            i.reminderSchedules = [ReminderSchedule(days: days, time: time)]
            i.scheduledDays = days
            i.reminderTime = time
        }
        return i
    }

    /// A single representative ideal (scheduled, partially complete).
    static var sampleIdeal: Ideal {
        ideal("Try New Glasses", category: .fix, done: 2, target: "5", days: [futureDay])
    }

    /// A current-week list spanning several categories and states.
    static var ideals: [Ideal] {
        [
            ideal("Fix Leaky Faucet", category: .fix, done: 3, target: "3"),
            ideal("Make App Layouts", category: .fix, done: 9, target: "9"),
            ideal("Walk The Dog", category: .fitness, done: 12, target: "13"),
            ideal("Yoga", category: .fitness, done: 0, target: "5", days: [futureDay]),
            ideal("Read 30 min", category: .faculties, done: 1, target: "5"),
            ideal("Call Mom", category: .family, done: 2, target: "3", days: [futureDay]),
            ideal("Budget Review", category: .finance, done: 0, target: "1"),
            ideal("Plan Weekend", category: .fun, done: 1, target: "2"),
        ]
    }

    /// A finished "last week" list with review scores, for review / history views.
    static var lastWeekIdeals: [Ideal] {
        [
            ideal("Morning Run", category: .fitness, done: 4, target: "5", reviewScore: 6),
            ideal("Journaling", category: .feelings, done: 3, target: "3", reviewScore: 7),
            ideal("Pay Bills", category: .finance, done: 1, target: "1", reviewScore: 4),
            ideal("Date Night", category: .fun, done: 1, target: "1", reviewScore: 5),
        ]
    }

    /// Wishlist (not yet scheduled) ideas.
    static var wishlist: [Ideal] {
        [
            ideal("Learn Guitar", category: .fun, target: "3", wishlist: true),
            ideal("Meditation Habit", category: .feelings, target: "7", wishlist: true),
        ]
    }

    // MARK: - Schedule helpers

    static var days: [DayInfo] {
        let abbr = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return (1...7).map { DayInfo(weekday: $0, abbreviation: abbr[$0 - 1], dayNumber: "\($0)") }
    }

    static var plannedGroups: [PlannedReminderGroup] {
        [PlannedReminderGroup(days: Set([futureDay]), time: nil)]
    }

    // MARK: - Radar / charts

    static var radarAxes: [RadarAxis] {
        Category.allCases.enumerated().map { idx, cat in
            RadarAxis(category: cat,
                      completion: Double((idx % 5) + 1) / 5.0,
                      reviewDisplay: Double((idx % 7) + 1),
                      reviewPlotted: Double((idx % 7) + 1) / 7.0)
        }
    }
}
#endif
