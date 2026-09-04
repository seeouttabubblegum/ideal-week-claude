//
//  DateWheelLogic.swift
//  The Ideal Week
//
//  Resolving a day / month / year wheel selection into a real, allowed date.
//
//  Three independent wheels can express dates the calendar does not have
//  (31 February) and dates the app does not allow (a birthday that makes the
//  user under 16). Rather than fight the wheels — disabling rows mid-spin reads
//  as a broken control — the selection is always accepted and then resolved
//  here: impossible days fall back to the last day of the month, and anything
//  past the ceiling snaps to the ceiling.
//

import Foundation

enum DateWheelLogic {

    /// How many days the given month actually has, leap years included.
    static func daysInMonth(month: Int, year: Int, calendar: Calendar = .current) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let start = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: start) else {
            return 31
        }
        return range.count
    }

    /// Minimum age the app requires. Lowered from 16 on 2026-09-02 (client).
    static let minimumAgeYears = 13

    /// Latest allowed birthday — someone born exactly this long ago turns
    /// `minimumAgeYears` today and is allowed.
    static func minimumAgeCeiling(today: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .year, value: -minimumAgeYears, to: today) ?? today
    }

    /// Years the wheel lists — a century before the ceiling, through to the
    /// current year. Years past the ceiling ARE included so they can be shown
    /// greyed out; omitting them makes the wheel look like it stops for no
    /// reason. Use `isEligible(year:notAfter:)` to decide how to render each.
    static func selectableYears(notAfter maximum: Date,
                                today: Date = Date(),
                                calendar: Calendar = .current) -> [Int] {
        let maxYear = calendar.component(.year, from: maximum)
        let thisYear = calendar.component(.year, from: today)
        return Array((maxYear - 100)...max(maxYear, thisYear))
    }

    /// False for years that would make the user younger than the minimum age.
    /// Year granularity: the ceiling's own year is eligible, because part of it
    /// is (month/day within it are handled by `resolve`).
    static func isEligible(year: Int, notAfter maximum: Date, calendar: Calendar = .current) -> Bool {
        year <= calendar.component(.year, from: maximum)
    }

    /// Turn a raw wheel selection into a date that exists and is allowed.
    /// - Day is clamped to the month's real length.
    /// - The result is clamped to `maximum` (the minimum-age boundary).
    static func resolve(day: Int, month: Int, year: Int,
                        notAfter maximum: Date, calendar: Calendar = .current) -> Date {
        let safeMonth = min(max(month, 1), 12)
        let safeDay = min(max(day, 1), daysInMonth(month: safeMonth, year: year, calendar: calendar))

        var components = DateComponents()
        components.year = year
        components.month = safeMonth
        components.day = safeDay
        guard let candidate = calendar.date(from: components) else { return maximum }
        return min(candidate, maximum)
    }
}
