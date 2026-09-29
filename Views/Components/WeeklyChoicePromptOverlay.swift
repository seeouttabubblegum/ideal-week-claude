//
//  WeeklyChoicePromptOverlay.swift
//  The Ideal Week
//
//  Moved out of IdealListView (2026-09-04) verbatim. Behaviour unchanged.
//

import SwiftUI

/// Handoff 27-7n: bottom-pinned neumorphic card over the dimmed list.
/// "WHAT DO YOU WANNA DO THIS WEEK?" in HH Samuel, raised YELLOW
/// "Let Me Pick" pill + neutral raised "Skip For Now" pill.
struct WeeklyChoicePromptOverlay: View {
    /// Client, 2026-09-29 (was "Pick For Me To Plan"): the user picks.
    static let pickLabel = "Let Me Pick"
    static let skipLabel = "Skip For Now"

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
                    .accentText(.pink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.manrope(14, .medium))
                    .foregroundColor(LCColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                VStack(spacing: 14) {
                    Button(Self.pickLabel, action: onPick)
                        .buttonStyle(NeumorphicButtonStyle(
                            tint: LCColor.pink, fill: LCColor.yellow,
                            verticalPadding: 17, font: .manrope(18, .heavy)))

                    Button(Self.skipLabel, action: onSkip)
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
                    // No shadow at all (client, 2026-09-29): over the dimmed
                    // list both halves of the neumorphic pair read as a white
                    // glow around the card — the "dark" one is a pale grey too.
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
    }
}
