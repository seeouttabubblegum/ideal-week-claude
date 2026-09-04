//
//  AuthLabel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 16/8/25.
//
//  2026-07 neumorphic redesign: renders the book-cover brand header used on
//  the full-bleed pink auth screens (5a Login / 5b Register) — the stacked
//  "THE IDEAL WEEK" wordmark in HH Samuel blue with the hard cover shadow,
//  plus the full-width "AN APP TO F UP YOUR LIFE*" subtitle in
//  Open Sans Condensed Bold (yellow over a blue offset, cover style).
//

import SwiftUI

/// Cover yellow used on the pink auth screens (#EDEF12 in the handoff HTML —
/// slightly brighter than `LCColor.yellow`).
private let coverYellow = Color(hex: 0xEDEF12)

struct AuthLabel: View {
    let type: String

    /// Login shows the wordmark at 56pt, Register/others at 50pt (handoff 5a/5b).
    private var wordmarkSize: CGFloat { type == "login" ? 56 : 50 }

    var body: some View {
        VStack(spacing: 16) {
            // Stacked wordmark — lines left-aligned, block centered,
            // tight leading (handoff line-height 0.82), hard cover shadow.
            VStack(alignment: .leading, spacing: -wordmarkSize * 0.18) {
                Text("THE")
                Text("IDEAL")
                Text("WEEK")
            }
            .font(.hhSamuel(wordmarkSize))
            .foregroundColor(LCColor.blue)
            .shadow(color: .black.opacity(0.14), radius: 0, x: 3, y: 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("The Ideal Week")

            // Subtitle spans the full content width (cover treatment):
            // oversized font scaled down to exactly fit one line.
            Text("AN APP TO F UP YOUR LIFE*")
                .font(.coverSubtitle(40))
                .italic()
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .foregroundColor(coverYellow)
                .shadow(color: LCColor.blue, radius: 0, x: 2, y: 3)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    AuthLabel(type: "login")
        .padding(34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LCColor.deepPinkFill)
}
