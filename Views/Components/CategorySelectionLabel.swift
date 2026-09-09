//
//  CategorySelectionLabel.swift
//  The Ideal Week
//
//  "Category: Fix" — the section label with the chosen category named beside
//  it, so the icon row underneath needs no text of its own.
//

import SwiftUI

struct CategorySelectionLabel: View {
    let selection: String

    var body: some View {
        HStack(spacing: 6) {
            Text("Category:")
                .foregroundColor(LCColor.ink)
            Text(selection)
                .accentText(.pink)
        }
        .font(.manrope(16, .heavy))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Category: \(selection)")
    }
}
