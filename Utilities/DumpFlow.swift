//
//  DumpFlow.swift
//  The Ideal Week
//
//  The first-week dump (client, 2026-10-02; book chapter 9). A new user
//  writes down every idea first — the dump is the Next? list in disguise, so
//  each idea is saved as a Next? (wishlist) item the moment it is added. The
//  ideas are then sorted one F at a time in the book's order, empty Fs get a
//  chance to be filled, and each pick gets its number. Picks move into the
//  CURRENT week; whatever is left waits on Next? for week two.
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

enum DumpFlowStage: Equatable {
    /// Write everything down.
    case dump
    /// "Which of these are your …?" — one F per screen, book order.
    case sort(Category)
    /// Fs nothing was hearted for.
    case fillEmpty
    /// One number per pick, then save.
    case howOften
}

struct DumpFlowState: Equatable {
    struct Entry: Equatable, Identifiable {
        /// The Next? item's document id.
        let id: String
        let title: String
        /// Written during this run. Only these can be deleted from the dump;
        /// older Next? items are managed on the Next? page as before.
        let isNew: Bool
    }

    /// Fix first, then the F Mes, then Everything Else (book §8).
    static let sortOrder: [Category] = Category.allCases

    private(set) var entries: [Entry] = []
    /// Entry id → the F it was hearted for. One F per ideal (book §8).
    private(set) var picks: [String: Category] = [:]
    private var targets: [String: Int] = [:]
    private(set) var stage: DumpFlowStage = .dump
    /// The fill screen was shown on the way forward, so Back returns to it.
    private var showedFillEmpty = false

    static func cleanTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func contains(title: String) -> Bool {
        let key = Self.cleanTitle(title).lowercased()
        return entries.contains { $0.title.lowercased() == key }
    }

    /// Adds an idea. False for a blank title, a title already in the dump, or
    /// an id already used. `pickedFor` hearts it straight away (the fill
    /// screen adds ideas for a named F).
    @discardableResult
    mutating func add(_ entry: Entry, pickedFor category: Category? = nil) -> Bool {
        let title = Self.cleanTitle(entry.title)
        guard !title.isEmpty, !contains(title: title),
              !entries.contains(where: { $0.id == entry.id }) else { return false }
        entries.append(Entry(id: entry.id, title: title, isNew: entry.isNew))
        if let category { picks[entry.id] = category }
        return true
    }

    mutating func remove(id: String) {
        entries.removeAll { $0.id == id }
        picks[id] = nil
        targets[id] = nil
    }

    /// The ideas a pass shows: everything not taken by another F.
    func entries(for category: Category) -> [Entry] {
        entries.filter { picks[$0.id] == nil || picks[$0.id] == category }
    }

    func isPicked(_ id: String, for category: Category) -> Bool {
        picks[id] == category
    }

    /// Heart / un-heart in a pass. An idea taken by another F is left alone.
    mutating func togglePick(_ id: String, for category: Category) {
        guard entries.contains(where: { $0.id == id }) else { return }
        switch picks[id] {
        case nil: picks[id] = category
        case category?: picks[id] = nil
        default: break
        }
    }

    var emptyCategories: [Category] {
        let used = Set(picks.values)
        return Self.sortOrder.filter { !used.contains($0) }
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

    var canContinue: Bool {
        stage == .dump ? !entries.isEmpty : true
    }

    var isLastStage: Bool { stage == .howOften }

    mutating func goNext() {
        guard canContinue else { return }
        switch stage {
        case .dump:
            stage = .sort(Self.sortOrder[0])
        case .sort(let category):
            if let index = Self.sortOrder.firstIndex(of: category), index + 1 < Self.sortOrder.count {
                stage = .sort(Self.sortOrder[index + 1])
            } else {
                showedFillEmpty = !emptyCategories.isEmpty
                stage = showedFillEmpty ? .fillEmpty : .howOften
            }
        case .fillEmpty:
            stage = .howOften
        case .howOften:
            break
        }
    }

    mutating func goBack() {
        switch stage {
        case .dump:
            break
        case .sort(let category):
            if let index = Self.sortOrder.firstIndex(of: category), index > 0 {
                stage = .sort(Self.sortOrder[index - 1])
            } else {
                stage = .dump
            }
        case .fillEmpty:
            stage = .sort(Self.sortOrder[Self.sortOrder.count - 1])
        case .howOften:
            stage = showedFillEmpty ? .fillEmpty : .sort(Self.sortOrder[Self.sortOrder.count - 1])
        }
    }

    /// What the save hands to `PlanningSheetViewModel.savePlanning`: the
    /// picked Next? items, each with its F and its number.
    struct SavePlan: Equatable {
        let wishlistIds: [String]
        let categories: [String: String]
        let targets: [String: String]
    }

    /// The picks as the Next? items `savePlanning` moves into the week.
    var pickedIdeals: [Ideal] {
        pickedEntries.map { pick in
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
        return SavePlan(wishlistIds: picked.map(\.entry.id),
                        categories: categories,
                        targets: targetLabels)
    }
}
