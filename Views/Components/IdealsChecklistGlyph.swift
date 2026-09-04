//
//  IdealsChecklistGlyph.swift
//  The Ideal Week
//
//  The "my ideals" mark: a checklist — three horizontal rules, each with a tick
//  to its left. Used by the 1h "My Progress" header (the button back to the
//  list) and by the menu drawer's "My Ideals" row, so both entry points to the
//  list carry the same symbol.
//
//  Replaces the handoff's five vertical bars / the SF symbol
//  `lines.measurement.vertical`: both read as an audio waveform rather than a
//  list (client call, 2026-08-11). Don't "restore the handoff icon" here
//  without asking.
//
//  Stroke width and colour come from the caller's `.stroke(...)`, which should
//  use round caps AND round joins so the ticks look drawn rather than cut.
//

import SwiftUI

struct IdealsChecklistGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 28, sy = rect.height / 28
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        // Rows evenly spaced; each tick's elbow sits just under its rule so the
        // pair reads as one line item.
        for y in [6.5, 14.0, 21.5] as [CGFloat] {
            // tick
            path.move(to: p(2, y + 0.5))
            path.addLine(to: p(4.5, y + 3))
            path.addLine(to: p(8.5, y - 2.5))
            // rule
            path.move(to: p(12.5, y))
            path.addLine(to: p(26, y))
        }
        return path
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        IdealsChecklistGlyph()
            .stroke(LCColor.pink, style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
            .frame(width: 26, height: 26)
        IdealsChecklistGlyph()
            .stroke(Color(hex: 0x181818), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .frame(width: 28, height: 28)
    }
    .padding(40)
    .background(LCColor.surface)
}
#endif
