//
//  CategoryRadarChart.swift
//  The Ideal Week
//
//  A radar (spider) chart that overlays TWO smooth-curved shapes on the same category axes:
//   - Completion (pink) on top, semi-transparent.
//   - Average review (blue) underneath.
//  Both share a 0…100% radial ring drawn over a SUNKEN neumorphic well. Swift Charts has no
//  radar type, so this is drawn with a SwiftUI Canvas (closed Catmull-Rom splines for the
//  curved boundaries).
//

import SwiftUI

struct CategoryRadarChart: View {
    let axes: [RadarAxis]

    // Computed, not `let`: a `static let` is initialised once per process and
    // would freeze whichever palette was active the first time this chart was
    // drawn. These are thin overlay outlines, so they take the ink tokens.
    static var completionColor: Color { LCColor.pink } // completion overlay (primary accent)
    static var reviewColor: Color { LCColor.blue }     // review overlay (secondary accent)

    @State private var selectedAxis: Int? = nil

    private let ringSteps = 4 // 25/50/75/100 rings (plus the center)

    /// The section places the legend under its own title (client, 2026-08-28);
    /// standalone uses keep it below the chart.
    var showsLegend: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let geom = RadarGeometry(
                    size: geo.size,
                    axisCount: axes.count,
                    inset: 38 // room for the category labels around the rim
                )
                ZStack {
                    // Sunken circular well behind the radial grid (radar backgrounds are SUNKEN).
                    Circle()
                        .fill(
                            LCColor.surface
                                .shadow(.inner(color: LCColor.shadowDark, radius: 7, x: 6, y: 6))
                                .shadow(.inner(color: LCColor.shadowLight, radius: 7, x: -6, y: -6))
                        )
                        .frame(width: (geom.radius + 10) * 2, height: (geom.radius + 10) * 2)
                        .position(geom.center)

                    Canvas { context, _ in
                        drawGrid(context: context, geom: geom)
                        // Review underneath, completion on top.
                        drawOverlay(context: context, geom: geom,
                                    values: axes.map { $0.reviewPlotted },
                                    color: Self.reviewColor)
                        drawOverlay(context: context, geom: geom,
                                    values: axes.map { $0.completion },
                                    color: Self.completionColor)
                        drawAxisLabels(context: context, geom: geom)
                    }

                    // Tap targets sit ONLY on the rim labels. The chart face
                    // itself takes no gesture at all — a full-surface
                    // DragGesture(minimumDistance: 0) was swallowing the page's
                    // scroll whenever the finger landed on the graph
                    // (client, 2026-08-28). Discrete taps on these small spots
                    // do not block scrolling that starts over them.
                    ForEach(axes.indices, id: \.self) { i in
                        Color.clear
                            .frame(width: 56, height: 40)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedAxis = (selectedAxis == i) ? nil : i
                                }
                            }
                            .position(geom.labelPoint(axis: i))
                    }

                    if let idx = selectedAxis, axes.indices.contains(idx) {
                        tooltip(for: axes[idx])
                            .position(tooltipPosition(idx: idx, geom: geom))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .animation(.easeInOut(duration: 0.35), value: axes)

            if showsLegend {
                legend
            }
        }
    }

    // MARK: - Legend

    var legend: some View {
        HStack(spacing: 20) {
            legendItem(color: Self.completionColor, label: "Completion")
            legendItem(color: Self.reviewColor, label: "Review")
        }
        .font(.manrope(13, .bold))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.85))
                .frame(width: 16, height: 16)
            Text(label)
                .foregroundColor(LCColor.textSecondary)
        }
    }

    // MARK: - Tooltip

    private func tooltip(for axis: RadarAxis) -> some View {
        let completionPct = Int((axis.completion * 100).rounded())
        let reviewText = axis.reviewDisplay.map { "\(ReviewScoreScale.formattedDisplay($0))/7" } ?? "—"
        return VStack(spacing: 2) {
            Text(axis.category.rawValue)
                .font(.manrope(13, .heavy))
                .foregroundColor(LCColor.ink)
            Text("Completion \(completionPct)% · Review \(reviewText)")
                .font(.manrope(11, .medium))
                .foregroundColor(LCColor.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: LCRadius.chip)
                .fill(LCColor.surface)
                .shadow(color: LCColor.shadowDark, radius: 3.5, x: 3, y: 3)
                .shadow(color: LCColor.shadowLight, radius: 3.5, x: -3, y: -3)
        )
        .overlay(RoundedRectangle(cornerRadius: LCRadius.chip).stroke(Neumorphic.edgeStroke))
        .fixedSize()
    }

    private func tooltipPosition(idx: Int, geom: RadarGeometry) -> CGPoint {
        // Pin near the selected axis vertex (at the larger of the two overlay radii), nudged inward.
        let r = max(axes[idx].completion, axes[idx].reviewPlotted)
        let p = geom.point(axis: idx, value: max(0.18, r))
        return CGPoint(x: geom.center.x + (p.x - geom.center.x) * 0.7,
                       y: geom.center.y + (p.y - geom.center.y) * 0.7)
    }

    // MARK: - Drawing

    private func drawGrid(context: GraphicsContext, geom: RadarGeometry) {
        let gridColor = LCColor.dividerGrey.opacity(0.4)
        // Concentric polygon rings.
        for step in 1...ringSteps {
            let frac = Double(step) / Double(ringSteps)
            var path = Path()
            for i in 0..<geom.axisCount {
                let p = geom.point(axis: i, value: frac)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(gridColor), lineWidth: 1)
        }
        // Spokes + % tick labels along the top (vertical) axis.
        for i in 0..<geom.axisCount {
            var spoke = Path()
            spoke.move(to: geom.center)
            spoke.addLine(to: geom.point(axis: i, value: 1))
            context.stroke(spoke, with: .color(gridColor), lineWidth: 1)
        }
        for step in 0...ringSteps {
            let frac = Double(step) / Double(ringSteps)
            let pct = Int(frac * 100)
            let p = geom.point(axis: 0, value: frac)
            context.draw(
                Text("\(pct)%").font(.manrope(9, .medium)).foregroundColor(LCColor.textMuted),
                at: CGPoint(x: p.x + 12, y: p.y - 2),
                anchor: .leading
            )
        }
    }

    private func drawOverlay(context: GraphicsContext, geom: RadarGeometry, values: [Double], color: Color) {
        guard values.count == geom.axisCount, geom.axisCount >= 3 else { return }
        let points = (0..<geom.axisCount).map { geom.point(axis: $0, value: max(0, min(1, values[$0]))) }
        let path = Self.closedSmoothPath(points: points)
        context.fill(path, with: .color(color.opacity(0.25)))
        context.stroke(path, with: .color(color.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        // Vertex dots.
        for p in points {
            let dot = Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
            context.fill(dot, with: .color(color))
        }
    }

    private func drawAxisLabels(context: GraphicsContext, geom: RadarGeometry) {
        for i in 0..<geom.axisCount {
            let lp = geom.labelPoint(axis: i)
            let anchor: UnitPoint = abs(lp.x - geom.center.x) < 8
                ? .center
                : (lp.x < geom.center.x ? .trailing : .leading)
            context.draw(
                Text(axes[i].category.rawValue)
                    .font(.hhSamuel(13))
                    .foregroundColor(LCColor.ink),
                at: lp,
                anchor: anchor
            )
        }
    }

    // MARK: - Closed Catmull-Rom spline → cubic Bézier path

    static func closedSmoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        let n = points.count
        guard n >= 3 else {
            // Degenerate: straight polygon.
            if let first = points.first {
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
                path.closeSubpath()
            }
            return path
        }
        path.move(to: points[0])
        for i in 0..<n {
            let p0 = points[(i - 1 + n) % n]
            let p1 = points[i]
            let p2 = points[(i + 1) % n]
            let p3 = points[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6.0, y: p1.y + (p2.y - p0.y) / 6.0)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6.0, y: p2.y - (p3.y - p1.y) / 6.0)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }
}

