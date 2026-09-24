//
//  MissedCategoriesNotice.swift
//  The Ideal Week
//
//  Moved out of PlanningSheetView (2026-09-04). Since 2026-09-16 it is hidden,
//  not replaced by an all-clear line, once nothing is missing.
//

import SwiftUI

/// Category-coverage notice on the "Missed Anything?" step.
///
/// Names the categories that would still have no ideal if the plan were saved
/// now. The step shows it only while that list is non-empty, so it drops each
/// category as soon as something covers it and disappears with the last one.
/// Kept as its own View so the type-checker solves it in isolation — inlining it
/// into the step's already-large ViewBuilder made compilation explode.
struct MissedCategoriesNotice: View {
    /// Categories with no ideal if the plan were saved right now. Never empty.
    let stillMissing: [String]

    /// "Fix", "Fix and Fun", "Fix, Family and Fun".
    static func listPhrase(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return names[0] + " and " + names[1]
        default:
            let head = names.dropLast().joined(separator: ", ")
            return head + " and " + (names.last ?? "")
        }
    }

    static func message(_ names: [String]) -> String {
        let tail = names.count == 1 ? "Add one below, or save as is." : "Add them below, or save as is."
        return "You haven't picked anything for " + listPhrase(names) + " this week. " + tail
    }

    var body: some View {
        Text(Self.message(stillMissing))
            .font(.manrope(15, .medium))
            .accentText(.pink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .neuSunken(cornerRadius: 16)
            .padding(.horizontal, LCMetrics.screenMargin)
            .accessibilityElement(children: .combine)
    }
}
