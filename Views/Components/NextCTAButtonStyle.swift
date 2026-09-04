//
//  NextCTAButtonStyle.swift
//  The Ideal Week
//
//  Moved out of IdealListView (2026-09-04) verbatim. Behaviour unchanged.
//

import SwiftUI

/// Scaled-up NEXT-style CTA (handoff 1d "Add To The Next List"): raised yellow
/// rounded-rect (22pt radius, not a full pill) that depresses while pressed.
struct NextCTAButtonStyle: ButtonStyle {
    var fill: Color = LCColor.yellow

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(NeuPressableBackground(
                shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                fill: fill, pressed: configuration.isPressed))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
