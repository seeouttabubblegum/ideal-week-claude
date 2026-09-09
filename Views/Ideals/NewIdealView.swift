//
//  NewIdealView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import SwiftUI
import SwiftData

struct NewIdealView: View {
    @StateObject var viewModel = NewIdealViewViewModel()
    @Binding var newItemPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var setReminder: Bool = false
    @Query var storedAccentColors: [MainSettings]


    var accentColor: Color {
        // Follows the palette chosen in Settings (LCPalette).
        LCColor.pink
    }

    init(newItemPresented: Binding<Bool>, category:Category? = nil, wishlist: Bool = false, editingItem: Ideal? = nil){
        self._newItemPresented = newItemPresented
        self._viewModel = StateObject(wrappedValue: NewIdealViewViewModel(category: category, wishlist: wishlist, editingItem: editingItem))
        // Initialize slider value based on targetCount
    }

    // MARK: - Neumorphic header (close · title · save-check), replaces the nav bar (1i design)
    private var header: some View {
        ZStack {
            Text(viewModel.editingItemId != nil ? "Edit Ideal" : "New Ideal")
                .font(.hhSamuel(40))
                .textCase(.uppercase)
                .accentText(.pink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 56)
            HStack {
                NeuCloseButton {
                    newItemPresented = false
                    dismiss()
                }
                Spacer()
                NeuCheckSaveButton(diameter: 40) {
                    if viewModel.canSave {
                        viewModel.save(setReminder: setReminder, weekStartDay: storedAccentColors.first?.week_start_day) { success in
                            if success {
                                newItemPresented = false
                                dismiss()
                            } else if !viewModel.showAlert {
                                viewModel.alertMessage = "Could not save ideal. Please try again."
                                viewModel.showAlert = true
                            }
                        }
                    } else {
                        // Set alert message based on validation failure
                        viewModel.validateAndSetAlertMessage()
                        viewModel.showAlert = true
                    }
                }
                // While a save is in flight (the duplicate check can take a few
                // seconds on a slow network), disable the button and show a
                // spinner so a second tap can't trigger the bogus-error/dup race.
                .disabled(viewModel.isSaving)
                .opacity(viewModel.isSaving ? 0.55 : (viewModel.canSave ? 1.0 : 0.6))
                .overlay {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(LCColor.pink)
                    }
                }
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .frame(minHeight: 56)
        .padding(.top, 8)
    }

    // Section header — HH Samuel at ~75% of category-title size (handoff 1i).
    // Vertical rhythm kept tight so the whole form fits above the keyboard.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.hhSamuel(23))
            .textCase(.uppercase)
            .accentText(.pink)
            .padding(.leading, LCMetrics.screenMargin)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.wishlistEnabled {
                        // For wishlist items, only show the prompt + title field (1f styling)
                        Text("What piece might fit the puzzle next?")
                            .font(.manrope(16, .heavy))
                            .foregroundColor(LCColor.ink)
                            .padding(.horizontal, LCMetrics.screenMargin)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        VoiceTitleField(
                            text: $viewModel.title,
                            placeholder: "Title",
                            accentColor: LCColor.pink
                        )
                        .padding(.horizontal, LCMetrics.screenMargin)
                        .padding(.vertical, 14)
                    } else {
                        // For regular ideals, show all fields
                        sectionHeader("Ideal Information")
                        VStack(alignment: .leading, spacing: 0) {
                            if let cat = Category(rawValue: viewModel.category) {
                                Text(cat.subheading)
                                    .font(.idealTitle(21))
                                    .foregroundColor(LCColor.ink)
                                    .imprinted()
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 10)
                                    .padding(.bottom, 8)
                                NeuFeatheredDivider()
                            }
                            VoiceTitleField(
                                text: $viewModel.title,
                                placeholder: "Title",
                                accentColor: LCColor.pink
                            )
                            .padding(.vertical, 10)

                            NeuFeatheredDivider()

                            VStack(alignment: .leading, spacing: 12) {
                                // The chosen category is named in the label, so
                                // the row below can be icons alone.
                                CategorySelectionLabel(selection: viewModel.category)
                                CategoryIconRow(selection: $viewModel.category)
                            }
                            .padding(.vertical, 14)

                            NeuFeatheredDivider()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("How Often?")
                                    .font(.manrope(16, .heavy))
                                    .foregroundColor(LCColor.ink)

                                // Same slider as the wishlist quick-add sheet.
                                HowOftenSliderView(value: Binding(
                                    get: { HowOftenSlider.value(fromLabel: viewModel.targetCount) },
                                    set: { viewModel.targetCount = HowOftenSlider.label(for: $0) }
                                ))
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 8)
                            .id("newIdealFormBottom")
                        }
                        .padding(.horizontal, LCMetrics.screenMargin)
                    }
                }
                .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                // Client fix: with the keyboard open, the WHOLE form (incl. the
                // How Often 1–6+ labels) must sit above the keyboard. When the
                // keyboard slides in, scroll the form's bottom into view once
                // the reduced viewport is in place.
                .onReceive(NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillShowNotification)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("newIdealFormBottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(LCColor.surface.ignoresSafeArea())
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.alertMessage),
                dismissButton: .cancel(Text("OK"))
            )
        }
    }
}

#Preview {
    NewIdealView(newItemPresented: Binding(get: {
        return true
    }, set: { _ in

    }))
}
