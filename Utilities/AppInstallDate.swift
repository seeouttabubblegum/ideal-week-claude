//
//  AppInstallDate.swift
//  The Ideal Week
//
//  When this install of the app first ran. The guided tours measure their
//  two-week window from it, and an account created before it belongs to an
//  existing user (client, 2026-09-29).
//
//  Recorded at launch, before anyone signs in, so a new user's account is
//  always created after it. It lives with the app's other settings, so a
//  reinstall starts a new install — which is exactly what makes an existing
//  user's reinstall read as "account older than the install".
//

import Foundation

enum AppInstallDate {
    static let key = "appInstallFirstLaunchDate"

    /// The stored date, recording `now` the first time it is asked.
    @discardableResult
    static func recordIfNeeded(defaults: UserDefaults = .standard, now: Date = Date()) -> Date {
        if let stored = defaults.object(forKey: key) as? Date { return stored }
        defaults.set(now, forKey: key)
        return now
    }
}
