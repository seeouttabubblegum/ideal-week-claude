//
//  WeekTimeZone.swift
//  The Ideal Week
//
//  The time zone weeks are counted in. Every ideal's startDate is the instant
//  its week began — midnight on the week-start day where it was written. If
//  week boundaries followed the phone's current time zone, travelling west
//  would push this week's ideals into "last week" (and east, the other way),
//  and the weekly prompt would offer the wrong week (loophole found
//  2026-09-29).
//
//  So the first time the app runs, the phone's time zone is recorded and week
//  boundaries use it from then on. Days and reminder times stay in the phone's
//  local time; only which WEEK something belongs to is pinned.
//

import Foundation

enum WeekTimeZone {
    static let key = "weekTimeZoneIdentifier"

    /// The recorded zone, recording `current` the first time it is asked.
    static func recorded(defaults: UserDefaults = .standard, current: TimeZone = .current) -> TimeZone {
        if let id = defaults.string(forKey: key), let zone = TimeZone(identifier: id) {
            return zone
        }
        defaults.set(current.identifier, forKey: key)
        return current
    }

    /// The zone the app counts weeks in — read once per run.
    static var current: TimeZone {
        if let cached { return cached }
        let zone = recorded()
        cached = zone
        return zone
    }

    private static var cached: TimeZone?
}
