//
//  CategoryWellPicker.swift
//  The Ideal Week
//
//  Every category on screen at once instead of a stock `.pickerStyle(.menu)`
//  dropdown: chips that wrap onto as many lines as they need, unselected sitting
//  in a sunken well, selected raised in pink — the same treatment as the
//  reminder day chips.
//

import SwiftUI

struct CategoryWellPicker: View {
    @Binding var selection: String
    var options: [String] = Category.allCases.map(\.rawValue)
    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 10
    var textSize: CGFloat = 15

    var body: some View {
        FlowLayout(alignment: .leading,
                   horizontalSpacing: horizontalSpacing,
                   verticalSpacing: verticalSpacing) {
            ForEach(options, id: \.self) { option in
                well(option)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func well(_ option: String) -> some View {
        let isSelected = selection == option
        let label = Text(option)
            .font(.manrope(textSize, .heavy))
            .foregroundColor(isSelected ? LCColor.contrastingInk(on: LCColor.pink) : LCColor.textSecondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)

        return Button {
            HapticFeedback.impact(style: .light)
            selection = option
        } label: {
            Group {
                if isSelected {
                    label.neuRaised(cornerRadius: LCRadius.chip,
                                    fill: LCColor.pink,
                                    cssOffset: LCNeumorphism.raisedOffsetSmall,
                                    cssBlur: LCNeumorphism.raisedBlurSmall)
                } else {
                    label.neuSunken(cornerRadius: LCRadius.chip)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: LCRadius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
