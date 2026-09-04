//
//  IdealScheduleFormatter.swift
//  The Ideal Week
//
//  Pure helpers for formatting an Ideal's schedule display in the row.
//
//  Two inputs drive the indicator:
//  - `consumedCount`: how many scheduled occurrences have been "used up" by
//    completions made SINCE the schedule was set. The caller computes this as
//    max(0, doneCount − scheduleBaselineDoneCount). Completing advances it (the
//    next pending occurrence disappears); un-completing rewinds it (the previous
//    occurrence comes back). This is drift-free because it's derived, not a
//    mutated counter.
//  - `now`: occurrences whose date already passed are skipped.
//
//  Algorithm: sort occurrences by date, drop the first `consumedCount`, then show
//  the first of the remainder that is still in the future. If none remain (all
//  consumed, or all past), show .unscheduled (the bell).
//
//  The baseline offset fixes the "complete first, schedule later" case: an ideal
//  with doneCount=3 then given a 3-day schedule records baseline=3, so
//  consumedCount=0 and the schedule shows from its first day instead of wrongly
//  indexing past the end. The doneCount ↔ reminder check state stays in lockstep
//  via the separate delta-based two-way sync.
//

import Foundation

enum IdealScheduleFormatter {
    enum Display: Equatable {
        case unscheduled
        case next(text: String)   // "NEXT: 10:15 A, WED"
    }

    private static let dayAbbrev = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    /// Build display for an ideal's schedule.
    /// - Parameters:
    ///   - scheduledDays: 1=Sun ... 7=Sat (order in array is ignored — sorted chronologically internally)
    ///   - reminderTime: seconds since midnight (local)
    ///   - consumedCount: scheduled occurrences already used up by completions made
    ///                    since the schedule was set = max(0, doneCount − baseline).
    ///                    Defaults to 0.
    ///   - weekStartDay: user's preferred week start (e.g. "Monday")
    ///   - weekAnchor: any date within the target week (defaults to today).
    ///                 For Next? planned items, pass `item.startDate`-derived Date.
    ///   - now: the reference "now" used to skip past occurrences (defaults to current time)
    ///   - calendar: calendar to use (defaults to user's week calendar)
    static func display(
        scheduledDays: [Int],
        reminderTime: TimeInterval,
        consumedCount: Int = 0,
        weekStartDay: String,
        weekAnchor: Date? = nil,
        now: Date? = nil,
        calendar: Calendar? = nil
    ) -> Display {
        return display(
            schedules: scheduledDays.isEmpty ? [] : [ReminderSchedule(days: scheduledDays, time: reminderTime)],
            consumedCount: consumedCount,
            weekStartDay: weekStartDay,
            weekAnchor: weekAnchor,
            now: now,
            calendar: calendar
        )
    }

    /// Multi-group variant: builds occurrences for every `(day, time)` across all schedule
    /// groups, then runs the same sort → drop `consumedCount` → first-future logic. Identical
    /// `(day, hour, minute)` occurrences are de-duplicated so overlapping groups don't double-count.
    static func display(
        schedules: [ReminderSchedule],
        consumedCount: Int = 0,
        weekStartDay: String,
        weekAnchor: Date? = nil,
        now: Date? = nil,
        calendar: Calendar? = nil
    ) -> Display {
        guard !schedules.isEmpty else { return .unscheduled }
        let effectiveNow = now ?? Date()

        let cal: Calendar = {
            if let calendar = calendar { return calendar }
            return WeekdayUtility.calendar(firstWeekday: weekStartDay)
        }()
        let anchor = weekAnchor ?? Date()
        // Compute week start (of the anchor's week) using the supplied calendar so timezone is consistent.
        let weekStart: Date = {
            var c = cal
            c.firstWeekday = WeekdayUtility.weekdayIndex(for: weekStartDay)
            let comps = c.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)
            let start = c.date(from: comps) ?? anchor
            return c.startOfDay(for: start)
        }()
        let weekStartWeekday = cal.component(.weekday, from: weekStart) // 1..7

        var occurrences: [(date: Date, day: Int)] = []
        // Dedup identical occurrences across groups by (day, hour, minute).
        var seen: Set<Int> = []
        for schedule in schedules {
            let hour = Int(schedule.time) / 3600
            let minute = (Int(schedule.time) % 3600) / 60
            let second = Int(schedule.time) % 60
            for day in schedule.days {
                guard (1...7).contains(day) else { continue }
                let key = day * 10000 + hour * 100 + minute
                guard seen.insert(key).inserted else { continue }
                let offset = ((day - weekStartWeekday) % 7 + 7) % 7
                guard
                    let dayDate = cal.date(byAdding: .day, value: offset, to: weekStart),
                    let occurrence = cal.date(bySettingHour: hour, minute: minute, second: second, of: dayDate)
                else { continue }
                occurrences.append((occurrence, day))
            }
        }

        guard !occurrences.isEmpty else { return .unscheduled }

        let sorted = occurrences.sorted { $0.date < $1.date }
        // Drop the occurrences already consumed by post-schedule completions, then
        // show the first of the remainder still in the future. If consumedCount has
        // eaten the whole list (all done) or the remainder is all past, fall through
        // to .unscheduled (bell).
        let startIndex = max(0, consumedCount)
        guard startIndex < sorted.count else { return .unscheduled }
        let remaining = sorted[startIndex...]
        guard let upcoming = remaining.first(where: { $0.date >= effectiveNow }) else {
            return .unscheduled
        }
        return .next(text: "NEXT: \(format(date: upcoming.date, dayInt: upcoming.day, calendar: cal))")
    }

    /// Format a single occurrence as "10:15 A, WED".
    /// dayInt: 1=Sun ... 7=Sat
    static func format(date: Date, dayInt: Int, calendar: Calendar? = nil) -> String {
        let cal = calendar ?? {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = .current
            return c
        }()
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let hour24 = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let isPM = hour24 >= 12
        var hour12 = hour24 % 12
        if hour12 == 0 { hour12 = 12 }
        let period = isPM ? "P" : "A"
        let dayLabel = (1...7).contains(dayInt) ? dayAbbrev[dayInt - 1] : "—"
        return String(format: "%d:%02d %@, %@", hour12, minute, period, dayLabel)
    }
}
