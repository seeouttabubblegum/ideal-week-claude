//
//  DumpFlow.swift
//  The Ideal Week
//
//  The first-week dump (client, 2026-10-02; book chapter 9). A new user
//  writes down every idea first — the dump is the Next? list in disguise, so
//  each idea is saved as a Next? (wishlist) item the moment it is added. The
//  ideas are then sorted one F at a time in the book's order; each pick gets
//  its number on the same screen, and an F with nothing left to pick offers
//  to add ideas for it (client, 2026-10-02). The last F saves. Picks move
//  into the CURRENT week; whatever is left waits on Next? for week two.
//
//  Pure logic only — `DumpFlowView` draws it, `PlanningSheetViewModel`
//  saves it.
//

import Foundation

/// When the dump opens by itself.
enum DumpFlowGate {
    /// Set when the dump is saved or closed — it never opens by itself again.
    static func doneKey(uid: String) -> String { "dumpFlowDone_\(uid)" }

    /// Worth reading the server at all: tours may start on their own for this
    /// user (a new account, first install, within two weeks —
    /// `WalkthroughGate.allowsAutomaticTours`) and the dump is not done.
    static func shouldCheck(automaticAllowed: Bool, done: Bool) -> Bool {
        automaticAllowed && !done
    }

    /// After the server read: only someone with nothing in any week yet.
    static func shouldShow(automaticAllowed: Bool, done: Bool, hasAnyWeekIdeal: Bool) -> Bool {
        shouldCheck(automaticAllowed: automaticAllowed, done: done) && !hasAnyWeekIdeal
    }

    /// Next? items do not count — an interrupted dump leaves those behind. A
    /// document without the flag (older clients) counts as a week ideal.
    static func hasAnyWeekIdeal(wishlistFlags: [Bool?]) -> Bool {
        wishlistFlags.contains { $0 != true }
    }
}

/// Which run of the F screens this is.
enum DumpFlowMode: Equatable {
    /// A new user's first week: the dump, then the Fs.
    case firstWeek
    /// The second active week's weekly prompt (client, 2026-10-08): straight
    /// to the Fs with last week's ideals, each under its own F, plus the
    /// Next? list. The third week on uses the usual planning flow.
    case secondWeek
}

/// When the weekly prompt walks through the Fs instead of the usual flow.
enum SecondWeekPick {
    /// Distinct weeks before this one that hold an ideal. Next? items
    /// (`startDate` 0), this week and later do not count.
    static func earlierWeekCount(startDates: [TimeInterval],
                                 currentWeekStart: TimeInterval,
                                 weekStartOf: (TimeInterval) -> TimeInterval) -> Int {
        Set(startDates.filter { $0 > 0 && $0 < currentWeekStart }.map(weekStartOf)).count
    }

    /// Exactly one earlier week: this is the second.
    static func isSecondWeek(earlierWeekCount: Int) -> Bool {
        earlierWeekCount == 1
    }

    /// The answer on the weekly prompt card.
    enum CardChoice { case pick, skip }

    /// The walk-through opens only on the user's yes — "Walk Me Through" on
    /// the second week's card. Nothing else opens it.
    static func opensWalkThrough(isSecondWeek: Bool, choice: CardChoice) -> Bool {
        isSecondWeek && choice == .pick
    }
}

enum DumpFlowStage: Equatable {
    /// Write everything down.
    case dump
    /// "Which of these are your …?" — one F per screen, book order, with
    /// the number for each pick on the same screen. Finance saves.
    case sort(Category)
}

struct DumpFlowState: Equatable {
    struct Entry: Equatable, Identifiable {
        /// The Next? item's document id.
        let id: String
        let title: String
        /// Written during this run. Only these can be deleted from the dump;
        /// older Next? items are managed on the Next? page as before.
        let isNew: Bool
        /// Added on an F's own screen; nil for an idea from the dump or the
        /// Next? list.
        var addedFor: Category? = nil
        /// Last week's ideal (second week only): it belongs to this F, is
        /// shown on its screen alone, and is copied into this week if picked.
        var fixedCategory: Category? = nil
    }

    let mode: DumpFlowMode

    init(mode: DumpFlowMode = .firstWeek) {
        self.mode = mode
        stage = mode == .firstWeek ? .dump : .sort(Self.sortOrder[0])
    }

    /// Fix first, then the F Mes, then Everything Else (book §8).
    static let sortOrder: [Category] = Category.allCases

    private(set) var entries: [Entry] = []
    /// Entry id → the F it was hearted for. One F per ideal (book §8).
    private(set) var picks: [String: Category] = [:]
    private var targets: [String: Int] = [:]
    private(set) var stage: DumpFlowStage

    static func cleanTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func contains(title: String) -> Bool {
        let key = Self.cleanTitle(title).lowercased()
        return entries.contains { $0.title.lowercased() == key }
    }

