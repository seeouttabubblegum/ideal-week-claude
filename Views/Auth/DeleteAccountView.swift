//
//  DeleteAccountView.swift
//  The Ideal Week
//
//  In-app account deletion. Required by App Store Review Guideline 5.1.1(v)
//  for any app that offers account creation.
//
//  The flow is deliberately slow: the user must read what goes, type DELETE,
//  and — when Firebase asks for a fresh sign-in — re-enter their password. This
//  cannot be undone, so an accidental tap must not be enough to trigger it.
//

import SwiftUI

struct DeleteAccountView: View {
    /// Called after the account is gone, so the host can drop back to login.
    var onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var confirmationText = ""
    @State private var password = ""
    @State private var needsPassword = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    private let requiredConfirmation = "DELETE"

    private var confirmationMatches: Bool {
        confirmationText.trimmingCharacters(in: .whitespaces).uppercased() == requiredConfirmation
    }

    private var canSubmit: Bool {
        guard !isWorking, confirmationMatches else { return false }
        return needsPassword ? !password.isEmpty : true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    whatGetsDeleted
                    confirmationField
                    if needsPassword { passwordField }
                    if let errorMessage { errorBanner(errorMessage) }
                    deleteButton
                    cancelButton
                }
                .padding(.horizontal, LCMetrics.screenMargin)
                .padding(.vertical, 24)
            }
            .background(LCColor.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                NeuSheetHeader(title: "Delete Account") { dismiss() }
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    // MARK: - Pieces

    private var header: some View {
        Text("This permanently deletes your account and everything in it. It cannot be undone.")
            .font(.manrope(16, .heavy))
            .foregroundColor(LCColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var whatGetsDeleted: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What will be removed")
                .font(.manrope(14, .heavy))
                .accentText(.pink)
                .textCase(.uppercase)
            ForEach([
                "Your ideals, for every week",
                "Your review scores and progress history",
                "Your plans for the coming week",
                "Your profile and sign-in details",
                "Reminders this app created on this device",
            ], id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Text("•").accentText(.pink)
                    Text(line)
                        .font(.manrope(15, .medium))
                        .foregroundColor(LCColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neuRaised(cornerRadius: LCRadius.card)
    }

    private var confirmationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type \(requiredConfirmation) to confirm")
                .font(.manrope(14, .heavy))
                .foregroundColor(LCColor.ink)
            TextField(requiredConfirmation, text: $confirmationText)
                .font(.manrope(16, .medium))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(14)
                .neuSunken(cornerRadius: LCRadius.field)
                .disabled(isWorking)
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Re-enter your password")
                .font(.manrope(14, .heavy))
                .foregroundColor(LCColor.ink)
            SecureField("Password", text: $password)
                .font(.manrope(16, .medium))
                .textContentType(.password)
                .padding(14)
                .neuSunken(cornerRadius: LCRadius.field)
                .disabled(isWorking)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.manrope(14, .medium))
            .accentText(.pink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deleteButton: some View {
        Button {
            HapticFeedback.impact(style: .heavy)
            submit()
        } label: {
            HStack(spacing: 8) {
                if isWorking { ProgressView().tint(LCColor.pink) }
                Text(isWorking ? "Deleting…" : "Delete My Account")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink, font: .manrope(18, .heavy)))
        .opacity(canSubmit ? 1 : 0.5)
        .disabled(!canSubmit)
    }

    private var cancelButton: some View {
        Button("Cancel") { dismiss() }
            .font(.manrope(16, .heavy))
            .accentText(.pink)
            .frame(maxWidth: .infinity)
            .disabled(isWorking)
    }

    // MARK: - Actions

    private func submit() {
        errorMessage = nil
        isWorking = true

        if needsPassword {
            AccountDeletionService.shared.reauthenticate(password: password) { result in
                switch result {
                case .failure(let error):
                    isWorking = false
                    errorMessage = error.errorDescription
                case .success:
                    performDelete()
                }
            }
        } else {
            performDelete()
        }
    }

    private func performDelete() {
        AccountDeletionService.shared.deleteAccount { result in
            isWorking = false
            switch result {
            case .success:
                onDeleted()
                dismiss()
            case .failure(.requiresRecentLogin):
                // Nothing was deleted — the service checks this before touching
                // any data, so retrying after the password is entered is safe.
                needsPassword = true
                errorMessage = AccountDeletionError.requiresRecentLogin.errorDescription
            case .failure(let error):
                errorMessage = error.errorDescription
            }
        }
    }
}
