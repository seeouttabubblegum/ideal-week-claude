//
//  AddIdealPinView.swift
//  The Ideal Week
//
//  Created on 1/15/25.
//
//  Restyled to the 2026-07 neumorphic handoff — screen 7i "Add Ideal PIN":
//  raised lock circle, blue HH Samuel "ENTER SECRET PIN", 4 sunken PIN boxes
//  (active box pink-bordered), raised yellow Confirm. PIN entry logic and
//  PinCursorView behavior are unchanged.
//

import SwiftUI

/// Blinking cursor shown in the active PIN digit box.
private struct PinCursorView: View {
    @State private var isVisible = true
    var body: some View {
        Rectangle()
            .fill(LCColor.ink)
            .frame(width: 2, height: 26)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isVisible)
            .onAppear { isVisible = false }
    }
}

struct AddIdealPinView: View {
    @ObservedObject var viewModel: AddIdealPinViewModel
    let storedPin: String?
    @Binding var isPresented: Bool
    let onSuccess: () -> Void
    let accentColor: Color
    let isForPlanning: Bool // Flag to indicate if PIN is for planning (parent will handle sheet dismissal)
    @FocusState private var focusedField: Int?
    @FocusState private var isPinEntryFocused: Bool // Single hidden field for PIN so backspace works correctly
    @FocusState private var isConfirmPinFocused: Bool // Single hidden field for confirm PIN
    @FocusState private var isReasonFieldFocused: Bool
    /// When true, show "Why plan early?" on the same screen (planning flow only); no separate reason screen.
    @State private var showPlanningReasonOnPinScreen = false

    /// PIN digit box metrics per the 7i handoff (58×58, radius 16, sunken 3/7).
    private static let pinBoxSize: CGFloat = 58
    private static let pinBoxRadius: CGFloat = 16

    var body: some View {
        NavigationStack {
            if viewModel.currentScreen == .pinEntry {
                pinEntryScreen
            } else {
                reasonScreen
            }
        }
    }

    /// Confirm button for the "Why plan early?" reason step. Hosted in a bottom
    /// safe-area inset on both reason surfaces so it floats above the keyboard
    /// (the reason field can otherwise push it under the keyboard, out of reach).
    @ViewBuilder private var confirmReasonButton: some View {
        Button(action: {
            guard viewModel.canConfirm() else {
                viewModel.showReasonError = true
                return
            }
            viewModel.showReasonError = false
            // Call onSuccess first — it handles closing the sheet for planning.
            onSuccess()
            // Only close here when not for planning; the parent closes it otherwise.
            if !isForPlanning {
                DispatchQueue.main.async { isPresented = false }
            }
        }) {
            Text("Confirm")
        }
        .buttonStyle(NeumorphicButtonStyle(
            tint: viewModel.canConfirm() ? LCColor.pink : LCColor.textMuted,
            fill: viewModel.canConfirm() ? LCColor.yellow : LCColor.surface,
            font: .manrope(18, .heavy)))
        .disabled(!viewModel.canConfirm())
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(LCColor.surface)
    }

