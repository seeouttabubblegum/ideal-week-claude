//
//  FlowLayout.swift
//  The Ideal Week
//

import SwiftUI

struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    // Cache stores subview sizes measured in sizeThatFits so placeSubviews
    // can reuse them without calling sizeThatFits on every subview a second time.
    func makeCache(subviews: Subviews) -> [CGSize] {
        []
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) -> CGSize {
        // Measure all subviews once and cache for placeSubviews.
        cache = subviews.map { $0.sizeThatFits(proposal) }

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxRowHeight: CGFloat = 0
        var width: CGFloat = 0

        for subviewSize in cache {
            if currentX + subviewSize.width + horizontalSpacing > proposal.width ?? .infinity {
                currentX = 0
                currentY += maxRowHeight + verticalSpacing
                maxRowHeight = 0
            }

            currentX += subviewSize.width + horizontalSpacing
            maxRowHeight = max(maxRowHeight, subviewSize.height)
            width = max(width, currentX)
        }

        return CGSize(width: width, height: currentY + maxRowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) {
        // Use cached sizes when available; fall back to measuring if cache is stale.
        let sizes = cache.count == subviews.count ? cache : subviews.map { $0.sizeThatFits(proposal) }

        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxRowHeight: CGFloat = 0

        for (subview, subviewSize) in zip(subviews, sizes) {
            if currentX + subviewSize.width > bounds.maxX {
                currentX = bounds.minX
                currentY += maxRowHeight + verticalSpacing
                maxRowHeight = 0
            }

            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(subviewSize))

            currentX += subviewSize.width + horizontalSpacing
            maxRowHeight = max(maxRowHeight, subviewSize.height)
        }
    }
}
