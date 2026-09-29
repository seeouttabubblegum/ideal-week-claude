//
//  TestLinks.swift
//  The Ideal Week
//
//  Who sees the TEMPORARY test links under the NEXT pill. The links — and this
//  file — come out before the App Store release.
//
//  The weekly-prompt link forces the prompt past its "a plan already exists"
//  gate, so the client (Jay) opened planning through it on a week he had
//  already planned and saw a two-item list (2026-09-29). It is hidden on his
//  account only; everyone else on TestFlight keeps it. His address is here
//  only because this whole file is deleted with the links.
//

import Foundation

enum TestLinks {
    private static let weeklyPromptLinkHiddenFor: Set<String> = ["jay@pijut.com"]

    static func showsWeeklyPromptLink(email: String?) -> Bool {
        guard let email else { return true }
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !weeklyPromptLinkHiddenFor.contains(normalized)
    }
}
