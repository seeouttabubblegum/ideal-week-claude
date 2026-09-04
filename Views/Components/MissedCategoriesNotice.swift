//
//  MissedCategoriesNotice.swift
//  The Ideal Week
//
//  Moved out of PlanningSheetView (2026-09-04) verbatim. Behaviour unchanged.
//

import SwiftUI

/// Reactive category-coverage notice shown under the "Missed Anything?" title.
///
/// It only exists for users who landed on the step with gaps: it names the
/// categories that still have no ideal, drops each one as soon as a draft covers
/// it, and flips to the all-clear line when the last gap is filled. Kept as its
/// own View so the type-checker solves it in isolation — inlining it into the
/// step's already-large ViewBuilder made compilation explode.
struct MissedCategoriesNotice: View {
    /// Categories with no ideal if the plan were saved right now.
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
        Group {
            if stillMissing.isEmpty {
                Text("You are all caught up now!")
                    .font(.manrope(15, .heavy))
                    .foregroundColor(LCColor.blue)
            } else {
                Text(Self.message(stillMissing))
                    .font(.manrope(15, .medium))
                    .foregroundColor(LCColor.deepPink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .neuSunken(cornerRadius: 16)
        .padding(.horizontal, LCMetrics.screenMargin)
        .accessibilityElement(children: .combine)
    }
}
