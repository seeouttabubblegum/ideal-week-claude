//
//  SubscriptionRequiredView.swift
//  The Ideal Week
//
//  Extracted from IdealListView (2026-09-04). The body is copied verbatim;
//  the two flags were write-only there, so they arrive as bindings.
//

import SwiftUI

struct SubscriptionRequiredView: View {
    @Binding var showSubscriptionView: Bool
    @Binding var showOfferCodeView: Bool
    /// The 17-day free trial has run out (it says so instead of a bare ask).
    var trialEnded: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .accentText(.pink)

            Text("SUBSCRIPTION REQUIRED")
                .font(.hhSamuel(26))
                .accentText(.pink)
                .multilineTextAlignment(.center)

            Text(SubscriptionCopy.subscribeRequired(trialEnded: trialEnded))
                .font(.manrope(15, .medium))
                .foregroundColor(LCColor.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 14) {
                Button("View Subscription Options") {
                    showSubscriptionView = true
                }
                .buttonStyle(NeumorphicButtonStyle(
                    tint: LCColor.pink, fill: LCColor.yellow,
                    font: .manrope(17, .heavy)))

                Button(action: {
                    showOfferCodeView = true
                }) {
                    HStack {
                        Image(systemName: "ticket.fill")
                        Text("Redeem Offer Code")
                    }
                }
                .buttonStyle(NeumorphicButtonStyle(
                    tint: LCColor.pink, font: .manrope(16, .heavy)))
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LCColor.surface)
    }
}
