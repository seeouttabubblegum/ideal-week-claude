//
//  TLButton.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//
//  2026-07 neumorphic redesign: raised capsule that depresses to sunken while
//  pressed. Primary actions (Save / Save Settings) fill YELLOW per the handoff
//  ("key CTA button fills"); Cancel / Close / destructive actions stay a
//  neutral raised surface so the pair reads Cancel-neutral / Save-yellow
//  (handoff 7o Quick Add).
//

import SwiftData
import SwiftUI

struct TLButton: View {

    @Query var storedAccentColors: [MainSettings]
    var accentColor: Color {
        if let firstColor = storedAccentColors.first{
            return Color(red: firstColor.red, green: firstColor.green, blue: firstColor.blue, opacity: firstColor.opacity)
        }else{
            return Color("default_color")
        }
   }
    let title: String
    /// The colour the original (pre-neumorphic) design used. We now read it
    /// only to detect "destructive" / "cancel" intent — anything pink-ish or
    /// red-ish (legacy convention in this app) renders as the NEUTRAL raised
    /// surface button, everything else as the YELLOW key-CTA fill, so
    /// Cancel / Save remain visually distinct.
    let background: Color
    let action: () -> Void

    private var isCancel: Bool {
        let c = background.getComponents()
        // Pink / red / coral — red dominates.
        return c.red > 0.7 && c.green < 0.5 && c.blue < 0.7
    }

    var body: some View {
        Button {
            HapticFeedback.impact()
            action()
        } label: {
            Text(title)
        }
        .buttonStyle(NeumorphicButtonStyle(
            tint: LCColor.ink,
            fill: isCancel ? LCColor.surface : LCColor.yellow
        ))
    }
}

#Preview {
    TLButton(title: "value",background: .white){
//        action()
    }
    .modelContainer(for: [MainSettings.self, UserProfileSettings.self], inMemory: true)
}