    private var pinEntryScreen: some View {
        VStack(spacing: 0) {
            // Header — pinned above the scroll so the close button is always reachable.
            HStack {
                NeuCloseButton(action: { isPresented = false }, diameter: 36)
                Spacer()
            }
            .padding(.horizontal, LCMetrics.screenMargin)
            .frame(height: 56)

            // Scrollable body so the reason field + Confirm stay reachable once
            // the keyboard is up; minHeight keeps it vertically centred when idle.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 0)

            // Pink lock glyph in a raised circle (7i).
            Image(systemName: "lock")
                .font(.system(size: 28, weight: .semibold))
                .accentText(.pink)
                .frame(width: 66, height: 66)
                .neuRaisedCircle(cssOffset: 5, cssBlur: 12)
                .accessibilityHidden(true)

            Text("ENTER\nSECRET PIN")
                .font(.hhSamuel(34))
                .accentText(.blue)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
                .accessibilityLabel("Enter Secret PIN")

            if storedPin == nil || storedPin?.isEmpty == true {
                Text("Set a PIN to add more ideals after 2 days from week start")
                    .font(.manrope(14, .medium))
                    .foregroundColor(LCColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 250)
                    .padding(.horizontal)
            } else {
                Text("Enter your PIN to add more ideals")
                    .font(.manrope(14, .medium))
                    .foregroundColor(LCColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 250)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                // PIN input - single hidden TextField so number pad backspace works (clears previous digit)
                HStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { index in
                        ZStack(alignment: .leading) {
                            Text(viewModel.pinDigits[index])
                                .font(.manrope(24, .heavy))
                                .foregroundColor(LCColor.ink)
                            // Show cursor in the active digit box when PIN field is focused
                            if isPinEntryFocused && index == min(viewModel.enteredPinFromDigits.count, 3) {
                                HStack(spacing: 2) {
                                    Text(viewModel.pinDigits[index])
                                        .font(.manrope(24, .heavy))
                                        .opacity(0)
                                    PinCursorView()
                                }
                            }
                        }
                        .frame(width: Self.pinBoxSize, height: Self.pinBoxSize)
                        .neuSunken(cornerRadius: Self.pinBoxRadius, cssOffset: 3, cssBlur: 7)
                        .overlay(
                            RoundedRectangle(cornerRadius: Self.pinBoxRadius)
                                .stroke(focusedField == index ? LCColor.pink : Color.clear, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { isPinEntryFocused = true }
                    }
                }
                .padding(.horizontal)
                .overlay(
                    TextField("", text: Binding(
                        get: { viewModel.enteredPinFromDigits },
                        set: { newValue in
                            let digits = Array(newValue.filter { $0.isNumber }.prefix(4))
                            viewModel.pinDigits = (0..<4).map { i in i < digits.count ? String(digits[i]) : "" }
                            viewModel.showPinError = false
                            // Defer FocusState update to avoid Objective-C exception from updating focus during binding
                            let newCount = viewModel.enteredPinFromDigits.count
                            DispatchQueue.main.async {
                                focusedField = min(newCount, 3)
                            }
                            if newCount == 4 {
                                let isFirstTimeSetup = storedPin == nil || storedPin?.isEmpty == true
                                if isFirstTimeSetup {
                                    // First-time setup: move cursor to first digit of confirm PIN section
                                    DispatchQueue.main.async {
                                        isPinEntryFocused = false
                                        isConfirmPinFocused = true
                                        focusedField = 4
                                    }
                                } else {
                                    viewModel.checkPinComplete(storedPin: storedPin, onError: {
                                        DispatchQueue.main.async { focusedField = 0 }
                                    }) {
                                        if isForPlanning {
                                            showPlanningReasonOnPinScreen = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                                isReasonFieldFocused = true
                                            }
                                        } else {
                                            withAnimation {
                                                viewModel.currentScreen = .reason
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    ))
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isPinEntryFocused)
                    .frame(width: 1, height: 1)
                    .opacity(0)
                )

                // Show confirm PIN fields only when setting PIN for first time
                if storedPin == nil || storedPin?.isEmpty == true {
                    Text("Confirm PIN")
                        .font(.manrope(14, .semibold))
                        .foregroundColor(LCColor.textSecondary)
                        .padding(.top, 8)

                    HStack(spacing: 14) {
                        ForEach(0..<4, id: \.self) { index in
                            ZStack(alignment: .leading) {
                                Text(viewModel.confirmPinDigits[index])
                                    .font(.manrope(24, .heavy))
                                    .foregroundColor(LCColor.ink)
                                // Show cursor in the active digit box when confirm PIN field is focused
                                if isConfirmPinFocused && index == min(viewModel.confirmPinFromDigits.count, 3) {
                                    HStack(spacing: 2) {
                                        Text(viewModel.confirmPinDigits[index])
                                            .font(.manrope(24, .heavy))
                                            .opacity(0)
                                        PinCursorView()
                                    }
                                }
                            }
                            .frame(width: Self.pinBoxSize, height: Self.pinBoxSize)
                            .neuSunken(cornerRadius: Self.pinBoxRadius, cssOffset: 3, cssBlur: 7)
                            .overlay(
                                RoundedRectangle(cornerRadius: Self.pinBoxRadius)
                                    .stroke(focusedField == index + 4 ? LCColor.pink : Color.clear, lineWidth: 2)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { isConfirmPinFocused = true }
                        }
                    }
                    .padding(.horizontal)
                    .overlay(
                        TextField("", text: Binding(
                            get: { viewModel.confirmPinFromDigits },
                            set: { newValue in
                                let digits = Array(newValue.filter { $0.isNumber }.prefix(4))
                                viewModel.confirmPinDigits = (0..<4).map { i in i < digits.count ? String(digits[i]) : "" }
                                viewModel.showPinError = false
                                let newCount = viewModel.confirmPinFromDigits.count
                                DispatchQueue.main.async {
                                    focusedField = min(newCount, 3) + 4
                                }
                                if viewModel.enteredPinFromDigits.count == 4 && newCount == 4 {
                                    viewModel.checkPinComplete(storedPin: storedPin, onError: {
                                        // PINs don't match: move cursor back to first digit of first section
                                        DispatchQueue.main.async {
                                            focusedField = 0
                                            isConfirmPinFocused = false
                                            isPinEntryFocused = true
                                        }
                                    }) {
                                        viewModel.isSettingPin = true
                                        withAnimation {
                                            viewModel.currentScreen = .reason
                                        }
                                    }
                                }
                            }
                        ))
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($isConfirmPinFocused)
                        .frame(width: 1, height: 1)
                        .opacity(0)
                    )
                }

                if viewModel.showPinError {
                    Text(viewModel.pinErrorMessage)
                        .font(.manrope(12, .semibold))
                        .accentText(.pink)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal)

            // Planning flow: "Why plan early?" on same screen so it's one combined PIN + reason step
            if isForPlanning && showPlanningReasonOnPinScreen {
                VStack(spacing: 16) {
                    Text("Why do you want to plan early?")
                        .font(.manrope(18, .heavy))
                        .foregroundColor(LCColor.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Enter your reason", text: $viewModel.reason, axis: .vertical)
                            .textFieldStyle(NeumorphicTextFieldStyle())
                            .lineLimit(3...6)
                            .focused($isReasonFieldFocused)
                            .onChange(of: viewModel.reason) { oldValue, newValue in
                                viewModel.showReasonError = false
                            }
                        if viewModel.showReasonError {
                            Text("This field is mandatory")
                                .font(.manrope(12, .semibold))
                                .accentText(.pink)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 24)
            }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        // Confirm floats above the keyboard so a long reason can't hide it.
        .safeAreaInset(edge: .bottom) {
            if isForPlanning && showPlanningReasonOnPinScreen {
                confirmReasonButton
            }
        }
        .background(LCColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            focusedField = 0
            isPinEntryFocused = true
        }
    }

    private var reasonScreen: some View {
        VStack(spacing: 20) {
            // Header — raised back chevron (returns to PIN entry) + standard close (cancels).
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentScreen = .pinEntry
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(LCColor.glyph(.pink))
                }
                .buttonStyle(NeuCircleButtonStyle(diameter: 36))
                .accessibilityLabel("Back")

                Spacer()

                // Dismissing without onSuccess cancels the planning flow (parent onDismiss clears pendingPlanningAction)
                NeuCloseButton(action: { isPresented = false }, diameter: 36)
            }
            .padding(.horizontal, LCMetrics.screenMargin)
            .frame(height: 56)

            Spacer()

            Text("Why do you want to plan early?")
                .font(.manrope(20, .heavy))
                .foregroundColor(LCColor.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter your reason", text: $viewModel.reason, axis: .vertical)
                    .textFieldStyle(NeumorphicTextFieldStyle())
                    .lineLimit(3...6)
                    .focused($isReasonFieldFocused)
                    .onChange(of: viewModel.reason) { oldValue, newValue in
                        viewModel.showReasonError = false
                    }

                if viewModel.showReasonError {
                    Text("This field is mandatory")
                        .font(.manrope(12, .semibold))
                        .accentText(.pink)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        // Confirm floats above the keyboard so a long reason can't hide it.
        .safeAreaInset(edge: .bottom) { confirmReasonButton }
        .background(LCColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isReasonFieldFocused = true
            }
        }
    }
}

#if DEBUG
#Preview {
    PreviewData.configureFirebaseIfNeeded()
    return AddIdealPinView(
        viewModel: AddIdealPinViewModel(),
        storedPin: "1234",
        isPresented: .constant(true),
        onSuccess: {},
        accentColor: LCColor.pink,
        isForPlanning: false
    )
}
#endif
