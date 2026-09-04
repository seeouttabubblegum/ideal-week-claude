//
//  IdealListCategoryLabel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 13/6/25.
//
//  2026-07 neumorphic redesign (6a): each category gets a full-width BANDED
//  header — deep-pink band, white category line-icon + blue HH Samuel name,
//  and a raised yellow "+" add button on the band's right.
//

import SwiftData
import SwiftUI

struct IdealListCategoryLabel: View {
    @Query var storedAccentColors: [MainSettings]
    private var firstColor: MainSettings? { storedAccentColors.first }
    var accentColor: Color {
        if let c = firstColor {
            return Color(red: c.red, green: c.green, blue: c.blue, opacity: c.opacity)
        } else {
            return Color("default_color")
        }
    }
    var textColor: Color {
        if let c = firstColor {
            return Color(red: c.textColorRed, green: c.textColorGreen, blue: c.textColorBlue, opacity: c.textColorOpacity)
        } else {
            return Color.black
        }
    }
    let cat: Category
    var onePlusTapped: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // LC category icon (v2 set: Fitness = pulse, Family = two figures),
            // template-tinted white on the pink band. Handoff 6a: 38×38.
            Image(cat.lcCategoryIconV2())
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)

            Text(cat.rawValue.uppercased())
                .font(.hhSamuel(31))
                .kerning(0.5)
                .foregroundColor(LCColor.blue)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Yellow raised "+" add button (raised against the pink band, so the
            // shadow pair is band-tinted rather than the surface pair).
            if let onePlusTapped = onePlusTapped {
                Button {
                    HapticFeedback.impact()
                    onePlusTapped()
                } label: {
                    // Handoff 6a: 16pt plus, stroke 2.6 round-capped, ink — the
                    // design's own glyph, not an SF-symbol stand-in.
                    BandPlusGlyph()
                        .stroke(Color(hex: 0x181818),
                                style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                        .frame(width: 16, height: 16)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                }
                .buttonStyle(BandAddButtonStyle())
                .accessibilityLabel("Add \(cat.rawValue) ideal")
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: LCMetrics.rowHeight, alignment: .leading)
        .background(LCColor.deepPink)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Handoff 6a band add glyph: a plus in a 16-unit box — vertical (8,2)–(8,14),
/// horizontal (2,8)–(14,8). Stroke width/colour applied by the caller.
private struct BandPlusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 16
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        path.move(to: p(8, 2)); path.addLine(to: p(8, 14))
        path.move(to: p(2, 8)); path.addLine(to: p(14, 8))
        return path
    }
}

/// Raised yellow circle button used on the pink category band. The neumorphic
/// shadow pair is tinted to the band (dark maroon / light pink) per the handoff
/// CSS: `3px 3px 7px rgba(120,8,60,0.5), -3px -3px 6px rgba(255,120,190,0.55)`.
/// Depresses (shadows collapse + slight scale) while pressed.
private struct BandAddButtonStyle: ButtonStyle {
    private let darkShadow = Color(hex: 0x78083C, opacity: 0.5)
    private let lightShadow = Color(hex: 0xFF78BE, opacity: 0.55)

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(
                Circle()
                    .fill(LCColor.yellow)
                    .shadow(color: darkShadow, radius: pressed ? 1 : 3.5,
                            x: pressed ? 1 : 3, y: pressed ? 1 : 3)
                    .shadow(color: lightShadow, radius: pressed ? 1 : 3,
                            x: pressed ? -1 : -3, y: pressed ? -1 : -3)
            )
            .scaleEffect(pressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

#Preview {
    IdealListCategoryLabel(cat: .family, onePlusTapped: {})
        .modelContainer(for: [MainSettings.self, UserProfileSettings.self], inMemory: true)
        .background(LCColor.surface)
}
