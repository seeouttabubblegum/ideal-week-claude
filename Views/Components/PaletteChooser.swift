//
//  PaletteChooser.swift
//  The Ideal Week
//
//  The four colour schemes as pickable rows. Each row previews the palette with
//  its own three accents, so the choice is made by looking rather than reading.
//

import SwiftUI

struct PaletteChooser: View {
    @Binding var selection: LCPalette

    var body: some View {
        VStack(spacing: 12) {
            ForEach(LCPalette.allCases) { palette in
                row(palette)
            }
        }
    }

    private func row(_ palette: LCPalette) -> some View {
        let isSelected = selection == palette
        return Button {
            HapticFeedback.impact(style: .light)
            selection = palette
        } label: {
            HStack(spacing: 14) {
                swatches(palette)

                VStack(alignment: .leading, spacing: 3) {
                    Text(palette.displayName)
                        .font(.manrope(16, .heavy))
                        .foregroundColor(LCColor.ink)
                    Text(palette.subtitle)
                        .font(.manrope(12, .medium))
                        .foregroundColor(LCColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                // Sunken well that fills when chosen — the app's completion dot.
                NeumorphicCompletionDot(state: isSelected ? .completed : .empty, size: 18)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(NeuRowButtonStyle(cornerRadius: LCRadius.card))
        .accessibilityLabel("\(palette.displayName). \(palette.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Three stacked discs in the palette's own colours — the same order the
    /// book covers use: primary, secondary, CTA.
    private func swatches(_ palette: LCPalette) -> some View {
        HStack(spacing: -10) {
            ForEach(Array(LCHue.allCases.enumerated()), id: \.offset) { index, role in
                Circle()
                    .fill(palette.resolved(role, variant: .base))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(LCColor.surface, lineWidth: 2))
                    .zIndex(Double(LCHue.allCases.count - index))
            }
        }
        .padding(.leading, 2)
        .accessibilityHidden(true)
    }
}
