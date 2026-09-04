//
//  WeeklyChoicePromptOverlay.swift
//  The Ideal Week
//
//  Moved out of IdealListView (2026-09-04) verbatim. Behaviour unchanged.
//

import SwiftUI

/// Handoff 27-7n: bottom-pinned neumorphic card over the dimmed list.
/// "WHAT DO YOU WANNA DO THIS WEEK?" in HH Samuel, raised YELLOW
/// "Pick For Me To Plan" pill + neutral raised "Skip For Now" pill.
struct WeeklyChoicePromptOverlay: View {
    let subtitle: String
    let onPick: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dim layer (no tap-to-dismiss: the choice must be explicit, exactly
            // like the alert it replaces).
            Color(hex: 0x141418, opacity: 0.35)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("What Do You\nWanna Do\nThis Week?")
                    .textCase(.uppercase)
                    .font(.hhSamuel(32))
                    .foregroundColor(LCColor.deepPink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.manrope(14, .medium))
                    .foregroundColor(LCColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                VStack(spacing: 14) {
                    Button("Pick For Me To Plan", action: onPick)
                        .buttonStyle(NeumorphicButtonStyle(
                            tint: LCColor.deepPink, fill: LCColor.yellow,
                            verticalPadding: 17, font: .manrope(18, .heavy)))

                    Button("Skip For Now", action: onSkip)
                        .buttonStyle(NeumorphicButtonStyle(
                            tint: LCColor.blue,
                            verticalPadding: 16, font: .manrope(17, .heavy)))
                }
                .padding(.top, 24)
            }
            .padding(24)
            .padding(.top, 4)
            .background(
                RoundedRectangle(cornerRadius: LCRadius.sheetTop, style: .continuous)
                    .fill(LCColor.surface)
                    .shadow(color: LCColor.shadowDark, radius: 11, x: 8, y: 8)
                    .shadow(color: LCColor.shadowLight, radius: 8, x: -6, y: -6)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
    }
}
