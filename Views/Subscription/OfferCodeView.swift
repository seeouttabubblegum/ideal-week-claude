//
//  OfferCodeView.swift
//  The Ideal Week
//
//  Created for offer code redemption
//  Restyled to the 2026-07 neumorphic redesign (handoff screen 7e).
//

import SwiftUI
import StoreKit
import SwiftData

struct OfferCodeView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Query private var storedAccentColors: [MainSettings]
    @State private var isRedeeming = false
    @State private var showError = false
    @State private var errorMessage = ""

    /// Step body copy grey (handoff 7e — sits between ink and secondary).
    private var stepTextColor: Color { Color(hex: 0x4A4A52) }

    var accentColor: Color {
        // Follows the palette chosen in Settings (LCPalette).
        LCColor.pink
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header — centered title, close (raised circle, pink X) right
                    ZStack {
                        Text("REDEEM CODE")
                            .font(.hhSamuel(32))
                            .accentText(.pink)

                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image("Line Close_Pink")
                                    .resizable()
                                    .renderingMode(.original)
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                            }
                            .buttonStyle(NeuCircleButtonStyle(diameter: 36))
                            .accessibilityLabel("Close")
                        }
                    }
                    .padding(.horizontal, LCMetrics.screenMargin)
                    .frame(height: 56)

                    // Ticket badge + title + subtitle
                    VStack(spacing: 0) {
                        Image(systemName: "ticket")
                            .font(.system(size: 34, weight: .medium))
                            .accentText(.pink)
                            .frame(width: 78, height: 78)
                            .neuRaisedCircle(cssOffset: 5, cssBlur: 12)
                            .accessibilityHidden(true)

                        Text("REDEEM\nOFFER CODE")
                            .font(.hhSamuel(34))
                            .accentText(.blue)
                            .multilineTextAlignment(.center)
                            .padding(.top, 18)

                        Text("Enter your offer code to unlock The Ideal Week")
                            .font(.manrope(15, .medium))
                            .foregroundColor(LCColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 28)

                    // Instructions — numbered steps in a grouped list
                    Text("TO REDEEM")
                        .font(.hhSamuel(22))
                        .accentText(.pink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 26)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        redeemStep("1.", "Make sure you're signed in with a valid account in Settings > App Store")
                        NeuFeatheredDivider()
                            .padding(.horizontal, 16)
                        redeemStep("2.", "Tap the button below to open the redemption sheet")
                        NeuFeatheredDivider()
                            .padding(.horizontal, 16)
                        redeemStep("3.", "Enter your offer code in the sheet")
                        NeuFeatheredDivider()
                            .padding(.horizontal, 16)
                        redeemStep("4.", "Your subscription activates automatically after redemption")
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, LCMetrics.screenMargin)

                    // Redeem Button - Opens system redemption sheet
                    Button {
                        Task { await redeemCode() }
                    } label: {
                        HStack(spacing: 10) {
                            if isRedeeming {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: LCColor.pink))
                            } else {
                                Image(systemName: "ticket")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Redeem Offer Code")
                            }
                        }
                    }
                    .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink,
                                                       fill: LCColor.yellow,
                                                       verticalPadding: 17,
                                                       font: .manrope(18, .heavy)))
                    .disabled(isRedeeming)
                    .padding(.top, 26)
                    .padding(.horizontal, LCMetrics.screenMargin)

                    // Manual Check Subscription Button (pink link)
                    Button(action: {
                        Task {
                            await subscriptionManager.checkSubscriptionStatus()
                            if subscriptionManager.hasActiveSubscription {
                                dismiss()
                            } else {
                                errorMessage = "No active subscription found. Please redeem an offer code or subscribe. If you just redeemed a code, wait a few seconds and try again."
                                showError = true
                            }
                        }
                    }) {
                        Text("Check Subscription Status")
                            .font(.manrope(15, .bold))
                            .accentText(.pink)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(LCColor.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: subscriptionManager.hasActiveSubscription) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }

    /// One numbered instruction row (pink number + grey copy).
    private func redeemStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.manrope(17, .heavy))
                .accentText(.pink)
            Text(text)
                .font(.manrope(14, .medium))
                .foregroundColor(stepTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private func redeemCode() async {
        isRedeeming = true
        errorMessage = ""

        // StoreKit 2 requires using the system redemption sheet
        // Open it and the transaction listener will automatically detect the redemption
        subscriptionManager.presentCodeRedemptionSheet()

        // Wait and check for redemption periodically (up to 10 seconds)
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every second
            await subscriptionManager.checkSubscriptionStatus()

            if subscriptionManager.hasActiveSubscription {
                // Successfully redeemed - dismiss will happen via onChange
                isRedeeming = false
                return
            }
        }

        // If we get here, redemption might still be processing or user cancelled
        isRedeeming = false
        // Don't show error - user might have cancelled or is still entering code
    }
}

#if DEBUG
#Preview {
    OfferCodeView(subscriptionManager: SubscriptionManager())
        .modelContainer(for: MainSettings.self, inMemory: true)
}
#endif
