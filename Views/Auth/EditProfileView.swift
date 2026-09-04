//
//  EditProfileView.swift
//  The Ideal Week
//
//  Created for profile editing
//

import SwiftUI
import SwiftData

private let editProfileTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewViewModel
    @Binding var isPresented: Bool
    @Query var storedAccentColors: [MainSettings]
    @State private var firstName: String
    @State private var lastName: String
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    
    // New profile fields
    @State private var dateOfBirth: Date = Date()
    /// Birthday wheels are collapsed until the row is tapped.
    @State private var showBirthdayWheels = false

    /// Latest allowed birthday. Single source for the wheels, the load clamp
    /// and validation, so they can never disagree about the age rule.
    private var birthdayCeiling: Date { DateWheelLogic.minimumAgeCeiling() }
    @State private var gender: String = ""
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    @State private var country: String = "United States"
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 0
    @State private var heightCm: String = ""
    @State private var weightKg: String = ""
    @State private var weightLbs: String = ""
    @State private var wakeUpTime: Date = Calendar.current.date(bySettingHour: 5, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var sleepTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var workTimeStart: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var workTimeEnd: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var bio: String = ""
    @State private var goalFocusAreas: String = ""
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var cachedCountry: String = "United States"
    @State private var cachedState: String = ""
    @State private var showCountrySelection = false
    @State private var showStateSelection = false
    @State private var showFeetSelection = false
    @State private var showInchesSelection = false
    @State private var isInitialized = false
    
    var accentColor: Color {
        if let firstColor = storedAccentColors.first {
            return Color(red: firstColor.red, green: firstColor.green, blue: firstColor.blue, opacity: firstColor.opacity)
        } else {
            return Color("default_color")
        }
    }
    
    init(viewModel: ProfileViewViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        
        // Safely initialize with default values
        let user = viewModel.user
        _firstName = State(initialValue: user?.first_name ?? "")
        _lastName = State(initialValue: user?.last_name ?? "")
        
        // Initialize country with safe default - don't access arrays in init to avoid crashes
        let userCountry = user?.country ?? "United States"
        // Just use the user country or default - validation will happen later
        _country = State(initialValue: userCountry.isEmpty ? "United States" : userCountry)
        // Initialize cached values immediately with safe defaults
        _cachedCountry = State(initialValue: userCountry.isEmpty ? "United States" : userCountry)
        _cachedState = State(initialValue: user?.state ?? "")
        
        // Initialize bio and goalFocusAreas
        _bio = State(initialValue: user?.bio ?? "")
        _goalFocusAreas = State(initialValue: user?.goal_focus_areas ?? "")
        
        // Initialize gender
        _gender = State(initialValue: user?.gender ?? "")
    }
    
    // Removed all computed properties - they were causing crashes during view updates
    // Now using only @State cached values directly

    private var isSaveDisabled: Bool {
        viewModel.isLoading || firstName.isEmpty || lastName.isEmpty || isPasswordChangeIncomplete()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — standard close, HH Samuel title, yellow save-check (handoff 7f)
            ZStack {
                Text("EDIT PROFILE")
                    .font(.hhSamuel(32))
                    .foregroundColor(LCColor.deepPink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 56)
                HStack {
                    NeuCloseButton(action: { isPresented = false }, diameter: 36)
                    Spacer()
                    NeuCheckSaveButton(diameter: 36) {
                        saveProfile()
                    }
                    .disabled(isSaveDisabled)
                    .opacity(isSaveDisabled ? 0.45 : 1)
                }
            }
            .padding(.horizontal, LCMetrics.screenMargin)
            .padding(.top, 14)
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Personal Information")
                    VStack(spacing: 0) {
                        textFieldRow(label: "First Name *", text: $firstName)
                        rowDivider
                        textFieldRow(label: "Last Name *", text: $lastName)
                        rowDivider
                        // Date of Birth — tapping the row reveals three wheels
                        // (day / month / year) inline. The system calendar
                        // popover was dropped at the client's request
                        // (2026-09-02).
                        Button {
                            HapticFeedback.impact()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showBirthdayWheels.toggle()
                            }
                        } label: {
                            HStack {
                                rowLabel("Date of Birth")
                                Spacer(minLength: 12)
                                pinkValue(dateOfBirth.formatted(date: .abbreviated, time: .omitted))
                                Image(systemName: showBirthdayWheels ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(LCColor.pink)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Date of Birth")
                        .accessibilityValue(dateOfBirth.formatted(date: .abbreviated, time: .omitted))
                        .padding(.horizontal, 18)
                        .neuGroupedRow()
                        if showBirthdayWheels {
                            DayMonthYearWheels(date: $dateOfBirth, maximumDate: birthdayCeiling)
                                .padding(.horizontal, 8)
                                .neuGroupedRow()
                        }
                        rowDivider
                        // Gender — menu picker, pink value + pink stacked chevrons
                        Menu {
                            Picker(selection: $gender) {
                                Text("Female").tag("Female")
                                Text("Male").tag("Male")
                                Text("Other").tag("Other")
                                Text("Prefer not to say").tag("Prefer not to say")
                            } label: {
                                Text("Gender")
                            }
                        } label: {
                            HStack {
                                rowLabel("Gender")
                                Spacer(minLength: 12)
                                pinkValue(gender)
                                pickerChevrons
                            }
                            .padding(.horizontal, 18)
                            .neuGroupedRow()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Gender")
                        .accessibilityValue(gender)
                    }
                    .id("personal-info-section")

                    sectionHeader("Address Information")
                    VStack(spacing: 0) {
                        textFieldRow(label: "Address", text: $address)
                        rowDivider
                        textFieldRow(label: "City", text: $city)
                        rowDivider
                        // Use buttons with sheets - use only direct @State access, no computed properties
                        selectorRow(label: "Country", value: cachedCountry) {
                            showCountrySelection = true
                        }

                        // Only show state field if country is United States
                        if cachedCountry == "United States" {
                            rowDivider
                            selectorRow(label: "State", value: cachedState) {
                                showStateSelection = true
                            }
                        }

                        rowDivider
                        // "Zip Code" in the US, "Postal Code" elsewhere — with the
                        // keyboard following, since non-US codes contain letters.
                        textFieldRow(label: AddressFieldCopy.postalLabel(country: cachedCountry),
                                     text: $zipCode,
                                     keyboard: AddressFieldCopy.postalKeyboard(country: cachedCountry))
                    }
                    .id("address-info-section")

                    sectionHeader("Physical Information")
                    VStack(spacing: 0) {
                        if cachedCountry == "United States" {
                            // Imperial system (feet/inches and lbs)
                            HStack {
                                rowLabel("Height")
                                Spacer(minLength: 12)
                                Button(action: {
                                    showFeetSelection = true
                                }) {
                                    HStack(spacing: 6) {
                                        pinkValue("\(heightFeet) ft")
                                        pickerChevrons
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    showInchesSelection = true
                                }) {
                                    HStack(spacing: 6) {
                                        pinkValue("\(heightInches) in")
                                        pickerChevrons
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 12)
                            }
                            .padding(.horizontal, 18)
                            .neuGroupedRow()

                            rowDivider
                            measureFieldRow(label: "Weight", text: $weightLbs, unit: "lbs")
                        } else {
                            // Metric system (cm and kg)
                            measureFieldRow(label: "Height", text: $heightCm, unit: "cm")
                            rowDivider
                            measureFieldRow(label: "Weight", text: $weightKg, unit: "kg")
                        }
                    }
                    .id("physical-info-section")

                    sectionHeader("Daily Schedule")
                    VStack(spacing: 0) {
                        timeRow(label: "Wake Up Time", selection: $wakeUpTime)
                        rowDivider
                        timeRow(label: "Sleep Time", selection: $sleepTime)
                        rowDivider
                        timeRow(label: "Work Start", selection: $workTimeStart)
                        rowDivider
                        timeRow(label: "Work End", selection: $workTimeEnd)
                    }
                    .id("daily-schedule-section")

                    sectionHeader("Account Information")
                    VStack(spacing: 0) {
                        if let email = viewModel.user?.email {
                            HStack {
                                rowLabel("Email")
                                Spacer(minLength: 12)
                                Text(email)
                                    .font(.manrope(14, .semibold))
                                    .foregroundColor(LCColor.textSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 18)
                            .neuGroupedRow()
                            rowDivider
                        }

                        if let joined = viewModel.user?.joined {
                            HStack {
                                rowLabel("Member Since")
                                Spacer(minLength: 12)
                                Text("\(Date(timeIntervalSince1970: joined).formatted(date: .abbreviated, time: .omitted))")
                                    .font(.manrope(15, .semibold))
                                    .foregroundColor(LCColor.textSecondary)
                            }
                            .padding(.horizontal, 18)
                            .neuGroupedRow()
                            rowDivider
                        }

                        secureFieldRow(label: "Current Password", text: $currentPassword)
                        rowDivider
                        secureFieldRow(label: "New Password", text: $newPassword)
                        rowDivider
                        secureFieldRow(label: "Confirm New Password", text: $confirmPassword)
                    }
                    .id("account-info-section")
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(LCColor.surface.ignoresSafeArea())
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showCountrySelection) {
            NavigationStack {
                CountrySelectionView(selectedCountry: $country, selectedState: $state)
            }
            .onDisappear {
                // Update cached values when sheet dismisses
                validatePickerValues()
                updateCachedValues()
            }
        }
        .sheet(isPresented: $showStateSelection) {
            NavigationStack {
                StateSelectionView(selectedState: $state)
            }
            .onDisappear {
                // Update cached values when sheet dismisses
                validatePickerValues()
                updateCachedValues()
            }
        }
        .sheet(isPresented: $showFeetSelection) {
            NavigationStack {
                HeightFeetSelectionView(selectedFeet: $heightFeet)
            }
        }
        .sheet(isPresented: $showInchesSelection) {
            NavigationStack {
                HeightInchesSelectionView(selectedInches: $heightInches)
            }
        }
        .onAppear {
            loadUserData()
            // Validate and update cached values on appear - do it asynchronously to avoid crashes
            DispatchQueue.main.async {
                validatePickerValues()
                updateCachedValues()
                isInitialized = true
            }
        }
        // Only update cached values when country/state actually change
        // Don't validate during text field updates to avoid crashes
    }

    // MARK: - Neumorphic form building blocks (handoff 7f)

    /// HH Samuel section header — deep pink, uppercase.
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.hhSamuel(22))
            .foregroundColor(LCColor.deepPink)
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }

    /// Row label — Manrope 800, ink.
    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.manrope(15, .heavy))
            .foregroundColor(LCColor.ink)
    }

    /// Row value — Manrope, pink.
    private func pinkValue(_ text: String) -> some View {
        Text(text)
            .font(.manrope(15, .semibold))
            .foregroundColor(LCColor.pink)
    }

    /// Pink stacked up/down chevrons shown on picker rows.
    private var pickerChevrons: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(LCColor.pink)
    }

    /// Feathered break between grouped rows.
    private var rowDivider: some View {
        NeuFeatheredDivider(widthFraction: 1)
            .padding(.horizontal, LCMetrics.screenMargin)
    }

    /// 56pt grouped row with an ink label and a trailing pink text field.
    private func textFieldRow(label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            rowLabel(label)
            Spacer(minLength: 12)
            TextField("", text: text)
                .font(.manrope(15, .semibold))
                .foregroundColor(LCColor.pink)
                .tint(LCColor.pink)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
        }
        .padding(.horizontal, 18)
        .neuGroupedRow()
    }

    /// Decimal-pad field row with a trailing unit suffix ("lbs" / "kg" / "cm").
    private func measureFieldRow(label: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            rowLabel(label)
            Spacer(minLength: 12)
            TextField("", text: text)
                .font(.manrope(15, .semibold))
                .foregroundColor(LCColor.pink)
                .tint(LCColor.pink)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
            if !text.wrappedValue.isEmpty {
                Text(unit)
                    .font(.manrope(15, .semibold))
                    .foregroundColor(LCColor.textSecondary)
            }
        }
        .padding(.horizontal, 18)
        .neuGroupedRow()
    }

    /// Secure-entry row (passwords), pink trailing input.
    private func secureFieldRow(label: String, text: Binding<String>) -> some View {
        HStack {
            rowLabel(label)
            Spacer(minLength: 12)
            SecureField("", text: text)
                .font(.manrope(15, .semibold))
                .foregroundColor(LCColor.pink)
                .tint(LCColor.pink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 18)
        .neuGroupedRow()
    }

    /// Hour-and-minute row — native picker kept for tap behavior, dimmed under
    /// the pink Manrope value.
    private func timeRow(label: String, selection: Binding<Date>) -> some View {
        HStack {
            rowLabel(label)
            Spacer(minLength: 12)
            ZStack(alignment: .trailing) {
                DatePicker(selection: selection, displayedComponents: .hourAndMinute) {
                    Text(label)
                }
                .labelsHidden()
                .opacity(0.02)
                pinkValue(formatTime(selection.wrappedValue))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 18)
        .neuGroupedRow()
    }

    /// Full-width tappable row that opens a selection sheet — pink value + chevrons.
    private func selectorRow(label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                rowLabel(label)
                Spacer(minLength: 12)
                pinkValue(value)
                pickerChevrons
            }
            .padding(.horizontal, 18)
            .neuGroupedRow()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func loadUserData() {
        guard let user = viewModel.user else { return }
        
        firstName = user.first_name
        lastName = user.last_name
        
        // Load date of birth
        if let dob = user.date_of_birth {
            let loadedDate = Date(timeIntervalSince1970: dob)
            // Ensure the loaded date satisfies the minimum-age rule
            dateOfBirth = min(loadedDate, DateWheelLogic.minimumAgeCeiling())
        } else {
            // Default to 25 years ago (ensures 16+ requirement)
            let calendar = Calendar.current
            dateOfBirth = calendar.date(byAdding: .year, value: -25, to: Date()) ?? Date()
        }
        
        // Load gender
        gender = user.gender ?? ""
        
        // Load address fields
        address = user.address ?? ""
        city = user.city ?? ""
        state = user.state ?? ""
        zipCode = user.zip_code ?? ""
        
        // Set country - validation will happen asynchronously
        country = user.country ?? "United States"
        if country.isEmpty {
            country = "United States"
        }
        
        // Set state - validation will happen asynchronously
        state = user.state ?? ""
        
        // Update cached values immediately without validation
        cachedCountry = country
        cachedState = state
        
        // Load height and weight based on country
        if country == "United States" {
            // Imperial system
            if let feet = user.height_feet {
                heightFeet = feet
            }
            if let inches = user.height_inches {
                heightInches = inches
            }
            // Convert kg to lbs if weight_kg exists
            if let weightKgValue = user.weight_kg {
                let weightLbsValue = weightKgValue * 2.20462
                weightLbs = String(format: "%.1f", weightLbsValue)
            }
        } else {
            // Metric system
            // Convert feet/inches to cm if they exist
            if let feet = user.height_feet, let inches = user.height_inches {
                let totalInches = Double(feet * 12 + inches)
                let heightCmValue = totalInches * 2.54
                heightCm = String(format: "%.1f", heightCmValue)
            }
            if let weight = user.weight_kg {
                weightKg = String(format: "%.1f", weight)
            }
        }
        
        // Load wake up time
        if let wakeTime = user.wake_up_time, let time = parseTimeString(wakeTime) {
            wakeUpTime = time
        }
        
        // Load sleep time
        if let sleepTimeStr = user.sleep_time, let time = parseTimeString(sleepTimeStr) {
            sleepTime = time
        }
        
        // Load work time
        if let workStart = user.work_time_start, let start = parseTimeString(workStart) {
            workTimeStart = start
        }
        if let workEnd = user.work_time_end, let end = parseTimeString(workEnd) {
            workTimeEnd = end
        }
        
        // Load bio and goalFocusAreas
        bio = user.bio ?? ""
        goalFocusAreas = user.goal_focus_areas ?? ""
        
        // Clear password fields
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        
        // Validate picker values after loading - do it asynchronously to avoid crashes
        DispatchQueue.main.async {
            validatePickerValues()
            updateCachedValues()
        }
    }
    
    private func parseTimeString(_ timeString: String) -> Date? {
        editProfileTimeFormatter.date(from: timeString)
    }

    private func formatTime(_ date: Date) -> String {
        editProfileTimeFormatter.string(from: date)
    }
    
    private func validatePickerValues() {
        // Ensure arrays are not empty before checking
        let countries = CountryStateData.countries
        let states = CountryStateData.usStates
        
        guard !countries.isEmpty else {
            country = "United States"
            return
        }
        
        // Ensure country is valid and not empty
        if country.isEmpty || !countries.contains(country) {
            country = "United States"
        }
        
        // Ensure state is valid if country is US
        if country == "United States" {
            guard !states.isEmpty else {
                state = ""
                return
            }
            if !state.isEmpty && !states.contains(state) {
                state = ""
            }
        } else {
            state = ""
        }
    }
    
    private func updateCachedValues() {
        // Convert between metric and imperial when country changes
        let previousCountry = cachedCountry
        let isNowUS = country == "United States"
        let wasUS = previousCountry == "United States"
        
        // Safely update cached values without causing crashes
        // Use a completely safe approach that never accesses arrays unsafely
        let countries = CountryStateData.countries
        guard !countries.isEmpty else {
            cachedCountry = "United States"
            cachedState = ""
            return
        }
        
        if country.isEmpty {
            cachedCountry = "United States"
        } else {
            // Safely check containment
            let isValid = countries.contains(country)
            cachedCountry = isValid ? country : "United States"
        }
        
        // Only check state if country is US
        if cachedCountry == "United States" {
            let states = CountryStateData.usStates
            guard !states.isEmpty else {
                cachedState = ""
                return
            }
            
            if state.isEmpty {
                cachedState = ""
            } else {
                let isValid = states.contains(state)
                cachedState = isValid ? state : ""
            }
        } else {
            cachedState = ""
        }
        
        // Convert height and weight when switching between systems
        if wasUS && !isNowUS {
            // Converting from imperial to metric
            // Convert feet/inches to cm
            let totalInches = Double(heightFeet * 12 + heightInches)
            let cmValue = totalInches * 2.54
            heightCm = String(format: "%.1f", cmValue)
            
            // Convert lbs to kg
            if let lbsValue = Double(weightLbs) {
                let kgValue = lbsValue / 2.20462
                weightKg = String(format: "%.1f", kgValue)
            }
        } else if !wasUS && isNowUS {
            // Converting from metric to imperial
            // Convert cm to feet/inches
            if let cmValue = Double(heightCm) {
                let totalInches = cmValue / 2.54
                heightFeet = Int(totalInches / 12)
                heightInches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            }
            
            // Convert kg to lbs
            if let kgValue = Double(weightKg) {
                let lbsValue = kgValue * 2.20462
                weightLbs = String(format: "%.1f", lbsValue)
            }
        }
    }
    
    private func isPasswordChangeIncomplete() -> Bool {
        let hasAnyPassword = !currentPassword.isEmpty || !newPassword.isEmpty || !confirmPassword.isEmpty
        if hasAnyPassword {
            return currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty
        }
        return false
    }
    
    private func saveProfile() {
        guard !firstName.isEmpty && !lastName.isEmpty else {
            errorMessage = "First name and last name cannot be empty."
            showError = true
            return
        }
        
        // Validate date of birth (minimum age, and not in the future)
        if dateOfBirth > DateWheelLogic.minimumAgeCeiling() {
            errorMessage = "You must be at least \(DateWheelLogic.minimumAgeYears) years old to use this app."
            showError = true
            return
        }
        if dateOfBirth > Date() {
            errorMessage = "Date of birth cannot be in the future."
            showError = true
            return
        }
        
        // Validate password change if any password fields are filled
        if !currentPassword.isEmpty || !newPassword.isEmpty || !confirmPassword.isEmpty {
            guard !currentPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty else {
                errorMessage = "Please fill in all password fields to change your password."
                showError = true
                return
            }
            
            guard newPassword == confirmPassword else {
                errorMessage = "New password and confirm password do not match."
                showError = true
                return
            }
            
            guard newPassword.count >= 6 else {
                errorMessage = "New password must be at least 6 characters long."
                showError = true
                return
            }
        }
        
        // Prepare profile data
        let profileData: [String: Any?] = [
            "first_name": firstName,
            "last_name": lastName,
            "date_of_birth": dateOfBirth.timeIntervalSince1970,
            "gender": gender.isEmpty ? nil : gender,
            "address": address.isEmpty ? nil : address,
            "city": city.isEmpty ? "" : city,
            "state": (country == "United States" && !state.isEmpty) ? state : "",
            "zip_code": zipCode.isEmpty ? "" : zipCode,
            "country": country,
            "height_feet": country == "United States" ? heightFeet : nil,
            "height_inches": country == "United States" ? heightInches : nil,
            "weight_kg": country == "United States" ? (weightLbs.isEmpty ? nil : (Double(weightLbs) ?? 0) / 2.20462) : (weightKg.isEmpty ? nil : Double(weightKg)),
            "wake_up_time": formatTime(wakeUpTime),
            "sleep_time": formatTime(sleepTime),
            "work_time_start": formatTime(workTimeStart),
            "work_time_end": formatTime(workTimeEnd),
            "bio": bio.isEmpty ? "" : bio,
            "goal_focus_areas": "" // Removed field - always set to empty
        ]
        
        // Update profile
        let currentPwd = currentPassword
        let newPwd = newPassword
        
        viewModel.updateProfile(data: profileData) { success in
            if !success {
                self.errorMessage = "Failed to update profile. Please try again."
                self.showError = true
                return
            }
            
            // Update password if provided
            if !currentPwd.isEmpty && !newPwd.isEmpty {
                viewModel.updatePassword(currentPassword: currentPwd, newPassword: newPwd) { success in
                    if success {
                        self.isPresented = false
                    } else {
                        self.errorMessage = "Failed to update password. Please check your current password and try again."
                        self.showError = true
                    }
                }
            } else {
                self.isPresented = false
            }
        }
    }
}

#Preview {
    EditProfileView(viewModel: ProfileViewViewModel(), isPresented: .constant(true))
}
