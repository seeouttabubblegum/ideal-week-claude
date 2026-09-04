//
//  HeartDoneShape.swift
//  The Ideal Week
//
//  Vector path of the LC hand-drawn "Line Done" heart (SVG viewBox 0 0 300 300),
//  used to draw the heart on with an animated .trim mask.
//

import SwiftUI

struct HeartDoneShape: Shape {
    /// 0…1 fraction of the pen-draw. BOTH ribbon outlines (the outer and inner
    /// edges of the hand-drawn heart) advance to THIS SAME fraction in parallel —
    /// see path(in:). A plain `.trim` on the whole shape would instead trace the
    /// outer outline to completion and then the inner one on top of it (the
    /// "double-draw / thickening" bug), because trim parameterises by the combined
    /// length of both subpaths.
    var trimTo: CGFloat = 1

    var animatableData: CGFloat {
        get { trimTo }
        set { trimTo = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 300.0
        let t = max(0, min(1, trimTo))
        var combined = Path()
        // Trim each subpath to the SAME fraction so the two edges grow together as
        // one stroke. At t = 1 both are fully traced → identical to the full art.
        combined.addPath(Self.outer(s).trimmedPath(from: 0, to: t))
        combined.addPath(Self.inner(s).trimmedPath(from: 0, to: t))
        return combined
    }

    /// Outer edge of the heart ribbon (one closed subpath).
    private static func outer(_ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 274.07*s, y: 24.12*s))
        p.addLine(to: CGPoint(x: 272.94*s, y: 13.15*s))
        p.addCurve(to: CGPoint(x: 265.09*s, y: 2.99*s), control1: CGPoint(x: 272.43*s, y: 8.17*s), control2: CGPoint(x: 270.59*s, y: 4.32*s))
        p.addCurve(to: CGPoint(x: 199.37*s, y: 23.99*s), control1: CGPoint(x: 248.67*s, y: -1.00*s), control2: CGPoint(x: 215.57*s, y: 14.20*s))
        p.addLine(to: CGPoint(x: 141.82*s, y: 58.77*s))
        p.addCurve(to: CGPoint(x: 137.52*s, y: 53.38*s), control1: CGPoint(x: 139.26*s, y: 57.76*s), control2: CGPoint(x: 138.90*s, y: 55.03*s))
        p.addCurve(to: CGPoint(x: 94.19*s, y: 19.45*s), control1: CGPoint(x: 124.28*s, y: 37.50*s), control2: CGPoint(x: 112.18*s, y: 28.57*s))
        p.addCurve(to: CGPoint(x: 71.58*s, y: 12.64*s), control1: CGPoint(x: 86.82*s, y: 15.71*s), control2: CGPoint(x: 79.64*s, y: 14.35*s))
        p.addCurve(to: CGPoint(x: 46.98*s, y: 14.12*s), control1: CGPoint(x: 63.09*s, y: 10.83*s), control2: CGPoint(x: 55.56*s, y: 10.40*s))
        p.addCurve(to: CGPoint(x: 25.67*s, y: 52.26*s), control1: CGPoint(x: 32.93*s, y: 20.20*s), control2: CGPoint(x: 24.10*s, y: 37.33*s))
        p.addCurve(to: CGPoint(x: 39.64*s, y: 86.33*s), control1: CGPoint(x: 26.99*s, y: 64.87*s), control2: CGPoint(x: 31.77*s, y: 76.59*s))
        p.addLine(to: CGPoint(x: 49.89*s, y: 99.01*s))
        p.addLine(to: CGPoint(x: 65.54*s, y: 115.37*s))
        p.addCurve(to: CGPoint(x: 109.87*s, y: 153.43*s), control1: CGPoint(x: 80.38*s, y: 130.88*s), control2: CGPoint(x: 92.82*s, y: 140.87*s))
        p.addCurve(to: CGPoint(x: 136.95*s, y: 172.54*s), control1: CGPoint(x: 118.91*s, y: 160.09*s), control2: CGPoint(x: 127.83*s, y: 166.00*s))
        p.addLine(to: CGPoint(x: 142.14*s, y: 176.26*s))
        p.addCurve(to: CGPoint(x: 159.90*s, y: 188.66*s), control1: CGPoint(x: 148.17*s, y: 180.58*s), control2: CGPoint(x: 153.73*s, y: 184.72*s))
        p.addLine(to: CGPoint(x: 172.68*s, y: 196.82*s))
        p.addLine(to: CGPoint(x: 163.87*s, y: 215.19*s))
        p.addCurve(to: CGPoint(x: 141.78*s, y: 295.94*s), control1: CGPoint(x: 155.42*s, y: 232.82*s), control2: CGPoint(x: 126.20*s, y: 284.82*s))
        p.addCurve(to: CGPoint(x: 160.87*s, y: 290.98*s), control1: CGPoint(x: 147.41*s, y: 299.96*s), control2: CGPoint(x: 157.93*s, y: 296.36*s))
        p.addCurve(to: CGPoint(x: 161.12*s, y: 278.25*s), control1: CGPoint(x: 163.24*s, y: 286.65*s), control2: CGPoint(x: 160.02*s, y: 282.17*s))
        p.addLine(to: CGPoint(x: 166.27*s, y: 259.84*s))
        p.addCurve(to: CGPoint(x: 181.30*s, y: 226.76*s), control1: CGPoint(x: 170.47*s, y: 248.20*s), control2: CGPoint(x: 175.60*s, y: 237.60*s))
        p.addLine(to: CGPoint(x: 191.46*s, y: 207.42*s))
        p.addCurve(to: CGPoint(x: 200.35*s, y: 204.03*s), control1: CGPoint(x: 194.21*s, y: 206.31*s), control2: CGPoint(x: 197.35*s, y: 204.28*s))
        p.addCurve(to: CGPoint(x: 204.23*s, y: 203.96*s), control1: CGPoint(x: 201.63*s, y: 204.46*s), control2: CGPoint(x: 203.32*s, y: 204.81*s))
        p.addCurve(to: CGPoint(x: 205.33*s, y: 201.62*s), control1: CGPoint(x: 204.76*s, y: 203.47*s), control2: CGPoint(x: 205.72*s, y: 203.05*s))
        p.addCurve(to: CGPoint(x: 201.76*s, y: 197.48*s), control1: CGPoint(x: 204.99*s, y: 200.40*s), control2: CGPoint(x: 201.46*s, y: 199.75*s))
        p.addCurve(to: CGPoint(x: 203.21*s, y: 196.93*s), control1: CGPoint(x: 201.86*s, y: 196.72*s), control2: CGPoint(x: 202.79*s, y: 196.79*s))
        p.addLine(to: CGPoint(x: 205.17*s, y: 197.58*s))
        p.addCurve(to: CGPoint(x: 204.04*s, y: 189.59*s), control1: CGPoint(x: 207.20*s, y: 195.54*s), control2: CGPoint(x: 207.19*s, y: 191.52*s))
        p.addCurve(to: CGPoint(x: 201.93*s, y: 186.12*s), control1: CGPoint(x: 203.24*s, y: 189.10*s), control2: CGPoint(x: 201.23*s, y: 187.44*s))
        p.addLine(to: CGPoint(x: 230.71*s, y: 131.43*s))
        p.addLine(to: CGPoint(x: 240.62*s, y: 112.13*s))
        p.addCurve(to: CGPoint(x: 262.20*s, y: 69.61*s), control1: CGPoint(x: 247.96*s, y: 97.84*s), control2: CGPoint(x: 255.69*s, y: 84.29*s))
        p.addLine(to: CGPoint(x: 268.75*s, y: 54.87*s))
        p.addLine(to: CGPoint(x: 272.10*s, y: 41.40*s))
        p.addCurve(to: CGPoint(x: 274.08*s, y: 24.13*s), control1: CGPoint(x: 275.05*s, y: 35.79*s), control2: CGPoint(x: 274.72*s, y: 30.40*s))
        p.closeSubpath()
        return p
    }

    /// Inner edge of the heart ribbon (the second closed subpath).
    private static func inner(_ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 254.42*s, y: 42.61*s))
        p.addCurve(to: CGPoint(x: 234.97*s, y: 83.30*s), control1: CGPoint(x: 249.08*s, y: 56.95*s), control2: CGPoint(x: 242.50*s, y: 70.03*s))
        p.addLine(to: CGPoint(x: 219.32*s, y: 110.88*s))
        p.addLine(to: CGPoint(x: 206.08*s, y: 136.82*s))
        p.addLine(to: CGPoint(x: 198.98*s, y: 148.81*s))
        p.addLine(to: CGPoint(x: 190.17*s, y: 166.14*s))
        p.addLine(to: CGPoint(x: 184.19*s, y: 176.24*s))
        p.addCurve(to: CGPoint(x: 177.37*s, y: 172.31*s), control1: CGPoint(x: 180.82*s, y: 175.96*s), control2: CGPoint(x: 179.44*s, y: 173.58*s))
        p.addLine(to: CGPoint(x: 160.49*s, y: 161.96*s))
        p.addLine(to: CGPoint(x: 132.32*s, y: 141.85*s))
        p.addLine(to: CGPoint(x: 105.20*s, y: 121.92*s))
        p.addLine(to: CGPoint(x: 91.63*s, y: 109.32*s))
        p.addCurve(to: CGPoint(x: 50.65*s, y: 61.92*s), control1: CGPoint(x: 78.18*s, y: 96.83*s), control2: CGPoint(x: 57.21*s, y: 77.52*s))
        p.addCurve(to: CGPoint(x: 47.87*s, y: 42.58*s), control1: CGPoint(x: 48.20*s, y: 56.09*s), control2: CGPoint(x: 45.47*s, y: 49.00*s))
        p.addCurve(to: CGPoint(x: 68.50*s, y: 33.22*s), control1: CGPoint(x: 50.70*s, y: 35.04*s), control2: CGPoint(x: 60.35*s, y: 31.73*s))
        p.addCurve(to: CGPoint(x: 122.29*s, y: 70.28*s), control1: CGPoint(x: 90.87*s, y: 37.32*s), control2: CGPoint(x: 109.42*s, y: 51.41*s))
        p.addCurve(to: CGPoint(x: 101.75*s, y: 86.63*s), control1: CGPoint(x: 117.01*s, y: 78.64*s), control2: CGPoint(x: 106.28*s, y: 76.02*s))
        p.addCurve(to: CGPoint(x: 103.58*s, y: 100.65*s), control1: CGPoint(x: 99.83*s, y: 91.14*s), control2: CGPoint(x: 99.63*s, y: 96.76*s))
        p.addCurve(to: CGPoint(x: 116.97*s, y: 102.98*s), control1: CGPoint(x: 106.32*s, y: 103.35*s), control2: CGPoint(x: 113.55*s, y: 104.96*s))
        p.addLine(to: CGPoint(x: 132.17*s, y: 94.18*s))
        p.addCurve(to: CGPoint(x: 134.30*s, y: 99.87*s), control1: CGPoint(x: 134.30*s, y: 95.58*s), control2: CGPoint(x: 133.46*s, y: 98.61*s))
        p.addCurve(to: CGPoint(x: 152.61*s, y: 100.57*s), control1: CGPoint(x: 138.41*s, y: 106.11*s), control2: CGPoint(x: 148.22*s, y: 106.70*s))
        p.addCurve(to: CGPoint(x: 151.97*s, y: 80.17*s), control1: CGPoint(x: 156.64*s, y: 94.94*s), control2: CGPoint(x: 155.48*s, y: 87.37*s))
        p.addLine(to: CGPoint(x: 165.44*s, y: 71.05*s))
        p.addLine(to: CGPoint(x: 197.85*s, y: 50.27*s))
        p.addCurve(to: CGPoint(x: 248.34*s, y: 25.51*s), control1: CGPoint(x: 213.86*s, y: 40.01*s), control2: CGPoint(x: 230.46*s, y: 31.90*s))
        p.addCurve(to: CGPoint(x: 257.85*s, y: 24.57*s), control1: CGPoint(x: 251.44*s, y: 24.40*s), control2: CGPoint(x: 254.54*s, y: 23.90*s))
        p.addCurve(to: CGPoint(x: 254.38*s, y: 42.61*s), control1: CGPoint(x: 258.06*s, y: 30.93*s), control2: CGPoint(x: 256.55*s, y: 36.77*s))
        p.closeSubpath()
        return p
    }}

#if DEBUG
#Preview {
    HeartDoneShape()
        .stroke(LCColor.pink, lineWidth: 3)
        .frame(width: 200, height: 200)
        .padding()
}
#endif
