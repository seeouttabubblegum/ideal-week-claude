//
//  CategoryGroup.swift
//  The Ideal Week
//
//  The book's "3 Fs": how the seven categories group. Read in order, the
//  groups are the seven categories in order — `CategoryOrderTests` holds that,
//  so the groups and `Category.allCases` cannot drift apart.
//

import Foundation

enum CategoryGroup: CaseIterable {
    /// F This — Fix.
    case fThis
    /// F Me — Fitness, Feelings, Faculties.
    case fMe
    /// F Everything Else — Family, Fun, Finance (Fun before Finance since the
    /// client's 2026-09-29 reorganisation).
    case fEverythingElse

    var categories: [Category] {
        switch self {
        case .fThis:           return [.fix]
        case .fMe:             return [.fitness, .feelings, .faculties]
        case .fEverythingElse: return [.family, .fun, .finance]
        }
    }

    /// Outer → centre, as the header's rings icon draws them. Client decision
    /// 2026-07-15: F This sits at the CENTRE pie, F Everything Else on the
    /// outer ring.
    static let ringOrder: [CategoryGroup] = [.fEverythingElse, .fMe, .fThis]

    /// The group's name as the book writes it.
    var title: String {
        switch self {
        case .fThis:           return "F This"
        case .fMe:             return "F Me"
        case .fEverythingElse: return "F Everything Else"
        }
    }

    /// The group a category belongs to.
    static func group(of category: Category) -> CategoryGroup {
        allCases.first { $0.categories.contains(category) } ?? .fThis
    }
}
