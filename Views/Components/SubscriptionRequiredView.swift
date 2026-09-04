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

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(LCColor.pink)

            Text("SUBSCRIPTION REQUIRED")
                .font(.hhSamuel(26))
                .foregroundColor(LCColor.deepPink)
                .multilineTextAlignment(.center)

            Text("Please subscribe to access The Ideal Week")
                .font(.manrope(15, .medium))
                .foregroundColor(LCColor.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 14) {
                Button("View Subscription Options") {
                    showSubscriptionView = true
                }
                .buttonStyle(NeumorphicButtonStyle(
                    tint: LCColor.deepPink, fill: LCColor.yellow,
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
