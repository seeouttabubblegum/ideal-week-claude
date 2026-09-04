//
//  ScheduleDetailSheetView.swift
//  The Ideal Week
//
//  Schedule-only detail sheet: title "Schedule", centered ideal name, schedule option, note, map (current/custom address, open in Apple/Google Maps).
//

import SwiftUI
import SwiftData
import FirebaseAuth
import CoreLocation
import MapKit

/// Raised neumorphic rounded-rect button (press inverts to sunken) — the
/// "Use current address" / Apple/Google Maps controls on the 7l design.
private struct NeuRoundedButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(NeuPressableBackground(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                fill: LCColor.surface,
                cssOffset: LCNeumorphism.raisedOffsetMedium,
                cssBlur: LCNeumorphism.raisedBlurMedium,
                pressed: configuration.isPressed))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ScheduleDetailSheetView: View {
    let item: Ideal
    let onDismiss: () -> Void

    @StateObject private var viewModel: IdealEditViewViewModel
    @Query private var storedTempSettings: [MainSettings]
    @Environment(\.dismiss) private var dismiss

    @State private var locationManager = LocationManagerForSchedule()
    @State private var locationError: String?
    @State private var isResolvingLocation = false
    @StateObject private var addressCompleter = AddressAutocompleteManager()
    @State private var addressQuery: String = ""
    @FocusState private var isAddressFieldFocused: Bool

    var accentColor: Color {
        storedTempSettings.first.map { Color(red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.opacity) } ?? Color("default_color")
    }

    var weekStartDay: String {
        storedTempSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
    }

    init(item: Ideal, onDismiss: @escaping () -> Void) {
        self.item = item
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: IdealEditViewViewModel(ideal: item))
    }

    func getRemainingDaysOfWeek(weekStartDay: String) -> [DayInfo] {
        let calendar = Calendar.current
        // Honour the virtual-date override (Settings → manual date) so this
        // picker matches the rest of the app's notion of "now".
        let now = DateProviderService.shared.now()
        let today = calendar.startOfDay(for: now)
        let userCalendar = WeekdayUtility.calendar(firstWeekday: weekStartDay)
        let weekStart = userCalendar.date(from: userCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let weekStartDayStart = calendar.startOfDay(for: weekStart)
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStartDayStart) else { return [] }
        let weekEndDayStart = calendar.startOfDay(for: weekEnd)
        let dayAbbreviations = WeekdayUtility.dayAbbreviations
        var days: [DayInfo] = []
        var currentDate = today
        while currentDate <= weekEndDayStart {
            let weekday = calendar.component(.weekday, from: currentDate)
            let dayOfMonth = calendar.component(.day, from: currentDate)
            days.append(DayInfo(weekday: weekday, abbreviation: dayAbbreviations[weekday - 1], dayNumber: "\(dayOfMonth)"))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = calendar.startOfDay(for: nextDate)
        }
        return days
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    /// Address string to use for "Open in Maps" (custom or resolved current).
    private var addressForMaps: String? {
        let trimmed = (viewModel.locationAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func openInAppleMaps() {
        guard let address = addressForMaps,
              let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://maps.apple.com/?q=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    /// Opens the address in the Google Maps app.
    private func openInGoogleMaps() {
        guard let address = addressForMaps, !address.isEmpty else { return }

        var googleMapsURLComponents = URLComponents(string: "comgooglemaps://")
        googleMapsURLComponents?.queryItems = [
            URLQueryItem(name: "q", value: address)
        ]

        guard let googleMapsURL = googleMapsURLComponents?.url else { return }

        // Launch Google Maps directly. Do not route this button through Apple Maps fallback.
        UIApplication.shared.open(googleMapsURL, options: [:], completionHandler: nil)
    }

    private func useCurrentAddress() {
        locationError = nil
        isResolvingLocation = true
        locationManager.requestLocation { [self] result in
            isResolvingLocation = false
            switch result {
            case .success(let address):
                viewModel.locationAddress = address
                addressQuery = address
                addressCompleter.clear()
            case .failure(let err):
                locationError = err.localizedDescription
            }
        }
    }

    // MARK: - Neumorphic building blocks (7l design)

    /// Section header — HH Samuel, deep pink, uppercase.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.hhSamuel(22))
            .textCase(.uppercase)
            .foregroundColor(LCColor.deepPink)
            .padding(.leading, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    /// Header row: close (cancel) · SCHEDULE · save-check.
    private var header: some View {
        ZStack {
            Text("Schedule")
                .font(.hhSamuel(38))
                .textCase(.uppercase)
                .foregroundColor(LCColor.deepPink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 56)
            HStack {
                NeuCloseButton {
                    onDismiss()
                }
                Spacer()
                NeuCheckSaveButton(diameter: 40) {
                    if viewModel.setReminder && !viewModel.schedules.contains(where: { !$0.days.isEmpty }) {
                        viewModel.setReminder = false
                    }
                    viewModel.reminderError = nil
                    viewModel.save(weekStartDay: weekStartDay) { success in
                        if success {
                            onDismiss()
                        } else {
                            if let reminderError = viewModel.reminderError {
                                viewModel.alertMessage = reminderError
                            } else {
                                viewModel.alertMessage = "Unable to save. Please try again."
                            }
                            viewModel.showAlert = true
                        }
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .frame(minHeight: 56)
        .padding(.top, 8)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Centered ideal name — Newsreader italic, imprinted
                    Text(item.title)
                        .font(.idealTitle(24))
                        .foregroundColor(LCColor.ink)
                        .imprinted()
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    // Reminder group: toggle + day chips + time
                    VStack(alignment: .leading, spacing: 0) {
                        Toggle(isOn: $viewModel.setReminder) {
                            Text("Schedule a Reminder?")
                                .font(.manrope(16, .heavy))
                                .foregroundColor(LCColor.ink)
                        }
                        .toggleStyle(NeuToggleStyle())
                        .neuGroupedRow()
                        .onChange(of: viewModel.setReminder) { _, _ in viewModel.ensureAtLeastOneSchedule() }

                        if viewModel.setReminder {
                            NeuFeatheredDivider()
                            ReminderSchedulesEditor(
                                viewModel: viewModel,
                                accentColor: LCColor.pink,
                                days: getRemainingDaysOfWeek(weekStartDay: weekStartDay)
                            )
                            .padding(.vertical, 14)
                        }
                    }
                    .padding(.horizontal, LCMetrics.screenMargin)

                    sectionHeader("Note")
                    TextField("", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...9)
                        .textFieldStyle(NeumorphicTextFieldStyle())
                        .padding(.horizontal, LCMetrics.screenMargin)

                    sectionHeader("Map")
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: useCurrentAddress) {
                            HStack(spacing: 10) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Use current address")
                                    .font(.manrope(15, .heavy))
                                if isResolvingLocation {
                                    ProgressView()
                                        .tint(LCColor.pink)
                                }
                            }
                            .foregroundColor(LCColor.pink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(NeuRoundedButtonStyle(cornerRadius: 14))
                        .disabled(isResolvingLocation)

                        TextField("Custom address", text: Binding(
                            get: { addressQuery },
                            set: { newValue in
                                addressQuery = newValue
                                viewModel.locationAddress = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newValue
                                addressCompleter.updateQuery(newValue)
                            }
                        ), axis: .vertical)
                            .lineLimit(1...3)
                            .focused($isAddressFieldFocused)
                            .textFieldStyle(NeumorphicTextFieldStyle())

                        if isAddressFieldFocused && !addressCompleter.suggestions.isEmpty {
                            let topSuggestions = Array(addressCompleter.suggestions.prefix(5))
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(topSuggestions.enumerated()), id: \.offset) { index, completion in
                                    Button(action: {
                                        let fullAddress = completion.subtitle.isEmpty
                                            ? completion.title
                                            : "\(completion.title), \(completion.subtitle)"
                                        addressQuery = fullAddress
                                        viewModel.locationAddress = fullAddress
                                        addressCompleter.clear()
                                        isAddressFieldFocused = false
                                    }) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(completion.title)
                                                .font(.manrope(15, .semibold))
                                                .foregroundColor(LCColor.ink)
                                            if !completion.subtitle.isEmpty {
                                                Text(completion.subtitle)
                                                    .font(.manrope(12, .medium))
                                                    .foregroundColor(LCColor.textSecondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)

                                    if index < topSuggestions.count - 1 {
                                        NeuFeatheredDivider()
                                    }
                                }
                            }
                        }

                        if let err = locationError {
                            Text(err)
                                .font(.manrope(12, .medium))
                                .foregroundColor(LCColor.deepPink)
                        }

                        if addressForMaps != nil {
                            HStack(spacing: 10) {
                                Button(action: openInAppleMaps) {
                                    HStack(spacing: 7) {
                                        Image(systemName: "map")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Apple Maps")
                                            .font(.manrope(12.5, .bold))
                                    }
                                    .foregroundColor(LCColor.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .padding(.horizontal, 10)
                                }
                                .buttonStyle(NeuRoundedButtonStyle(cornerRadius: LCRadius.chip))
                                .accessibilityLabel("Open in Apple Maps")
                                Button(action: openInGoogleMaps) {
                                    HStack(spacing: 7) {
                                        Image(systemName: "map.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Google Maps")
                                            .font(.manrope(12.5, .bold))
                                    }
                                    .foregroundColor(LCColor.pink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .padding(.horizontal, 10)
                                }
                                .buttonStyle(NeuRoundedButtonStyle(cornerRadius: LCRadius.chip))
                                .accessibilityLabel("Open in Google Maps")
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, LCMetrics.screenMargin)
                }
                .padding(.bottom, 24)
            }
        }
        .background(LCColor.surface.ignoresSafeArea())
        .onAppear {
            let initialAddress = viewModel.locationAddress ?? ""
            addressQuery = initialAddress
            if !initialAddress.isEmpty {
                addressCompleter.updateQuery(initialAddress)
            }
        }
        .alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK") { viewModel.showAlert = false }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

@MainActor
private final class AddressAutocompleteManager: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func updateQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            clear()
            return
        }
        completer.queryFragment = trimmed
    }

    func clear() {
        suggestions = []
    }
}

extension AddressAutocompleteManager: MKLocalSearchCompleterDelegate {
    // MKLocalSearchCompleter calls delegate methods on the main thread, so MainActor
    // hop is implicit. nonisolated lets us satisfy the non-isolated protocol requirement;
    // body explicitly hops to MainActor to update @Published `suggestions` safely.
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
        }
    }
}

// MARK: - Location manager for "Use current address"
private final class LocationManagerForSchedule: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var completion: ((Result<String, Error>) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation(completion: @escaping (Result<String, Error>) -> Void) {
        guard CLLocationManager.locationServicesEnabled() else {
            completion(.failure(NSError(domain: "ScheduleDetail", code: -1, userInfo: [NSLocalizedDescriptionKey: "Location services are off."])))
            return
        }
        let status = manager.authorizationStatus
        if status == .notDetermined {
            self.completion = completion
            manager.requestWhenInUseAuthorization()
            // requestLocation() will be called from didChangeAuthorization when user allows
        } else if status == .denied || status == .restricted {
            completion(.failure(NSError(domain: "ScheduleDetail", code: -1, userInfo: [NSLocalizedDescriptionKey: "Location access was denied."])))
        } else {
            self.completion = completion
            manager.requestLocation()
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            let comp = self?.completion
            self?.completion = nil
            Task { @MainActor in
                if let error = error {
                    comp?(.failure(error))
                    return
                }
                let address = placemarks?.first.flatMap { pm in
                    [pm.thoroughfare, pm.subThoroughfare, pm.locality, pm.administrativeArea, pm.postalCode, pm.country]
                        .compactMap { $0 }
                        .joined(separator: ", ")
                }
                if let address = address, !address.isEmpty {
                    comp?(.success(address))
                } else {
                    comp?(.failure(NSError(domain: "ScheduleDetail", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not get address for this location."])))
                }
            }
        }
    }
}

extension LocationManagerForSchedule: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            completion?(.failure(NSError(domain: "ScheduleDetail", code: -1, userInfo: [NSLocalizedDescriptionKey: "Location access was denied."])))
            completion = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        reverseGeocode(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(.failure(error))
        completion = nil
    }
}

#if DEBUG
#Preview {
    PreviewData.configureFirebaseIfNeeded()
    return ScheduleDetailSheetView(item: PreviewData.sampleIdeal, onDismiss: {})
}
#endif
