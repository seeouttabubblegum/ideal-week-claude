//
//  DoneHeartView.swift
//  The Ideal Week
//
//  Moved out of IdealListView (2026-09-04) verbatim. Behaviour unchanged.
//

import SwiftUI

/// The "DONE!" heart that self-draws when revealed on a right-swipe. The real
/// LC hand-drawn heart art is painted in via a soft left→right reveal mask that
/// animates 0→1 once on appear, so it reads like the heart is being drawn.
struct DoneHeartView: View {
    /// Swipe progress 0…1 — the heart traces on as the user swipes right.
    var progress: Double
    var body: some View {
        // Ease-IN the swipe→draw mapping (draw = progress²): the pen starts slow so
        // the trace reads clearly, then accelerates to cover the heart near the end
        // of the swipe. It still reaches a full heart exactly at full swipe, and —
        // because `draw` is a pure function of live swipe `progress` — swiping BACK
        // lowers progress → lowers draw → the heart un-draws in reverse.
        let p = CGFloat(min(1, max(0, progress)))
        let draw = p * p
        // "DONE!" fades in over the last 15% of the draw.
        let labelIn = max(0, min(1, (draw - 0.85) / 0.15))
        VStack(spacing: 2) {
            // Draw the ORIGINAL filled heart art on, progressively, by revealing it
            // through a mask that grows along the ribbon. Both ribbon edges are
            // trimmed in PARALLEL and stroked thick enough to bridge into one solid
            // band — so the heart fills in as a single solid stroke (never a double
            // outline) and is fully shown (identical to the original icon) exactly at
            // draw = 1. Because `draw` is a pure function of live swipe `progress`,
            // swiping back un-draws it in reverse.
            Image("Line Done_Pink")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(LCColor.glyph(.pink))
                .scaledToFit()
                .frame(width: 32, height: 32)
                .mask(
                    HeartDoneShape(trimTo: draw)
                        .stroke(style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 32, height: 32)
                )
            Text("DONE!")
                .font(.manrope(14, .heavy))
                .accentText(.pink)
                .lineLimit(1)
                .fixedSize()
                .opacity(labelIn)
        }
    }
}
