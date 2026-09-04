//
//  ProgressRingsLayout.swift
//  The Ideal Week
//
//  Geometry for the concentric category-progress dial on the Progress page.
//  The dial used to be drawn into a fixed 350×350 canvas no matter how many
//  categories the week had, so a two-category week left a small dial floating in
//  a large empty box and the totals card underneath looked detached from it.
//  The canvas now hugs the rings that are actually drawn.
//

import CoreGraphics

enum ProgressRingsLayout {

    /// Diameter of the innermost ring's path.
    static let innermostRingDiameter: CGFloat = 80

    /// Stroke width of every ring. Rings sit edge to edge, so each additional
    /// ring grows the dial by two stroke widths.
    static let ringStrokeWidth: CGFloat = 15.625

    /// The old hard-coded canvas. Kept as a ceiling so hugging can only tighten
    /// the layout, never push the dial wider than it used to be.
    static let maxCanvasSize: CGFloat = 350

    /// How far a category glyph reaches from the ring path it is centred on:
    /// half its own frame plus its padding. Slightly more than half a stroke, so
    /// it is the glyph — not the stroke — that decides the canvas edge.
    static let glyphRadius: CGFloat = (ringStrokeWidth * 0.72) / 2 + 3

    /// Outer diameter of the drawn dial, the outermost stroke included.
    static func dialDiameter(ringCount: Int) -> CGFloat {
        let rings = max(ringCount, 1)
        let pathDiameter = innermostRingDiameter + CGFloat(rings - 1) * ringStrokeWidth * 2
        return pathDiameter + ringStrokeWidth
    }

    /// Square canvas the rings are drawn into: the dial plus just enough room for
    /// the glyphs that straddle the outermost stroke.
    static func canvasSize(ringCount: Int) -> CGFloat {
        let rings = max(ringCount, 1)
        let pathRadius = (innermostRingDiameter + CGFloat(rings - 1) * ringStrokeWidth * 2) / 2
        let outerRadius = pathRadius + max(ringStrokeWidth / 2, glyphRadius)
        return min(maxCanvasSize, outerRadius * 2)
    }
}
