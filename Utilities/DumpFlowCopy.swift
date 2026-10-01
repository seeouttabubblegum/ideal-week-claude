//
//  DumpFlowCopy.swift
//  The Ideal Week
//
//  Every line of text in the first-week dump, in one place for the client's
//  copy edit.
//

import Foundation

enum DumpFlowCopy {
    static let headerTitle = "Your First Week"

    // The dump
    static let dumpTitle = "Brain Dump"
    static let dumpMessage = "Write down everything that might make you a little happier this week. Big, small, the dumb ones too. Whatever doesn't make this week waits on your Next? list."
    static let dumpPlaceholder = "An idea"
    static let addButton = "Add"
    static let alreadyInDump = "That one is already on your list."

    // Sorting, one F per screen
    static func sortTitle(_ category: Category) -> String {
        "Which of these are your \(category.rawValue)?"
    }
    static let sortHint = "Heart the ones for this week. The rest move on to the next F."
    static let sortNothingLeft = "Everything has a place already. Tap Continue."

    // Empty Fs
    static let fillTitle = "All 7 are required"
    static let fillMessage = "These Fs have nothing yet. Add one small ideal to each, or continue and add it later."
    static func fillPlaceholder(_ category: Category) -> String {
        "Something for \(category.rawValue)"
    }

    // How often
    static let howOftenTitle = "How often this week?"
    static let howOftenMessage = "One number for each. Pick what you can reach this week; you can always do more."
    static let howOftenNothingPicked = "Nothing picked for this week. Everything stays on your Next? list."

    // Buttons
    static let continueButton = "Continue"
    static let backButton = "Back"
    static let saveButton = "Start My Week"

    // Leaving
    static let leaveTitle = "Leave the setup?"
    static let leaveMessage = "Your ideas stay on the Next? list."
    static let leaveConfirm = "Leave"
    static let leaveCancel = "Stay"

    // Saving
    static let saveFailedTitle = "Couldn't save your week"
    static let saveFailedMessage = "Check your connection and try again."
    static let addFailedMessage = "That idea couldn't be saved. Check your connection and try again."

    static let skippedTitle = "Some ideals were not added"
    static func skippedMessage(_ labels: [String]) -> String {
        "These are already in this week and were skipped:\n\n" + labels.map { "- \($0)" }.joined(separator: "\n")
    }
    static let duplicatesTitle = "Fix duplicates before saving"
    static func duplicatesMessage(_ labels: [String]) -> String {
        "Two picks have the same title and F:\n\n" + labels.map { "- \($0)" }.joined(separator: "\n") + "\n\nGo back and un-heart one of them."
    }
    static let okButton = "OK"

    // The tour, after the save
    static let tourTitle = "Want a quick tour?"
    static let tourMessage = "A short walk through your list: adding, marking done and reviewing."
    static let tourStart = "Start Tour"
    static let tourLater = "Not Now"

    /// "F 3 of 7" on the sorting screens; nothing elsewhere.
    static func progress(for stage: DumpFlowStage) -> String? {
        guard case .sort(let category) = stage,
              let index = DumpFlowState.sortOrder.firstIndex(of: category) else { return nil }
        return "F \(index + 1) of \(DumpFlowState.sortOrder.count)"
    }

    // The temporary test link
    static let testLink = "\u{1F5D2}\u{FE0F} Open First-Week Dump (Test)"
}