/// Geometry math for the radar: axis i starts at the top and proceeds clockwise.
private struct RadarGeometry {
    let center: CGPoint
    let radius: CGFloat
    let axisCount: Int

    init(size: CGSize, axisCount: Int, inset: CGFloat) {
        self.center = CGPoint(x: size.width / 2, y: size.height / 2)
        self.radius = max(0, min(size.width, size.height) / 2 - inset)
        self.axisCount = max(1, axisCount)
    }

    private func angle(_ i: Int) -> CGFloat {
        -.pi / 2 + CGFloat(i) * (2 * .pi / CGFloat(axisCount))
    }

    func point(axis i: Int, value: Double) -> CGPoint {
        let a = angle(i)
        let r = radius * CGFloat(value)
        return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
    }

    func labelPoint(axis i: Int) -> CGPoint {
        let a = angle(i)
        let r = radius + 18
        return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
    }

    func nearestAxis(to p: CGPoint) -> Int {
        let target = atan2(p.y - center.y, p.x - center.x)
        var best = 0
        var bestDiff = CGFloat.greatestFiniteMagnitude
        for i in 0..<axisCount {
            var diff = abs(angle(i) - target)
            diff = min(diff, 2 * .pi - diff)
            if diff < bestDiff { bestDiff = diff; best = i }
        }
        return best
    }
}

#if DEBUG
#Preview {
    CategoryRadarChart(axes: PreviewData.radarAxes)
        .frame(width: 300, height: 300)
}
#endif
