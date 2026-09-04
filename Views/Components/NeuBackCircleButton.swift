//
//  NeuBackCircleButton.swift
//  The Ideal Week
//
//  Moved out of PlanningSheetView (2026-09-04) verbatim. Behaviour unchanged.
//

import SwiftUI

/// Raised round back button (pink chevron) — pops one step within the planning
/// flow; dismissal uses the standard `NeuCloseButton` instead.
struct NeuBackCircleButton: View {
    var action: () -> Void
    var diameter: CGFloat = 40

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(LCColor.pink)
        }
        .buttonStyle(NeuCircleButtonStyle(diameter: diameter))
        .accessibilityLabel("Back")
    }
}