    /// Adds an idea. False for a blank title, a title already in the dump, or
    /// an id already used. `pickedFor` hearts it straight away (an idea added
    /// on an F's own screen). `allowSameTitle` is for loading existing ideals:
    /// last week and the Next? list may share a title.
    @discardableResult
    mutating func add(_ entry: Entry, pickedFor category: Category? = nil,
                      allowSameTitle: Bool = false) -> Bool {
        let title = Self.cleanTitle(entry.title)
        guard !title.isEmpty, allowSameTitle || !contains(title: title),
              !entries.contains(where: { $0.id == entry.id }) else { return false }
        entries.append(Entry(id: entry.id, title: title, isNew: entry.isNew,
                             addedFor: category ?? entry.addedFor,
                             fixedCategory: entry.fixedCategory))
        if let category { picks[entry.id] = category }
        return true
    }

    mutating func remove(id: String) {
        entries.removeAll { $0.id == id }
        picks[id] = nil
        targets[id] = nil
    }

    /// The ideas a pass shows: last week's ideals of this F, and everything
    /// else not taken by another F.
    func entries(for category: Category) -> [Entry] {
        entries.filter { isOffered($0, for: category) }
    }

    private func isOffered(_ entry: Entry, for category: Category) -> Bool {
        if let fixed = entry.fixedCategory { return fixed == category }
        return picks[entry.id] == nil || picks[entry.id] == category
    }

    func isPicked(_ id: String, for category: Category) -> Bool {
        picks[id] == category
    }

    /// Heart / un-heart in a pass. An idea taken by another F is left alone.
    mutating func togglePick(_ id: String, for category: Category) {
        guard let entry = entries.first(where: { $0.id == id }),
              entry.fixedCategory == nil || entry.fixedCategory == category else { return }
        switch picks[id] {
        case nil: picks[id] = category
        case category?: picks[id] = nil
        default: break
        }
    }

    /// Nothing from the dump, last week or the Next? list is left for this F,
    /// so its screen says so (the add field is there either way). Ideas added
    /// on the screen do not count.
    func nothingLeftToPick(for category: Category) -> Bool {
        !entries.contains { $0.addedFor == nil && isOffered($0, for: category) }
    }

    struct Pick: Equatable, Identifiable {
        let entry: Entry
        let category: Category
        var id: String { entry.id }
    }

    /// Picks in book order, then in the order they were dumped.
    var pickedEntries: [Pick] {
        Self.sortOrder.flatMap { category in
            entries.filter { picks[$0.id] == category }.map { Pick(entry: $0, category: category) }
        }
    }

    /// Not picked — these stay on the Next? list.
    var leftovers: [Entry] {
        entries.filter { picks[$0.id] == nil }
    }

    /// How often, 1 by default, 1…6 where 6 reads "6+" (same as the slider).
    func target(for id: String) -> Int {
        targets[id] ?? 1
    }

    mutating func setTarget(_ value: Int, for id: String) {
        targets[id] = min(max(value, 1), HowOftenSlider.stopCount)
    }

    var hasPicks: Bool { !picks.isEmpty }

    var canContinue: Bool {
        stage == .dump ? !entries.isEmpty : true
    }

    var isLastStage: Bool { stage == .sort(Self.sortOrder[Self.sortOrder.count - 1]) }

    mutating func goNext() {
        guard canContinue else { return }
        switch stage {
        case .dump:
            stage = .sort(Self.sortOrder[0])
        case .sort(let category):
            // The last F stays put: its button saves.
            if let index = Self.sortOrder.firstIndex(of: category), index + 1 < Self.sortOrder.count {
                stage = .sort(Self.sortOrder[index + 1])
            }
        }
    }

    mutating func goBack() {
        switch stage {
        case .dump:
            break
        case .sort(let category):
            if let index = Self.sortOrder.firstIndex(of: category), index > 0 {
                stage = .sort(Self.sortOrder[index - 1])
            } else if mode == .firstWeek {
                stage = .dump
            }
        }
    }

    /// What the save hands to `PlanningSheetViewModel.savePlanning`: last
    /// week's picks (copied) and the picked Next? items (moved), each with
    /// its F and its number.
    struct SavePlan: Equatable {
        let lastWeekIds: [String]
        let wishlistIds: [String]
        let categories: [String: String]
        let targets: [String: String]
    }

    /// The picked Next? items `savePlanning` moves into the week (last
    /// week's picks are copied from their own ideals instead).
    var pickedIdeals: [Ideal] {
        pickedEntries.filter { $0.entry.fixedCategory == nil }.map { pick in
            var ideal = Ideal(id: pick.entry.id, title: pick.entry.title)
            ideal.category = pick.category.rawValue
            ideal.wishlistEnabled = true
            return ideal
        }
    }

    var savePlan: SavePlan {
        let picked = pickedEntries
        var categories: [String: String] = [:]
        var targetLabels: [String: String] = [:]
        for pick in picked {
            categories[pick.id] = pick.category.rawValue
            targetLabels[pick.id] = HowOftenSlider.label(for: target(for: pick.id))
        }
        return SavePlan(lastWeekIds: picked.filter { $0.entry.fixedCategory != nil }.map(\.entry.id),
                        wishlistIds: picked.filter { $0.entry.fixedCategory == nil }.map(\.entry.id),
                        categories: categories,
                        targets: targetLabels)
    }
}
