//
//  FreeTrial.swift
//  The Ideal Week
//
//  The 17-day free trial (client, 2026-10-07: "for everyone"). Apple's
//  introductory offers only come in 3 days, 1–2 weeks, 1–6 months or a year,
//  so the app counts this one itself. It starts the first time the app sees
//  the subscription switched on for a user — a new user's first open, or the
//  day the subscription goes live for an existing one — and that moment is
//  kept on the server (`users/{uid}.freeTrialStartedAt`), so reinstalling
//  does not restart it. Nothing here runs while the subscription is hidden.
//
//  Pure logic; `SubscriptionManager` reads and writes the start.
//

import Foundation

enum FreeTrial {
    static var days: Int { AppStoreConfig.freeTrialDays }

    /// The user document field that holds the start (a server timestamp).
    static let startField = "freeTrialStartedAt"

    static func endDate(start: Date) -> Date {
        start.addingTimeInterval(TimeInterval(days) * 86_400)
    }

    /// An unknown start (still loading, or the read failed) never locks
    /// anyone out.
    static func isActive(start: Date?, now: Date) -> Bool {
        guard let start else { return true }
        return now < endDate(start: start)
    }

    /// Whole days left, a part day counting as one; never below zero.
    static func daysLeft(start: Date, now: Date) -> Int {
        let remaining = endDate(start: start).timeIntervalSince(now)
        guard remaining > 0 else { return 0 }
        return Int((remaining / 86_400).rounded(.up))
    }

    /// Written once: a second write would hand out a new trial.
    static func shouldRecordStart(existing: Date?) -> Bool {
        existing == nil
    }
}

/// The monthly price is set in App Store Connect. This only notices when the
/// US store disagrees with the agreed price, so it can be fixed there.
enum SubscriptionPricing {
    static func isMonthlyPriceWrong(price: Decimal, currencyCode: String) -> Bool {
        guard currencyCode.uppercased() == "USD" else { return false }
        return price != AppStoreConfig.monthlyPriceUSD
    }
}
