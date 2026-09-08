//
//  NeuSheetHeader.swift
//  The Ideal Week
//
//  Neumorphic sheet header — close · title · optional save — replacing the iOS
//  navigation bar. Same shape as the New Ideal screen's 1i header, so second-level
//  sheets stop showing system chrome on top of a neumorphic body.
//
//  Use with `.toolbar(.hidden, for: .navigationBar)` on the sheet's content.
//

import SwiftUI

struct NeuSheetHeader: View {
    let title: String
    var titleSize: CGFloat = 30
    var onClose: () -> Void
    var onSave: (() -> Void)? = nil
    var saveDiameter: CGFloat = 40

    var body: some View {
        ZStack {
            Text(title)
                .font(.hhSamuel(titleSize))
                .textCase(.uppercase)
                .accentText(.pink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 56)
            HStack {
                NeuCloseButton(action: onClose, diameter: 36)
                Spacer()
                if let onSave {
                    NeuCheckSaveButton(diameter: saveDiameter, action: onSave)
                }
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(LCColor.surface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
