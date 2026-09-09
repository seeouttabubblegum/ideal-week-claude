//
//  CountrySelectionView.swift
//  The Ideal Week
//
//  Created for country selection
//

import SwiftUI

// MARK: - Shared neumorphic picker chrome (7p handoff — private to this file)

/// Centered HH Samuel title with a raised round back button on the left.
private struct NeuSelectionHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.hhSamuel(32))
                .textCase(.uppercase)
                .accentText(.pink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 60)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(LCColor.glyph(.pink))
                }
                .buttonStyle(NeuCircleButtonStyle(diameter: 36))
                .accessibilityLabel("Back")
                Spacer()
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .frame(minHeight: LCMetrics.rowHeight)
    }
}

/// Sunken search field (7p handoff).
private struct NeuSelectionSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(LCColor.textMuted)
            TextField("Search", text: $text)
                .font(.manrope(15, .medium))
                .foregroundColor(LCColor.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .neuSunken(cornerRadius: 16)
        .padding(.horizontal, LCMetrics.screenMargin)
    }
}

/// Single option row — Manrope label, blue check when selected, 56pt tap target.
private struct NeuSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.manrope(17, .semibold))
                    .foregroundColor(LCColor.ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .heavy))
                        .accentText(.blue)
                }
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: LCMetrics.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct CountrySelectionView: View {
    @Binding var selectedCountry: String
    @Binding var selectedState: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredCountries: [String] {
        let all = CountryStateData.countries.filter { !$0.isEmpty }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            NeuSelectionHeader(title: "Select Country") { dismiss() }

            NeuSelectionSearchBar(text: $searchText)
                .padding(.top, 14)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCountries, id: \.self) { country in
                        NeuSelectionRow(title: country, isSelected: country == selectedCountry) {
                            // Ensure country is valid before setting
                            let countries = CountryStateData.countries
                            guard !country.isEmpty, !countries.isEmpty, countries.contains(country) else { return }
                            selectedCountry = country
                            if country != "United States" {
                                selectedState = ""
                            }
                            dismiss()
                        }
                        if country != filteredCountries.last {
                            NeuFeatheredDivider(widthFraction: 0.88)
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .background(LCColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct StateSelectionView: View {
    @Binding var selectedState: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredStates: [String] {
        let all = CountryStateData.usStates.filter { !$0.isEmpty }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            NeuSelectionHeader(title: "Select State") { dismiss() }

            NeuSelectionSearchBar(text: $searchText)
                .padding(.top, 14)

            ScrollView {
                LazyVStack(spacing: 0) {
                    NeuSelectionRow(title: "Select State", isSelected: selectedState.isEmpty) {
                        selectedState = ""
                        dismiss()
                    }

                    ForEach(filteredStates, id: \.self) { state in
                        NeuFeatheredDivider(widthFraction: 0.88)
                        NeuSelectionRow(title: state, isSelected: state == selectedState) {
                            // Ensure state is valid before setting
                            let states = CountryStateData.usStates
                            guard !state.isEmpty, !states.isEmpty, states.contains(state) else { return }
                            selectedState = state
                            dismiss()
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .background(LCColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct HeightFeetSelectionView: View {
    @Binding var selectedFeet: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            NeuSelectionHeader(title: "Select Feet") { dismiss() }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(3...8, id: \.self) { feet in
                        if feet > 3 {
                            NeuFeatheredDivider(widthFraction: 0.88)
                        }
                        NeuSelectionRow(title: "\(feet) ft", isSelected: feet == selectedFeet) {
                            selectedFeet = feet
                            dismiss()
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .background(LCColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct HeightInchesSelectionView: View {
    @Binding var selectedInches: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            NeuSelectionHeader(title: "Select Inches") { dismiss() }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { inches in
                        if inches > 0 {
                            NeuFeatheredDivider(widthFraction: 0.88)
                        }
                        NeuSelectionRow(title: "\(inches) in", isSelected: inches == selectedInches) {
                            selectedInches = inches
                            dismiss()
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .background(LCColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var selectedCountry = "United States"
    @Previewable @State var selectedState = ""
    NavigationStack {
        CountrySelectionView(
            selectedCountry: $selectedCountry,
            selectedState: $selectedState
        )
    }
}
#endif

