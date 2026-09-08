//
//  LCPaletteSwatchRow.swift
//  The Ideal Week
//
//  Colour choice constrained to the LC palette. The old free-form `ColorPicker`
//  let a user set any colour at all, which overrides the fixed palette the
//  redesign is built on; these swatches keep the choice but keep it on-system.
//

import SwiftUI

struct LCPaletteSwatchRow: View {
    let title: String
    @Binding var selection: Color
    let options: [Color]

    /// Theme accents from the handoff palette.
    static let themeOptions: [Color] = [LCColor.pink, LCColor.pink, LCColor.blue, LCColor.yellow]
    /// Ink options for body text.
    static let textOptions: [Color] = [LCColor.ink, LCColor.pink, LCColor.blue]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.manrope(16, .heavy))
                .foregroundColor(LCColor.ink)

            HStack(spacing: 16) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    swatch(option)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func swatch(_ option: Color) -> some View {
        let isSelected = matches(option)
        return Button {
            HapticFeedback.impact(style: .light)
            selection = option
        } label: {
            Circle()
                .fill(option)
                .frame(width: 30, height: 30)
                .padding(6)
                .neuRaised(Circle(),
                           cssOffset: LCNeumorphism.raisedOffsetSmall,
                           cssBlur: LCNeumorphism.raisedBlurSmall)
                .overlay(
                    Circle()
                        .stroke(LCColor.ink.opacity(isSelected ? 0.55 : 0), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Colours come back from storage as component values, so compare resolved
    /// RGB rather than relying on `Color` identity.
    private func matches(_ option: Color) -> Bool {
        let a = UIColor(selection).cgColor.components ?? []
        let b = UIColor(option).cgColor.components ?? []
        guard a.count >= 3, b.count >= 3 else { return false }
        return abs(a[0] - b[0]) < 0.02 && abs(a[1] - b[1]) < 0.02 && abs(a[2] - b[2]) < 0.02
    }
}
