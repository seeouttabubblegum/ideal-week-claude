//
//  GroupedProgressRingsIcon.swift
//  The Ideal Week
//
//  A compact dynamic circular-chart icon for the ideal-list header. Mirrors the
//  ribbon/ring chart on the progress page, but GROUPED into the book's "3 Fs"
//  (outer → center): F EVERYTHING ELSE (Family, Finance, Fun) · F ME (Fitness,
//  Feelings, Faculties) · F THIS (Fix) at the CENTER pie (client decision
//  2026-07-15). Per the neumorphic handoff the icon is two concentric
//  palette-coloured rings around a central radial PIE that fills
//  COUNTERCLOCKWISE from 12 o'clock, proportional to completions.
//  Static fill (updates on completion) — it never spins.
//

import SwiftUI

struct GroupedProgressRingsIcon: View {
    /// One 0…1 completion value per element, outer → center:
    /// [outer ring, inner ring, center pie] (expects 3).
    var progress: [Double]
    /// Palette colours, outer → center: outer ring, inner ring, centre pie.
    /// Defaults follow the handoff header (pink ring · warm-yellow ring · blue
    /// pie — the mock's green maps to the palette's warm yellow, no green
    /// allowed). Pass 3 ink colours for the monochrome menu-drawer variant.
    var ringColors: [Color] = [LCColor.pink, LCColor.yellowAlt, LCColor.blue]
    var lineWidth: CGFloat = 3.0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            // Geometry lifted from the handoff's 40pt viewBox (rings r18.5 /
            // r14.7, pie ⌀22) and scaled to whatever frame we're given.
            let scale = size / 40
            let stroke = lineWidth * scale
            ZStack {
                ring(value: value(0), color: color(0), diameter: 37 * scale, stroke: stroke)
                ring(value: value(1), color: color(1), diameter: 29.4 * scale, stroke: stroke)
                // Centre pie — faint full track behind a solid wedge that
                // fills counterclockwise starting at 12 o'clock.
                Circle()
                    .fill(color(2).opacity(0.18))
                    .frame(width: 22 * scale, height: 22 * scale)
                CounterclockwisePie(fraction: value(2))
                    .fill(color(2))
                    .frame(width: 22 * scale, height: 22 * scale)
                    .animation(.easeInOut(duration: 0.35), value: value(2))
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    /// Faint full-circle track + progress arc sweeping clockwise from the top —
    /// every group stays visible even at 0 progress, and the arc pops against it.
    private func ring(value: Double, color: Color, diameter: CGFloat, stroke: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.22), lineWidth: stroke)
            // At exactly zero the rounded line cap used to paint a lone dot at
            // 12 o'clock (trim was floored at 0.0001) — draw nothing instead.
            Circle()
                .trim(from: 0, to: max(0, value))
                .stroke(color, style: StrokeStyle(lineWidth: stroke,
                                                  lineCap: value > 0.001 ? .round : .butt))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: value)
        }
        .frame(width: diameter, height: diameter)
    }

    private func value(_ index: Int) -> Double {
        guard index < progress.count else { return 0 }
        return min(1, max(0, progress[index]))
    }

    private func color(_ index: Int) -> Color {
        guard !ringColors.isEmpty else { return LCColor.pink }
        return ringColors[index % ringColors.count]
    }
}

/// Filled pie wedge anchored at 12 o'clock that grows COUNTERCLOCKWISE
/// (handoff rule for the header progress pie).
private struct CounterclockwisePie: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let f = min(1, max(0, fraction))
        guard f > 0 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        // In SwiftUI's flipped (y-down) coordinate space a decreasing angle
        // (clockwise: true) sweeps visually counterclockwise from 12 o'clock.
        path.addArc(center: center,
                    radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 - 360 * f),
                    clockwise: true)
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 24) {
        GroupedProgressRingsIcon(progress: [0.8, 0.6, 0.63])
            .frame(width: 42, height: 42)
        // Monochrome ink variant (menu drawer "Progress" glyph).
        GroupedProgressRingsIcon(progress: [0.8, 0.6, 0.63],
                                 ringColors: [Color(hex: 0x181818), Color(hex: 0x181818), Color(hex: 0x181818)])
            .frame(width: 34, height: 34)
    }
    .padding(40)
    .background(LCColor.surface)
}
