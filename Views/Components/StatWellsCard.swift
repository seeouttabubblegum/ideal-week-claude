//
//  StatWellsCard.swift
//  The Ideal Week
//
//  The "ideals propel actions" pair of sunken wells inside a raised card.
//  Profile shows it for lifetime totals (with a caption), Progress for the
//  current week's totals. One implementation so the two can never drift apart.
//

import SwiftUI

struct StatWellsCard<Caption: View>: View {
    let idealsValue: Int
    let idealsLabel: String
    let actionsValue: Int
    let actionsLabel: String
    @ViewBuilder var caption: () -> Caption

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                StatWell(value: idealsValue, label: idealsLabel, role: .pink)
                PropelArrow()
                StatWell(value: actionsValue, label: actionsLabel, role: .blue)
            }
            caption()
        }
        .padding(16)
        .neuRaised(cornerRadius: 20)
    }
}

extension StatWellsCard where Caption == EmptyView {
    init(idealsValue: Int, idealsLabel: String, actionsValue: Int, actionsLabel: String) {
        self.init(idealsValue: idealsValue,
                  idealsLabel: idealsLabel,
                  actionsValue: actionsValue,
                  actionsLabel: actionsLabel) { EmptyView() }
    }
}

/// Sunken stat well — big Oswald count over a muted uppercase label.
struct StatWell: View {
    let value: Int
    let label: String
    /// The ROLE, not a fixed colour: whichever of the three a palette hands this
    /// well decides whether the count needs its outline. Passing a `Color` was
    /// why this count stayed unreadable — it never reached the palette's own
    /// legibility rule.
    let role: LCHue

    var body: some View {
        VStack(spacing: 3) {
            Text(value.formatted())
                .font(.lcTitle(34))
                .accentText(role)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.lcTitle(13))
                .tracking(0.5)
                .foregroundColor(.black.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .neuSunken(cornerRadius: 16, cssOffset: 4, cssBlur: 8)
        .accessibilityElement(children: .combine)
    }
}

/// Triple pink chevrons between the stat wells (opacity ramps up — propulsion,
/// not competition).
struct PropelArrow: View {
    var body: some View {
        // All three take the SAME colour, only the opacity ramps. The first two
        // used the raw accent while the third went through the legibility rule,
        // so in a palette whose primary is the unreadable one you got two faint
        // yellow chevrons and one black.
        let chevron = LCColor.glyph(.pink)
        return HStack(spacing: 1) {
            Image(systemName: "chevron.right")
                .foregroundColor(chevron.opacity(0.42))
            Image(systemName: "chevron.right")
                .foregroundColor(chevron.opacity(0.7))
            Image(systemName: "chevron.right")
                .foregroundColor(chevron)
        }
        .font(.system(size: 15, weight: .bold))
        .accessibilityHidden(true)
    }
}
