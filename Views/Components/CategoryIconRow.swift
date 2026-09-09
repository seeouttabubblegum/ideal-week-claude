//
//  CategoryIconRow.swift
//  The Ideal Week
//
//  The seven categories as a single row of icons — no labels, because the
//  chosen one is named in the section header beside it ("Category: Fix").
//
//  The wrapping text chips (`CategoryWellPicker`) read as tabs and took three
//  lines; this keeps the whole choice on one line and lets the form breathe.
//  The row divides the available width evenly rather than using fixed spacing,
//  so all seven stay on one line at any width.
//

import SwiftUI

struct CategoryIconRow: View {
    @Binding var selection: String

    var options: [Category] = Category.allCases
    var diameter: CGFloat = 40
    var iconSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { category in
                cell(category)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cell(_ category: Category) -> some View {
        let isSelected = selection == category.rawValue
        return Button {
            HapticFeedback.impact(style: .light)
            // Reaching the category row means the title is finished being typed.
            hideKeyboard()
            selection = category.rawValue
        } label: {
            Image(category.lcCategoryIconV2())
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                // Selected: the glyph sits ON the primary accent, so it takes
                // whatever that fill can carry. Unselected: a quiet glyph in its
                // own sunken well, exactly as the text chips did.
                .foregroundColor(isSelected ? LCColor.contrastingInk(on: LCColor.pink)
                                            : LCColor.textSecondary)
                .frame(width: iconSize, height: iconSize)
                .frame(width: diameter, height: diameter)
                .modifier(CategoryIconWell(isSelected: isSelected))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.rawValue)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Raised and filled when chosen, sunken when not — the same pairing the text
/// chips used, in a circle.
private struct CategoryIconWell: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content.neuRaised(Circle(),
                              fill: LCColor.pink,
                              cssOffset: LCNeumorphism.raisedOffsetSmall,
                              cssBlur: LCNeumorphism.raisedBlurSmall)
        } else {
            content.neuSunken(Circle())
        }
    }
}

#if DEBUG
#Preview {
    struct Harness: View {
        @State private var selection = Category.fix.rawValue
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                CategorySelectionLabel(selection: selection)
                CategoryIconRow(selection: $selection)
            }
            .padding(.horizontal, LCMetrics.screenMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LCColor.surface)
        }
    }
    return Harness()
}
#endif
