//
//  SubscriptionView.swift
//  The Ideal Week
//
//  Created for subscription flow
//  Restyled to the 2026-07 neumorphic redesign (handoff screen 7d).
//

import SwiftUI
import StoreKit
import SwiftData

struct SubscriptionView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Query private var storedAccentColors: [MainSettings]
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var accentColor: Color {
        // Follows the palette chosen in Settings (LCPalette).
        LCColor.pink
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Close (top-right, raised circle with pink X)
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image("Line Close_Pink")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(LCColor.glyph(.pink))
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                        }
                        .buttonStyle(NeuCircleButtonStyle(diameter: 36))
                        .accessibilityLabel("Close")
                    }
                    .padding(.horizontal, LCMetrics.screenMargin)
                    .frame(height: 52)

                    // Header — star badge + UNLOCK THE IDEAL WEEK
                    VStack(spacing: 0) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 38))
                            .accentText(.yellow)
                            .frame(width: 78, height: 78)
                            .neuRaisedCircle(cssOffset: 5, cssBlur: 12)
                            .accessibilityHidden(true)

                        Text("UNLOCK THE\nIDEAL WEEK")
                            .font(.hhSamuel(38))
                            .accentText(.blue)
                            .multilineTextAlignment(.center)
                            .padding(.top, 18)

                        Text("Start your journey to a better week")
                            .font(.manrope(15, .medium))
                            .foregroundColor(LCColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 28)

                    // Trial Badge - Prominently displayed (pink raised banner)
                    HStack(spacing: 10) {
                        Image(systemName: "gift")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                        Text("2 Weeks Free Trial")
                            .font(.hhSamuel(26))
                            .accentText(.yellow)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .neuRaised(cornerRadius: 20, fill: LCColor.pink, cssOffset: 6, cssBlur: 16)
                    .padding(.horizontal, 28)
                    .padding(.top, 22)

                    Text("Try all features risk-free for 2 weeks, then choose your plan")
                        .font(.manrope(13.5, .medium))
                        .foregroundColor(LCColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 14)

                    // Subscription Options
                    if subscriptionManager.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(LCColor.pink)
                            Text("Loading subscription options...")
                                .font(.manrope(15, .medium))
                                .foregroundColor(LCColor.textSecondary)
                        }
                        .padding()
                        .padding(.top, 22)
                    } else if subscriptionManager.products.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .accentText(.pink)
                            Text("Unable to load subscription options")
                                .font(.manrope(17, .heavy))
                                .foregroundColor(LCColor.ink)

                            if let error = subscriptionManager.errorMessage {
                                Text(error)
                                    .font(.manrope(13, .medium))
                                    .accentText(.pink)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            } else {
                                Text("Products may not be configured in App Store Connect yet, or you may need to sign in with a sandbox account.")
                                    .font(.manrope(13, .medium))
                                    .foregroundColor(LCColor.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            Button(action: {
                                Task {
                                    await subscriptionManager.loadProducts()
                                }
                            }) {
                                Text("Retry")
                            }
                            .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink,
                                                               fill: LCColor.yellow,
                                                               fullWidth: false))
                        }
                        .padding()
                        .padding(.top, 22)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(subscriptionManager.products) { product in
                                SubscriptionOptionCard(
                                    product: product,
                                    accentColor: accentColor,
                                    isSelected: selectedProduct?.id == product.id,
                                    isYearly: product.id.contains("yearly"),
                                    monthlyProduct: subscriptionManager.products.first { $0.id.contains("yearly") == false }
                                ) {
                                    selectedProduct = product
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                    }

                    // Purchase Button — raised yellow pill, deep-pink label
                    if let selectedProduct = selectedProduct {
                        Button(action: {
                            Task {
                                await purchaseProduct(selectedProduct)
                            }
                        }) {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: LCColor.pink))
                                } else {
                                    Text("Start Free Trial")
                                }
                            }
                        }
                        .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink,
                                                           fill: LCColor.yellow,
                                                           verticalPadding: 17,
                                                           font: .manrope(18, .heavy)))
                        .disabled(isPurchasing)
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                    }

                    // Restore Purchases (pink link)
                    Button(action: {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.manrope(14, .bold))
                            .accentText(.pink)
                    }
                    .padding(.top, 18)

                    // Terms and Privacy (fine print)
                    VStack(spacing: 8) {
                        Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                            .font(.manrope(11, .medium))
                            .foregroundColor(LCColor.textMuted)
                            .multilineTextAlignment(.center)

                        Text("Cancel anytime. Subscription auto-renews unless cancelled.")
                            .font(.manrope(11, .medium))
                            .foregroundColor(LCColor.textMuted)
                            .multilineTextAlignment(.center)

                        Text("Note: Purchases use the Apple ID signed in to Settings > App Store on this device.")
                            .font(.manrope(10, .medium))
                            .foregroundColor(LCColor.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 16)
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
                // Dismiss subscription view if user becomes subscribed
                if newValue {
                    dismiss()
                }
            }
            .task {
                // Load products when view appears
                await subscriptionManager.loadProducts()
            }
        }
    }

    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        errorMessage = ""

        do {
            let transaction = try await subscriptionManager.purchase(product)
            if transaction != nil {
                dismiss()
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            showError = true
        }

        isPurchasing = false
    }
}

