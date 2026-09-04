//
//  MenuItem.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 12/6/25.
//
//  Menu-drawer row per the neumorphic handoff (2e): 80pt icon slot + HH Samuel
//  label in ink, riding on the drawer's cascading pink tab shades.
//

import SwiftUI

struct MenuItem: View {
    let imageName: String
    let text: String
    let padding = 12
    /// Rotates the glyph, for rows whose symbol needs it.
    var iconRotation: Double = 0
    /// When true, renders the grouped progress-rings graphic (ink monochrome)
    /// instead of an SF symbol — the drawer's "Progress" glyph.
    var showsProgressRings: Bool = false
    /// When true, renders the checklist mark — the drawer's "My Ideals" glyph.
    /// Same symbol the 1h header uses for the button back to the list.
    var showsChecklist: Bool = false

    /// Menu ink — the drawer labels/icons use the handoff's #181818.
    private let menuInk = Color(hex: 0x181818)

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if showsProgressRings {
                    // Static display copy of the 6a progress icon (target /
                    // tracking-line graphic), rendered in ink.
                    GroupedProgressRingsIcon(progress: [0.8, 0.6, 0.63],
                                             ringColors: [menuInk, menuInk, menuInk])
                        .frame(width: 34, height: 34)
                } else if showsChecklist {
                    IdealsChecklistGlyph()
                        .stroke(menuInk, style: StrokeStyle(
                            lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .frame(width: 28, height: 28)
                } else if imageName.hasPrefix("Line ") || imageName.hasPrefix("Solid ") {
                    // LC glyph from the handoff icon set, tinted with the menu ink.
                    Image(imageName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(iconRotation))
                } else {
                    Image(systemName: self.imageName)
                        .font(.system(size: 26, weight: .medium))
                        .rotationEffect(.degrees(iconRotation))
                }
            }
            .frame(width: 80)
            Text(self.text.uppercased())
                .font(.hhSamuel(27))
                .kerning(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .foregroundColor(menuInk)
        .padding([.top, .bottom], CGFloat(self.padding))
    }
}

#Preview {
    VStack(spacing: 0) {
        MenuItem(imageName: "", text: "My Ideals", showsChecklist: true)
            .background(LCColor.pink)
        MenuItem(imageName: "clock", text: "Progress", showsProgressRings: true)
            .background(LCColor.pink.lighter(0.1))
    }
}
