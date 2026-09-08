//
//  IdealHistoryItemLabel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 28/8/25.
//

import SwiftUI

struct IdealHistoryItemLabel: View {
    let item: Ideal
    let background: Color
    let onTap: () -> Void
    
    @State private var isPressed: Bool = false
    
    var intTargetState: Int {
        if item.targetCount == "6+" {
            return 6
        }
        return Int(item.targetCount) ?? 0
    }
    
    private static let startDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    private var startDateText: String {
        guard item.startDate > 0 else { return "Start: Not set" }
        return "Start: \(Self.startDateFormatter.string(from: Date(timeIntervalSince1970: item.startDate)))"
    }

    /// Raw completion % for this ideal (unclamped, so over-completion like 150% / 250% shows).
    /// nil when the target is 0 → badge is hidden (never render NaN/∞).
    private var completionBadge: Int? {
        CategoryRadarMetrics.badgePercent(item)
    }

    @ViewBuilder
    private var badgeView: some View {
        if let pct = completionBadge {
            // Always pink, whatever the percentage (client, 2026-09-02).
            // Over-completion used to switch the capsule to cyan, which made the
            // badge colour read as a category/state signal it never was.
            Text("\(pct)%")
                .font(.manrope(13, .heavy))
                .foregroundColor(LCColor.contrastingInk(on: LCColor.pink))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(LCColor.pink))
                .padding(8)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(startDateText)
                .font(.manrope(12, .semibold))
                .foregroundColor(LCColor.textSecondary)

            HStack {
                Text(item.title)
                    .font(.idealTitle(21))
                    .foregroundColor(LCColor.ink)
                    .imprinted()
                Spacer()
                if let category = Category(rawValue: item.category) {
                    // LC line icon, template-tinted blue (handoff history cards
                    // render the line asset, never an SF-symbol stand-in).
                    Image(category.lcCategoryIconV2())
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .accentText(.blue)
                        .frame(width: 26, height: 26)
                }
            }
            FlowLayout(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 8) {
                if item.doneCount >= intTargetState {
                    ForEach(0..<intTargetState, id: \.self) { _ in
                        NeumorphicCompletionDot(state: .completed, size: 17)
                    }
                    let overCap = min(item.doneCount, 13) - intTargetState
                    ForEach(0..<max(0, overCap), id: \.self) { _ in
                        NeumorphicCompletionDot(state: .overCompleted, size: 17)
                    }
                } else {
                    ForEach(0..<item.doneCount, id: \.self) { _ in
                        NeumorphicCompletionDot(state: .completed, size: 17)
                    }
                    ForEach(0..<(intTargetState - item.doneCount), id: \.self) { _ in
                        NeumorphicCompletionDot(state: .empty, size: 17)
                    }
                }
            }
            .padding(.vertical, 4)
            
            // Review score display
            if let reviewScore = item.reviewScore {
                let display = ReviewScoreScale.display(fromStored: reviewScore)
                Text("Review Score: \(ReviewScoreScale.formattedDisplay(display))/7")
                    .font(.manrope(13, .semibold))
                    .foregroundColor(LCColor.textSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(LCMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            // Highlight animation
            withAnimation(.easeOut(duration: 0.12)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.easeIn(duration: 0.12)) {
                    isPressed = false
                }
                onTap()
            }
        }
        .background(
            ZStack {
                Color.clear
                if isPressed {
                    RoundedRectangle(cornerRadius: LCRadius.card, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                }
            }
        )
        .neuRaised(cornerRadius: LCRadius.card)
        .overlay(alignment: .topTrailing) {
            badgeView
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .padding(.horizontal, LCMetrics.screenMargin)
    }
}

#if DEBUG
#Preview {
    IdealHistoryItemLabel(item: PreviewData.sampleIdeal, background: LCColor.pink, onTap: {})
}
#endif

