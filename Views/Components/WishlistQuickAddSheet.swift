//
//  WishlistQuickAddSheet.swift
//  The Ideal Week
//
//  Moved out of IdealListView (2026-09-04) verbatim. Behaviour unchanged.
//

import SwiftUI

struct WishlistQuickAddSheet: View {
    let idealTitle: String
    @Binding var selectedCategory: String
    @Binding var selectedTargetCount: Int
    let onCancel: () -> Void
    let onAdd: () -> Void

    /// One margin for every element on the sheet: the section labels, the
    /// category wells and the slider all start on this line, and the wells and
    /// the slider both end on the opposite one.
    private static let contentMargin: CGFloat = 22

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NeuSheetHeader(title: idealTitle, titleSize: 26,
                               onClose: onCancel, onSave: onAdd)
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        section("CATEGORY: \(selectedCategory.uppercased())") { categoryIcons }
                        section("HOW OFTEN?") { howOftenSlider }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Self.contentMargin)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .background(LCColor.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.hhSamuel(16))
                .accentText(.pink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Category

    /// Every category on screen at once, as one row of icons. The chosen one is
    /// named in this sheet's own section header, so the row needs no text.
    private var categoryIcons: some View {
        CategoryIconRow(selection: $selectedCategory)
    }

    // MARK: - How often?

    private var howOftenSlider: some View {
        HowOftenSliderView(value: $selectedTargetCount)
    }
}
