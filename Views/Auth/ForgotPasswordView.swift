//
//  ForgotPasswordView.swift
//  The Ideal Week
//
//  Created for password reset functionality
//
//  2026-07 neumorphic redesign (handoff 2c): matches the 5a/5b cover system —
//  full-bleed magenta, "RESET PASSWORD" wordmark in HH Samuel blue, recessed
//  email capsule, raised blue "Send Reset Link", blue round back button with
//  a yellow chevron, "Remembered It? / Back To Login" line at the bottom.
//

import SwiftUI

// MARK: - Pink-tuned cover neumorphics (file-local copy; see LoginView.swift)

private enum AuthCover {
    static let background  = LCColor.deepPink          // #E5197F full-bleed
    static let shadowDark  = Color(hex: 0xBC1066)      // pink dark shadow
    static let shadowLight = Color(hex: 0xFF2694)      // pink light shadow
    static let linkYellow  = Color(hex: 0xEDEF12)      // cover yellow links
}

private extension View {
    /// Sunken (recessed) capsule field on the pink cover background.
    func authSunkenCapsule() -> some View {
        background(
            Capsule().fill(
                AuthCover.background
                    .shadow(.inner(color: AuthCover.shadowDark, radius: 5.5, x: 5, y: 5))
                    .shadow(.inner(color: AuthCover.shadowLight, radius: 5.5, x: -5, y: -5))
            )
        )
    }
}

/// Raised BLUE capsule button (cover CTA); depresses to sunken while pressed.
private struct AuthCoverButtonStyle: ButtonStyle {
    var font: Font = .manrope(18, .heavy)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if configuration.isPressed {
                        Capsule().fill(
                            LCColor.blue
                                .shadow(.inner(color: AuthCover.shadowDark, radius: 4, x: 4, y: 4))
                                .shadow(.inner(color: AuthCover.shadowLight, radius: 4, x: -4, y: -4))
                        )
                    } else {
                        Capsule().fill(LCColor.blue)
                            .shadow(color: AuthCover.shadowDark, radius: 7, x: 6, y: 6)
                            .shadow(color: AuthCover.shadowLight, radius: 7, x: -6, y: -6)
                    }
                }
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Blue raised round back control with a YELLOW chevron (handoff 5b/2c).
private struct AuthBackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(LCColor.yellow)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(LCColor.blue)
                        .shadow(color: AuthCover.shadowDark, radius: 5, x: 5, y: 5)
                        .shadow(color: AuthCover.shadowLight, radius: 5, x: -5, y: -5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

/// Plain-text sunken capsule field with a cover-styled placeholder.
private struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.manrope(16, .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            TextField("", text: $text)
                .font(.manrope(16, .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .authSunkenCapsule()
    }
}

struct ForgotPasswordView: View {
    @ObservedObject var viewModel: LoginViewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    // Cover back control (replaces the old toolbar xmark)
                    HStack {
                        AuthBackButton {
                            HapticFeedback.impact()
                            dismiss()
                        }
                        Spacer()
                    }

                    // "RESET PASSWORD" wordmark + helper copy
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: -9) {
                            Text("RESET")
                            Text("PASSWORD")
                        }
                        .font(.hhSamuel(50))
                        .foregroundColor(LCColor.blue)
                        .shadow(color: .black.opacity(0.14), radius: 0, x: 3, y: 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Reset Password")

                        Text("Enter your email address and we'll send you a link to reset your password.")
                            .font(.manrope(15, .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 34)

                    VStack(spacing: 18) {
                        AuthTextField(placeholder: "Email Address", text: $viewModel.resetEmail)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)

                        if !viewModel.resetErrorMessage.isEmpty {
                            Text(viewModel.resetErrorMessage)
                                .font(.manrope(14, .semibold))
                                .foregroundColor(AuthCover.linkYellow)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                        }

                        if !viewModel.resetSuccessMessage.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(viewModel.resetSuccessMessage)
                                    .font(.manrope(14, .semibold))
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)

                                Text("If you don't see the email, please check your spam or junk folder.")
                                    .font(.manrope(12, .medium))
                                    .foregroundColor(.white.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                        }

                        Button {
                            HapticFeedback.impact()
                            viewModel.sendPasswordReset()
                        } label: {
                            Text(viewModel.isResettingPassword ? "Sending..." : "Send Reset Link")
                        }
                        .buttonStyle(AuthCoverButtonStyle())
                        .disabled(viewModel.isResettingPassword || !viewModel.isConnected)
                        .opacity((viewModel.isResettingPassword || !viewModel.isConnected) ? 0.6 : 1.0)
                        .padding(.top, 6)
                    }
                    .padding(.top, 44)

                    Spacer(minLength: 36)

                    // Cover infinity graphic above the account line
                    Image("Infinity")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 128)
                        .padding(.bottom, 22)
                        .accessibilityHidden(true)

                    VStack(spacing: 4) {
                        Text("Remembered It?")
                            .font(.manrope(16, .medium))
                            .foregroundColor(.white.opacity(0.85))
                        Button {
                            HapticFeedback.impact()
                            dismiss()
                        } label: {
                            Text("Back To Login")
                                .font(.manrope(16, .bold))
                                .foregroundColor(AuthCover.linkYellow)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.bottom, 24)
                .frame(minHeight: geo.size.height)
            }
        }
        .background(AuthCover.background.ignoresSafeArea())
        .tint(AuthCover.linkYellow)
        .onAppear {
            // Clear messages when view appears
            viewModel.resetErrorMessage = ""
            viewModel.resetSuccessMessage = ""
        }
    }
}

#Preview {
    ForgotPasswordView(viewModel: LoginViewViewModel())
}