struct SubscriptionOptionCard: View {
    let product: Product
    let accentColor: Color
    let isSelected: Bool
    let isYearly: Bool
    let monthlyProduct: Product?
    let onSelect: () -> Void

    // Calculate savings for yearly subscription
    private var savingsPercentage: Int? {
        guard isYearly, let monthly = monthlyProduct else { return nil }
        let yearlyPrice = product.price
        let monthlyPrice = monthly.price
        let yearlyEquivalent = monthlyPrice * 12
        guard yearlyEquivalent > 0 else { return nil }
        let savings = ((yearlyEquivalent - yearlyPrice) / yearlyEquivalent) * 100
        return Int(truncating: NSDecimalNumber(decimal: savings))
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Yearly" : "Monthly")
                            .font(.hhSamuel(22))
                            .foregroundColor(LCColor.ink)

                        if isYearly {
                            Text(savingsPercentage.map { "SAVE \($0)%" } ?? "BEST VALUE")
                                .font(.manrope(11, .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 7).fill(LCColor.blue))
                        }
                    }

                    // Trial period highlight
                    if let subscription = product.subscription {
                        if let introOffer = subscription.introductoryOffer {
                            if introOffer.period.unit == .day && introOffer.period.value == 14 {
                                Text("2 weeks free trial")
                                    .font(.manrope(12.5, .medium))
                                    .accentText(.pink)
                            }
                        }

                        let period = subscription.subscriptionPeriod
                        let periodText = period.unit == .month ? "month" : "year"
                        Text("Then \(product.displayPrice) / \(periodText) after trial")
                            .font(.manrope(12.5, .medium))
                            .foregroundColor(LCColor.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.manrope(22, .heavy))
                        .foregroundColor(LCColor.ink)

                    Text(isYearly ? "per year" : "per month")
                        .font(.manrope(12, .regular))
                        .foregroundColor(LCColor.textSecondary)
                }

                // Selection indicator — blue raised check when selected,
                // empty sunken well otherwise
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(LCColor.blue)
                            .shadow(color: LCColor.shadowDark, radius: 3, x: 3, y: 3)
                            .shadow(color: LCColor.shadowLight, radius: 3, x: -3, y: -3)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .fill(
                                LCColor.surface
                                    .shadow(.inner(color: LCColor.shadowDark, radius: 2, x: 2, y: 2))
                                    .shadow(.inner(color: LCColor.shadowLight, radius: 2, x: -2, y: -2))
                            )
                    }
                }
                .frame(width: 24, height: 24)
                .padding(.top, 2)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background {
                // Selected = raised card, unselected = sunken well
                if isSelected {
                    RoundedRectangle(cornerRadius: LCRadius.card, style: .continuous)
                        .fill(LCColor.surface)
                        .shadow(color: LCColor.shadowDark, radius: 6, x: 5, y: 5)
                        .shadow(color: LCColor.shadowLight, radius: 6, x: -5, y: -5)
                } else {
                    RoundedRectangle(cornerRadius: LCRadius.card, style: .continuous)
                        .fill(
                            LCColor.surface
                                .shadow(.inner(color: LCColor.shadowDark, radius: 3.5, x: 3, y: 3))
                                .shadow(.inner(color: LCColor.shadowLight, radius: 3.5, x: -3, y: -3))
                        )
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: LCRadius.card, style: .continuous)
                        .stroke(LCColor.glyph(.blue), lineWidth: 2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#if DEBUG
#Preview {
    SubscriptionView(subscriptionManager: SubscriptionManager())
        .modelContainer(for: MainSettings.self, inMemory: true)
}
#endif
