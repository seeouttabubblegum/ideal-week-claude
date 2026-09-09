//
//  CategoryTabBar.swift
//  The Ideal Week
//
//  The seven categories as a row of icon-only chips: selected raised and filled
//  with the primary accent, the rest sunken. Every chip takes an equal share of
//  the row so all seven fit at any width — fixed widths plus gaps used to sum
//  past the screen, which is why this once needed a horizontal scroll.
//
//  Icon-only on purpose (client, 2026-08-28): the chosen category is named once,
//  underneath the bar, instead of seven times inside it.
//
//  Extracted from `TopIdealsHistorySection` so the weekly recap's History browser
//  shows the same control rather than its own icon+text variant.
//

import SwiftUI

struct CategoryTabBar: View {
    @Binding var selection: Category

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Category.allCases, id: \.id) { cat in
                chip(cat)
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .padding(.vertical, 8)
    }

    private func chip(_ cat: Category) -> some View {
        let isSelected = selection == cat
        return Button {
            HapticFeedback.selection()
            withAnimation { selection = cat }
        } label: {
            Image(cat.lcCategoryIconV2())
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(isSelected ? LCColor.contrastingInk(on: LCColor.pink) : LCColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: LCRadius.chip, style: .continuous)
                                .fill(LCColor.pink)
                                .shadow(color: LCColor.shadowDark, radius: 3.5, x: 3, y: 3)
                                .shadow(color: LCColor.shadowLight, radius: 3.5, x: -3, y: -3)
                        } else {
                            RoundedRectangle(cornerRadius: LCRadius.chip, style: .continuous)
                                .fill(
                                    LCColor.surface
                                        .shadow(.inner(color: LCColor.shadowDark, radius: 3, x: 3, y: 3))
                                        .shadow(.inner(color: LCColor.shadowLight, radius: 3, x: -3, y: -3))
                                )
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cat.rawValue)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// The chosen category's name, as it sits under the bar on both screens.
struct CategoryTabBarSelectionLabel: View {
    let selection: Category

    var body: some View {
        Text(selection.rawValue)
            .font(.hhSamuel(20))
            .textCase(.uppercase)
            .accentText(.pink)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .animation(nil, value: selection)
    }
}
