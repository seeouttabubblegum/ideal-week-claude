//
//  LoginView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//
//  2026-07 neumorphic redesign (handoff 5a): full-bleed cover magenta screen,
//  pink-tuned neumorphic shadows — fields RECESSED capsules, buttons RAISED
//  blue capsules, links yellow. Infinity cover graphic above the
//  "New Around Here? / Create An Account" line.
//

import SwiftUI
import LocalAuthentication

// MARK: - Cover neumorphics (5a/5b/2c — the shadows are tinted to the cover, not grey)
//
// The four values used to be frozen `static let`s holding the Present palette's
// pink, copied into all three cover screens. They now come from LCAuthCover, so
// the ground, its two shadows and its links rotate together. Present is byte for
// byte what the handoff specified.

private typealias AuthCover = LCAuthCover

/// Sunken (recessed) capsule field on the pink cover background.
/// CSS: inset 5px 5px 11px #bc1066, inset -5px -5px 11px #ff2694.
private extension View {
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

/// Raised BLUE capsule button (cover CTA). Depresses to sunken while pressed.
/// CSS: 6px 6px 14px #bc1066, -6px -6px 14px #ff2694.
private struct AuthCoverButtonStyle: ButtonStyle {
    var font: Font = .manrope(18, .heavy)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            // This label sits on the BLUE capsule, not on the cover ground.
            .foregroundColor(LCColor.legible(.white, onRole: .blue))
            .padding(.horizontal, 24)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if configuration.isPressed {
                        Capsule().fill(
                            LCColor.blueFill
                                .shadow(.inner(color: AuthCover.shadowDark, radius: 4, x: 4, y: 4))
                                .shadow(.inner(color: AuthCover.shadowLight, radius: 4, x: -4, y: -4))
                        )
                    } else {
                        Capsule().fill(LCColor.blueFill)
                            .shadow(color: AuthCover.shadowDark, radius: 7, x: 6, y: 6)
                            .shadow(color: AuthCover.shadowLight, radius: 7, x: -6, y: -6)
                    }
                }
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
                    .foregroundColor(AuthCover.foreground.opacity(0.85))
            }
            TextField("", text: $text)
                .font(.manrope(16, .semibold))
                .foregroundColor(AuthCover.foreground)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .authSunkenCapsule()
    }
}

/// Secure sunken capsule field with the cover eye (show/hide) glyph.
private struct AuthSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.manrope(16, .semibold))
                        .foregroundColor(AuthCover.foreground.opacity(0.85))
                }
                Group {
                    if isRevealed {
                        TextField("", text: $text)
                    } else {
                        SecureField("", text: $text)
                    }
                }
                .font(.manrope(16, .semibold))
                .foregroundColor(AuthCover.foreground)
                .autocapitalization(.none)
            }
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AuthCover.foreground.opacity(0.78))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .authSunkenCapsule()
    }
}

struct LoginView: View {
    @StateObject var viewModel = LoginViewViewModel()
    @State private var showBiometricAlert = false
    @State private var biometricAlertMessage = ""
    @State private var showLoginAlert = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        AuthLabel(type: "login")
                            .padding(.top, 24)

                        if !viewModel.isConnected {
                            Text("You are currently offline. Please check your internet connection.")
                                .font(.manrope(14, .semibold))
                                .foregroundColor(AuthCover.link)
                                .multilineTextAlignment(.center)
                                .padding(.top, 14)
                        }

                        // Sunken fields + yellow link + raised blue CTAs
                        VStack(spacing: 18) {
                            AuthTextField(placeholder: "Email Address", text: $viewModel.email)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)

                            AuthSecureField(placeholder: "Password", text: $viewModel.password)
                                .autocorrectionDisabled()

                            Button(action: {
                                HapticFeedback.impact()
                                showForgotPassword = true
                            }) {
                                Text("Forgot Password?")
                                    .font(.manrope(14, .semibold))
                                    .foregroundColor(AuthCover.link)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .buttonStyle(.plain)

                            VStack(spacing: 16) {
                                if viewModel.isLoggingIn {
                                    ProgressView()
                                        .tint(AuthCover.foreground)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 17)
                                } else {
                                    Button {
                                        HapticFeedback.impact()
                                        viewModel.login()
                                    } label: {
                                        Text("Login")
                                    }
                                    .buttonStyle(AuthCoverButtonStyle())
                                    .disabled(!viewModel.isConnected)
                                }

                                if #available(iOS 15.0, *) {
                                    Button(action: {
                                        HapticFeedback.impact()
                                        viewModel.loginWithBiometrics { success, error in
                                            if success {
                                                // Login will be handled automatically in the viewModel
                                                viewModel.errorMessage = ""
                                                viewModel.biometricError = ""
                                            } else {
                                                if error == "Please enable biometric login first by logging in with your username and password" {
                                                    biometricAlertMessage = error!
                                                    showBiometricAlert = true
                                                } else {
                                                    viewModel.biometricError = error ?? "Biometric login failed."
                                                }
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: getBiometricIcon())
                                                .font(.system(size: 19, weight: .semibold))
                                            Text("Login with \(getBiometricType())")
                                        }
                                    }
                                    .buttonStyle(AuthCoverButtonStyle(font: .manrope(16, .heavy)))
                                    .disabled(!viewModel.isConnected)
                                }
                            }
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
                            Text("New Around Here?")
                                .font(.manrope(16, .medium))
                                .foregroundColor(AuthCover.foreground.opacity(0.85))
                            NavigationLink(destination: RegisterView()) {
                                Text("Create An Account")
                                    .font(.manrope(16, .bold))
                                    .foregroundColor(AuthCover.link)
                            }
                            .disabled(!viewModel.isConnected)
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticFeedback.impact()
                            })
                        }
                    }
                    .padding(.horizontal, 34)
                    .padding(.bottom, 24)
                    .frame(minHeight: geo.size.height)
                }
            }
            .background(AuthCover.background.ignoresSafeArea())
        }
        .tint(AuthCover.link)
        .alert("Biometric Login", isPresented: $showBiometricAlert) {
            Button("OK") {
                showBiometricAlert = false
            }
        } message: {
            Text(biometricAlertMessage)
        }
        .alert("Login Error", isPresented: $showLoginAlert) {
            Button("OK") {
                showLoginAlert = false
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.errorMessage) { oldValue, newValue in
            if !newValue.isEmpty {
                showLoginAlert = true
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(viewModel: viewModel)
        }
    }

    private func getBiometricType() -> String {
        return LoginViewViewModel.getBiometricType()
    }

    private func getBiometricIcon() -> String {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID, .opticID:
                return "faceid"
            case .touchID:
                return "touchid"
            default:
                return "person.badge.key"
            }
        }
        return "person.badge.key"
    }
}

#Preview {
    @Previewable @State var email: String = ""
    @Previewable @State var password: String = ""
    LoginView()
}
