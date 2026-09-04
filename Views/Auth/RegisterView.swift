//
//  RegisterView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//
//  2026-07 neumorphic redesign (handoff 5b): same full-bleed cover magenta
//  system as 5a Login — recessed capsule fields, raised blue "Create Account",
//  blue round back button with a yellow chevron, infinity graphic above the
//  "Already Have An Account? / Log In" line.
//

import SwiftUI

// MARK: - Cover neumorphics (5a/5b/2c — the shadows are tinted to the cover, not grey)
//
// The four values used to be frozen `static let`s holding the Present palette's
// pink, copied into all three cover screens. They now come from LCAuthCover, so
// the ground, its two shadows and its links rotate together. Present is byte for
// byte what the handoff specified.

private typealias AuthCover = LCAuthCover

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
                    Circle().fill(LCColor.blueFill)
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
                    .foregroundColor(AuthCover.foreground.opacity(0.85))
            }
            TextField("", text: $text)
                .font(.manrope(16, .semibold))
                .foregroundColor(AuthCover.foreground)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
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
        .padding(.vertical, 17)
        .authSunkenCapsule()
    }
}

struct RegisterView: View {
    @StateObject var viewModel = RegisterViewViewModel()
    @State private var showErrorAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    // Custom cover back control (system back bar is hidden)
                    HStack {
                        AuthBackButton {
                            HapticFeedback.impact()
                            dismiss()
                        }
                        Spacer()
                    }

                    AuthLabel(type: "register")
                        .padding(.top, 6)

                    VStack(spacing: 16) {
                        AuthTextField(placeholder: "First Name", text: $viewModel.first_name)
                            .autocorrectionDisabled()
                        AuthTextField(placeholder: "Last Name", text: $viewModel.last_name)
                            .autocorrectionDisabled()
                        AuthTextField(placeholder: "Email Address", text: $viewModel.email)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        AuthSecureField(placeholder: "Password", text: $viewModel.password)

                        Button {
                            HapticFeedback.impact()
                            viewModel.register()
                        } label: {
                            Text("Create Account")
                        }
                        .buttonStyle(AuthCoverButtonStyle())
                        .padding(.top, 12)
                    }
                    .padding(.top, 32)

                    Spacer(minLength: 36)

                    // Cover infinity graphic above the account line
                    Image("Infinity")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 128)
                        .padding(.bottom, 22)
                        .accessibilityHidden(true)

                    VStack(spacing: 4) {
                        Text("Already Have An Account?")
                            .font(.manrope(16, .medium))
                            .foregroundColor(AuthCover.foreground.opacity(0.85))
                        Button {
                            HapticFeedback.impact()
                            dismiss()
                        } label: {
                            Text("Log In")
                                .font(.manrope(16, .bold))
                                .foregroundColor(AuthCover.link)
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
        .tint(AuthCover.link)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Registration Error", isPresented: $showErrorAlert) {
            Button("OK") {
                showErrorAlert = false
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.errorMessage) { oldValue, newValue in
            if !newValue.isEmpty {
                showErrorAlert = true
            }
        }
    }
}

#Preview {
    RegisterView()
}
