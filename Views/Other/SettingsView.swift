//
//  SettingsView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import SwiftData
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

private let sharedDb = Firestore.firestore()
import LocalAuthentication

private let settingsTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var storedSettings: Color = .pink
    @State private var textColor: Color = .black
    @State private var weekStartDay: String = WeekdayUtility.defaultWeekStartDay
    @State private var skipReviews: Bool = false
    
    // Notification settings
    @State private var notificationTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var dailyNotifications: Bool = false
    @State private var weeklyNotifications: Bool = false
    
    // Security settings
    @State private var biometricLogin: Bool = false
    @State private var showBiometricAlert = false
    @State private var biometricAlertMessage = ""
    @State private var showPasswordPrompt = false
    @State private var showDeleteAccount = false
    @State private var passwordForBiometric = ""
    
    // Community settings
    @State private var useAppleIntelligence: Bool = false

    // PIN settings
    @State private var idealAddPin: String = ""
    @State private var confirmPin: String = ""
    @State private var showPinSettings = false
    
    @State private var showDrawer = false
    @State private var navigateToIdealList: String? = nil
    @State private var currentUserId: String = ""
    @State private var showColorPicker = false
    @State private var tempColor: Color = .pink
    @State private var tempTextColor: Color = .black
    @ObservedObject private var dateProvider = DateProviderService.shared
    @State private var resetWeeklyPromptsOnDateChange: Bool = true
    @State private var testModeEnabled: Bool = true
    @State private var isSavingSettings: Bool = false
    @State private var showSaveConfirmation: Bool = false
    @State private var dateTimePickerId = UUID()
    
    private let accentDefault: Color = .pink
    @Query var storedSettingss: [MainSettings]
    var accentColor: Color {
        var stored_format_color = Color("default_color")
        if let firstColor = storedSettingss.first{
            stored_format_color = Color(red: firstColor.red, green: firstColor.green, blue: firstColor.blue, opacity: firstColor.opacity)
        }
        return stored_format_color
   }
    
    init(accentDefault: Color, start_day: String, skip_reviews: Bool) {
        _storedSettings = State(initialValue: accentDefault)
        _weekStartDay = State(initialValue: start_day)
        _skipReviews = State(initialValue: skip_reviews)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TopNav(pageTitle: "Settings", isIdealList: false, showDrawer: $showDrawer, showingNewItemView: .constant(false))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Week & Appearance", topPadding: 14)
                        weekAppearanceGroup

                        sectionHeader("Reviews")
                        reviewsGroup

                        sectionHeader("Notifications")
                        notificationsGroup

                        // Testing-only surface: the virtual clock and Test Mode
                        // must never reach the App Store. A user flipping the
                        // date override would silently corrupt their own week
                        // data, and Apple treats visible test scaffolding as
                        // beta content (guideline 2.2).
                        #if DEBUG
                        sectionHeader("App Time (Testing)")
                        appTimeGroup
                        #endif

                        // The only community setting configures the community
                        // browser, which is switched off (AppStoreConfig).
                        if AppStoreConfig.isCommunityIdealsEnabled {
                            sectionHeader("Community")
                            communityGroup
                        }

                        sectionHeader("Security")
                        securityGroup

                        sectionHeader("Account")
                        accountGroup
                    }
                    .padding(.bottom, 12)
                }
                .background(LCColor.surface)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        // Gradient fade effect
                        LinearGradient(
                            gradient: Gradient(colors: [LCColor.surface.opacity(0), LCColor.surface.opacity(0.95)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                        .allowsHitTesting(false)

                        // Button container with full-width semi-transparent background.
                        // Yellow = key-CTA fill per the handoff; TLButton renders the
                        // raised neumorphic capsule.
                        VStack {
                            TLButton(title: "Save Settings", background: LCColor.yellow) {
                                saveSettings()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                        }
                        .frame(maxWidth: .infinity)
                        .background(LCColor.surface.opacity(0.85))
                    }
                }
            }
            .background(LCColor.surface.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                loadSettings()
            }
            .alert("Biometric Verification", isPresented: $showBiometricAlert) {
                Button("OK") {
                    showBiometricAlert = false
                }
            } message: {
                Text(biometricAlertMessage)
            }
            .alert("Settings Saved", isPresented: $showSaveConfirmation) {
                Button("OK") {
                    showSaveConfirmation = false
                }
            } message: {
                Text("Your settings have been saved. Weekly prompts will re-evaluate based on the selected date.")
            }
            .overlay {
                if isSavingSettings {
                    ZStack {
                        LCColor.ink.opacity(0.18)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(LCColor.pink)
                            Text("Saving Settings...")
                                .font(.manrope(16, .bold))
                                .foregroundColor(LCColor.ink)
                        }
                        .padding(32)
                        .neuRaised(cornerRadius: LCRadius.card)
                    }
                }
            }
            .sheet(isPresented: $showPasswordPrompt) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 0) {
                        NeuSheetHeader(title: "Enable \(LoginViewViewModel.getBiometricType())", titleSize: 26) {
                            showPasswordPrompt = false
                            passwordForBiometric = ""
                            biometricLogin = false
                        } onSave: {
                            guard !passwordForBiometric.isEmpty else { return }
                            enableBiometricLogin()
                        }
                        sectionHeader("Enter Password", topPadding: 8)
                        SecureField("Password", text: $passwordForBiometric)
                            .textFieldStyle(NeumorphicTextFieldStyle())
                            .padding(.horizontal, LCMetrics.screenMargin)
                        Spacer()
                    }
                    .background(LCColor.surface.ignoresSafeArea())
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountView(onDeleted: {
                    // The auth state listener drops the app back to login on its
                    // own; nothing here should try to read the deleted user.
                    showDeleteAccount = false
                })
            }
            .sheet(isPresented: $showPinSettings) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 0) {
                        NeuSheetHeader(title: "Ideal Add PIN") {
                            showPinSettings = false
                            idealAddPin = ""
                            confirmPin = ""
                        } onSave: {
                            guard idealAddPin.count >= 4, idealAddPin == confirmPin,
                                  let firstSettings = storedSettingss.first else { return }
                            firstSettings.idealAddPin = idealAddPin
                            showPinSettings = false
                            idealAddPin = ""
                            confirmPin = ""
                        }
                        sectionHeader("Set PIN for Adding Ideals", topPadding: 8)
                        VStack(spacing: 14) {
                            SecureField("PIN", text: $idealAddPin)
                                .keyboardType(.numberPad)
                                .textFieldStyle(NeumorphicTextFieldStyle())
                            SecureField("Confirm PIN", text: $confirmPin)
                                .keyboardType(.numberPad)
                                .textFieldStyle(NeumorphicTextFieldStyle())
                        }
                        .padding(.horizontal, LCMetrics.screenMargin)
                        Spacer()
                    }
                    .background(LCColor.surface.ignoresSafeArea())
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { navigateToIdealList == currentUserId && !currentUserId.isEmpty },
                set: { if !$0 { navigateToIdealList = nil } }
            )) {
                IdealListView(userId: currentUserId)
            }
        }
        .tint(LCColor.pink)
        .padding(.leading, MenuDrawer.contentInset)   // iPad sidebar inset (0 on iPhone)
        .overlay(alignment: .top) {
            MenuDrawer(showDrawer: $showDrawer, activeView: "settings")
        }
        .zIndex(9999)
    }

    // MARK: - Neumorphic section builders (7b Settings handoff)

    /// HH Samuel section header — deep pink, uppercase (handoff 7b).
    private func sectionHeader(_ title: String, topPadding: CGFloat = 20) -> some View {
        Text(title)
            .font(.hhSamuel(22))
            .kerning(0.3)
            .textCase(.uppercase)
            .foregroundColor(LCColor.deepPink)
            .padding(.horizontal, 24)
            .padding(.top, topPadding)
            .padding(.bottom, 8)
    }

    /// Manrope 800/16 ink row label (handoff row spec).
    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.manrope(16, .heavy))
            .foregroundColor(LCColor.ink)
    }

    /// Account — the only destructive action in Settings. Apple requires an
    /// in-app way to delete an account for any app that offers account creation
    /// (Review Guideline 5.1.1(v)); the confirmation lives in DeleteAccountView.
    private var accountGroup: some View {
        VStack(spacing: 0) {
            Button {
                HapticFeedback.impact()
                showDeleteAccount = true
            } label: {
                HStack {
                    Text("Delete Account")
                        .font(.manrope(16, .heavy))
                        .foregroundColor(LCColor.deepPink)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(LCColor.deepPink.opacity(0.6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .neuGroupedRow()
        }
        .padding(.horizontal, LCMetrics.screenMargin)
    }

    /// Week & Appearance — First Day of Week picker + Primary Colors swatch.
    private var weekAppearanceGroup: some View {
        VStack(spacing: 0) {
            Menu {
                Picker("First Day of Week", selection: $weekStartDay) {
                    Text("Monday").tag("Monday")
                    Text("Tuesday").tag("Tuesday")
                    Text("Wednesday").tag("Wednesday")
                    Text("Thursday").tag("Thursday")
                    Text("Friday").tag("Friday")
                    Text("Saturday").tag("Saturday")
                    Text("Sunday").tag("Sunday")
                }
            } label: {
                HStack {
                    rowLabel("First Day of Week")
                    Spacer()
                    HStack(spacing: 8) {
                        Text(weekStartDay)
                            .font(.manrope(16, .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(LCColor.pink)
                }
                .padding(.horizontal, 18)
                .neuGroupedRow()
                .contentShape(Rectangle())
            }
            .accessibilityLabel("First Day of Week")
            .accessibilityValue(weekStartDay)

            NeuFeatheredDivider()

            Button(action: {
                tempColor = storedSettings
                tempTextColor = textColor
                showColorPicker = true
            }) {
                HStack {
                    rowLabel("Primary Colors")
                    Spacer()
                    // Raised colour swatch (30pt, small-control shadow)
                    Color.clear
                        .frame(width: 30, height: 30)
                        .neuRaised(Circle(), fill: storedSettings, cssOffset: 3, cssBlur: 7)
                }
                .padding(.horizontal, 18)
                .neuGroupedRow()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showColorPicker) {
                NavigationStack {
                    VStack(spacing: 20) {
                        NeuSheetHeader(title: "Select Colors") {
                            showColorPicker = false
                        } onSave: {
                            storedSettings = tempColor
                            textColor = tempTextColor
                            showColorPicker = false
                        }
                        LCPaletteSwatchRow(title: "Theme Color",
                                           selection: $tempColor,
                                           options: LCPaletteSwatchRow.themeOptions)
                            .padding(.horizontal, LCMetrics.screenMargin)
                            .padding(.top, 6)

                        LCPaletteSwatchRow(title: "Text Color",
                                           selection: $tempTextColor,
                                           options: LCPaletteSwatchRow.textOptions)
                            .padding(.horizontal, LCMetrics.screenMargin)

                        Spacer()
                    }
                    .background(LCColor.surface.ignoresSafeArea())
                    .toolbar(.hidden, for: .navigationBar)
                }
                .presentationDetents([.medium])
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
    }

    /// Notifications — pink time value + NeuToggleStyle daily/weekly toggles.
    /// Reviews — the same weekly skip switch the onboarding "Skip Reviews This
    /// Week?" toggle writes. While ON, completing an ideal logs the action but
    /// skips the mood-review screen; it auto-resets at the start of the week.
    private var reviewsGroup: some View {
        Toggle(isOn: $skipReviews) {
            rowLabel("Skip Reviews This Week?")
        }
        .toggleStyle(NeuToggleStyle())
        .padding(.horizontal, 18)
        .neuGroupedRow()
    }

    private var notificationsGroup: some View {
        VStack(spacing: 0) {
            HStack {
                rowLabel("Notification Time")
                Spacer()
                // Pink time value painted OVER the real DatePicker (7a/7b handoff
                // treatment), so its grey capsule is hidden but every touch still
                // reaches it. Do not flip this back to a near-transparent picker
                // on top: UIKit skips hit-testing at alpha <= 0.01, which looked
                // fine and silently ate every tap.
                DatePicker(selection: $notificationTime, displayedComponents: .hourAndMinute) {
                    Text("Notification Time")
                }
                .labelsHidden()
                .overlay {
                    Text(formatTime(notificationTime))
                        .font(.manrope(16, .semibold))
                        .foregroundColor(LCColor.pink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(LCColor.surface)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .fixedSize()
            }
            .padding(.horizontal, 18)
            .neuGroupedRow()

            NeuFeatheredDivider()

            Toggle(isOn: $dailyNotifications) {
                rowLabel("Daily Notifications")
            }
            .toggleStyle(NeuToggleStyle())
            .padding(.horizontal, 18)
            .neuGroupedRow()

            NeuFeatheredDivider()

            Toggle(isOn: $weeklyNotifications) {
                rowLabel("Weekly Notifications")
            }
            .toggleStyle(NeuToggleStyle())
            .padding(.horizontal, 18)
            .neuGroupedRow()
        }
        .padding(.horizontal, LCMetrics.screenMargin)
    }

    /// App Time (Testing) — virtual-date override controls (not in the handoff;
    /// styled in-system so the testing rows read like every other group).
    private var appTimeGroup: some View {
        VStack(spacing: 0) {
            Toggle(isOn: Binding(
                get: { !dateProvider.isVirtualDateOverrideEnabled },
                set: { dateProvider.setUsingDeviceTime($0) }
            )) {
                rowLabel("Use Automatic Device Date & Time")
            }
            .toggleStyle(NeuToggleStyle())
            .padding(.horizontal, 18)
            .neuGroupedRow()

            if dateProvider.isVirtualDateOverrideEnabled {
                NeuFeatheredDivider()

                HStack {
                    rowLabel("Manual App Date & Time")
                    Spacer(minLength: 12)
                    DatePicker(
                        "Manual App Date & Time",
                        selection: Binding(
                            get: { dateProvider.virtualDate },
                            set: { newDate in
                                dateProvider.virtualDate = newDate
                                if resetWeeklyPromptsOnDateChange {
                                    clearWeeklyPromptKeys()
                                }
                            }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .fixedSize()
                    .id(dateTimePickerId)
                    .onChange(of: dateProvider.virtualDate) { oldValue, newValue in
                        let oldDay = Calendar.current.startOfDay(for: oldValue)
                        let newDay = Calendar.current.startOfDay(for: newValue)
                        let oldIsAM = Calendar.current.component(.hour, from: oldValue) < 12
                        let newIsAM = Calendar.current.component(.hour, from: newValue) < 12
                        if newDay != oldDay || newIsAM != oldIsAM {
                            dateTimePickerId = UUID()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .neuGroupedRow()

                NeuFeatheredDivider()

                Toggle(isOn: $resetWeeklyPromptsOnDateChange) {
                    rowLabel("Reset Weekly Prompts on Date Change")
                }
                .toggleStyle(NeuToggleStyle())
                .padding(.horizontal, 18)
                .neuGroupedRow()

                NeuFeatheredDivider()

                Toggle(isOn: $testModeEnabled) {
                    rowLabel("Test Mode")
                }
                .toggleStyle(NeuToggleStyle())
                .padding(.horizontal, 18)
                .neuGroupedRow()
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
    }

    /// Community — Apple Intelligence toggle + helper copy.
    private var communityGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: $useAppleIntelligence) {
                rowLabel("Use Apple Intelligence?")
            }
            .toggleStyle(NeuToggleStyle())
            .padding(.horizontal, 18)
            .neuGroupedRow()

            if useAppleIntelligence {
                Text("Your ideal titles are shared anonymously to power community Top Ideals. On-device AI filters out personal items.")
                    .font(.manrope(13, .medium))
                    .foregroundColor(LCColor.textSecondary)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
    }

    /// Security — biometric login toggle + Secret PIN row.
    private var securityGroup: some View {
        VStack(spacing: 0) {
            Toggle(isOn: Binding(
                get: { biometricLogin },
                set: { newValue in
                    if newValue {
                        // First verify biometric, then prompt for password
                        verifyBiometric { success, error in
                            if success {
                                // Prompt for password to store credentials
                                showPasswordPrompt = true
                            } else {
                                biometricLogin = false
                                biometricAlertMessage = error ?? "Biometric verification failed."
                                showBiometricAlert = true
                            }
                        }
                    } else {
                        biometricLogin = false
                        // Clear stored credentials and disable biometric login
                        UserDefaults.standard.set(false, forKey: "biometric_login_enabled")
                        clearStoredCredentials()
                    }
                }
            )) {
                rowLabel("Login with \(LoginViewViewModel.getBiometricType())")
            }
            .toggleStyle(NeuToggleStyle())
            .padding(.horizontal, 18)
            .neuGroupedRow()

            NeuFeatheredDivider()

            Button(action: {
                if let storedPin = storedSettingss.first?.idealAddPin {
                    idealAddPin = storedPin
                }
                confirmPin = ""
                showPinSettings = true
            }) {
                HStack {
                    rowLabel("Secret PIN")
                    Spacer()
                    if let storedPin = storedSettingss.first?.idealAddPin, !storedPin.isEmpty {
                        Text("Set")
                            .font(.manrope(15, .medium))
                            .foregroundColor(LCColor.textSecondary)
                    } else {
                        Text("Not Set")
                            .font(.manrope(15, .medium))
                            .foregroundColor(LCColor.textSecondary)
                    }
                }
                .padding(.horizontal, 18)
                .neuGroupedRow()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, LCMetrics.screenMargin)
    }
    
    private func saveSettings() {
        let components = storedSettings.getComponents()
        let textColorComponents = textColor.getComponents()
        let oldWeekStartDay = storedSettingss.first?.week_start_day
                                
        // Get userId right before navigation to ensure it's available
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        if let existingSettings = storedSettingss.first {
            // Update existing settings in place - this preserves all values including new ones
            existingSettings.red = components.red
            existingSettings.green = components.green
            existingSettings.blue = components.blue
            existingSettings.opacity = components.opacity
            existingSettings.textColorRed = textColorComponents.red
            existingSettings.textColorGreen = textColorComponents.green
            existingSettings.textColorBlue = textColorComponents.blue
            existingSettings.textColorOpacity = textColorComponents.opacity
            existingSettings.week_start_day = weekStartDay
            // Freshly enabling "Skip Reviews This Week?": stamp the set date so
            // the week-start auto-reset (checkAndResetSkipReviews) can tell the
            // following week apart and turn reviews back on. Without a stamp
            // (0), the reset guard bails and the skip would persist forever.
            if skipReviews && !existingSettings.skip_reviews {
                existingSettings.skip_reviews_last_reset_date = dateProvider.now().timeIntervalSince1970
            }
            existingSettings.skip_reviews = skipReviews

            // Update notification settings
            existingSettings.notification_time = formatTime(notificationTime)
            existingSettings.daily_notifications = dailyNotifications
            existingSettings.weekly_notifications = weeklyNotifications
            
            // Update testing settings
            existingSettings.resetWeeklyPromptsOnDateChange = resetWeeklyPromptsOnDateChange
            existingSettings.testModeEnabled = testModeEnabled

            // Update community settings
            existingSettings.useAppleIntelligence = useAppleIntelligence

            // Update security settings
            existingSettings.biometric_login = biometricLogin
            // PIN is already saved when user sets it in the sheet
            // Sync with UserDefaults
            UserDefaults.standard.set(biometricLogin, forKey: "biometric_login_enabled")
            if !biometricLogin {
                clearStoredCredentials()
            }
        } else {
            // Create new settings
            let newstoredSettings = MainSettings(
                red: components.red,
                green: components.green,
                blue: components.blue,
                opacity: components.opacity,
                week_start_day: weekStartDay,
                skip_reviews: skipReviews,
                skip_reviews_last_reset_date: skipReviews ? dateProvider.now().timeIntervalSince1970 : 0,
                textColorRed: textColorComponents.red,
                textColorGreen: textColorComponents.green,
                textColorBlue: textColorComponents.blue,
                textColorOpacity: textColorComponents.opacity,
                notification_time: formatTime(notificationTime),
                daily_notifications: dailyNotifications,
                weekly_notifications: weeklyNotifications,
                biometric_login: biometricLogin
            )
            modelContext.insert(newstoredSettings)
        }
        
        // Schedule notifications
        NotificationManager.shared.scheduleDailyNotification(time: notificationTime, enabled: dailyNotifications)
        NotificationManager.shared.scheduleWeeklyNotification(enabled: weeklyNotifications, weekStartDay: weekStartDay)
        // Always schedule planning unlocked notification (it's a core feature notification)
        NotificationManager.shared.schedulePlanningUnlockedNotification(enabled: true, weekStartDay: weekStartDay)
        if weeklyNotifications {
            NotificationManager.shared.calculateAndUpdateWeeklyNotification(weekStartDay: weekStartDay)
        }
        
        // When using manual date override, show spinner + confirmation and clear weekly keys
        let isManualDate = dateProvider.isVirtualDateOverrideEnabled

        let finalizeNavigation: () -> Void = {
            if isManualDate {
                // Clear weekly prompt keys so the prompt re-evaluates with the new virtual date
                if resetWeeklyPromptsOnDateChange {
                    clearWeeklyPromptKeys()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isSavingSettings = false
                    showSaveConfirmation = true
                }
            } else {
                DispatchQueue.main.async {
                    currentUserId = userId
                    navigateToIdealList = userId
                }
            }
        }

        if isManualDate {
            isSavingSettings = true
        }

        if let oldWeekStartDay, oldWeekStartDay != weekStartDay {
            migrateIdealsForWeekStartChange(
                userId: userId,
                oldWeekStartDay: oldWeekStartDay,
                newWeekStartDay: weekStartDay,
                completion: finalizeNavigation
            )
        } else {
            finalizeNavigation()
        }
    }

    /// Re-anchor current/next-week ideals when week start day changes so weekly boundaries
    /// follow the newly selected start day transition rules.
    private func migrateIdealsForWeekStartChange(
        userId: String,
        oldWeekStartDay: String,
        newWeekStartDay: String,
        completion: @escaping () -> Void
    ) {
        let now = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)

        let oldCurrentWeekStart = WeekdayUtility.weekStart(for: now, weekStartDay: oldWeekStartDay)
        let oldNextWeekStart = WeekdayUtility.nextWeekRange(for: now, weekStartDay: oldWeekStartDay).start
        guard let oldNextNextWeekStart = calendar.date(byAdding: .day, value: 7, to: oldNextWeekStart) else {
            completion()
            return
        }

        let currentWeekday = calendar.component(.weekday, from: now)
        let newWeekday = WeekdayUtility.weekdayIndex(for: newWeekStartDay)

        let migratedCurrentWeekStart: Date
        let migratedNextWeekStart: Date

        // Week always starts on the next occurrence after today.
        var daysUntilNextStart = (newWeekday - currentWeekday + 7) % 7
        if daysUntilNextStart == 0 { daysUntilNextStart = 7 }

        guard let nextStart = calendar.date(byAdding: .day, value: daysUntilNextStart, to: todayStart),
              let previousWeekAnchor = calendar.date(byAdding: .day, value: -7, to: nextStart) else {
            completion()
            return
        }

        migratedNextWeekStart = calendar.startOfDay(for: nextStart)
        migratedCurrentWeekStart = calendar.startOfDay(for: previousWeekAnchor)

        let oldCurrentWeekStartTS = oldCurrentWeekStart.timeIntervalSince1970
        let oldNextWeekStartTS = oldNextWeekStart.timeIntervalSince1970
        let oldNextNextWeekStartTS = oldNextNextWeekStart.timeIntervalSince1970
        let migratedCurrentWeekStartTS = migratedCurrentWeekStart.timeIntervalSince1970
        let migratedNextWeekStartTS = migratedNextWeekStart.timeIntervalSince1970

        let db = sharedDb
        let userRef = db.collection("users").document(userId)

        let idealsQuery = userRef
            .collection("ideals")
            .whereField("startDate", isGreaterThanOrEqualTo: oldCurrentWeekStartTS)
            .whereField("startDate", isLessThan: oldNextNextWeekStartTS)

        let plannedRecordsQuery = userRef
            .collection(PlannedIdealRecord.collectionName)
            .whereField("startDate", isGreaterThanOrEqualTo: oldCurrentWeekStartTS)
            .whereField("startDate", isLessThan: oldNextNextWeekStartTS)

        let group = DispatchGroup()
        let lock = NSLock()
        var pendingUpdates: [(DocumentReference, [String: Any])] = []
        var firstError: Error?

        func collectUpdates(from snapshot: QuerySnapshot?) {
            let documents = snapshot?.documents ?? []
            for doc in documents {
                let startDate = doc.data()["startDate"] as? TimeInterval ?? 0
                guard startDate > 0 else { continue }

                let targetStartDate: TimeInterval
                if startDate < oldNextWeekStartTS {
                    targetStartDate = migratedCurrentWeekStartTS
                } else {
                    targetStartDate = migratedNextWeekStartTS
                }

                // Skip no-op updates.
                guard abs(startDate - targetStartDate) > 0.5 else { continue }
                pendingUpdates.append((doc.reference, ["startDate": targetStartDate]))
            }
        }

        group.enter()
        idealsQuery.getDocuments { snapshot, error in
            lock.lock()
            defer {
                lock.unlock()
                group.leave()
            }
            if let error {
                firstError = firstError ?? error
                return
            }
            collectUpdates(from: snapshot)
        }

        group.enter()
        plannedRecordsQuery.getDocuments { snapshot, error in
            lock.lock()
            defer {
                lock.unlock()
                group.leave()
            }
            if let error {
                firstError = firstError ?? error
                return
            }
            collectUpdates(from: snapshot)
        }

        group.notify(queue: .main) {
            if let firstError {
                AppLogger.error(AppLogger.firestore, "[SettingsView] Week start migration query failed: \(firstError.localizedDescription)")
                completion()
                return
            }

            guard !pendingUpdates.isEmpty else {
                completion()
                return
            }

            commitStartDateUpdates(pendingUpdates, completion: completion)
        }
    }

    private func commitStartDateUpdates(
        _ updates: [(DocumentReference, [String: Any])],
        completion: @escaping () -> Void
    ) {
        guard !updates.isEmpty else {
            completion()
            return
        }

        let chunkSize = 400
        let chunks: [[(DocumentReference, [String: Any])]] = stride(from: 0, to: updates.count, by: chunkSize).map { index in
            Array(updates[index..<min(index + chunkSize, updates.count)])
        }

        let db = sharedDb

        func commitChunk(_ chunkIndex: Int) {
            guard chunkIndex < chunks.count else {
                completion()
                return
            }

            let batch = db.batch()
            for (ref, data) in chunks[chunkIndex] {
                batch.updateData(data, forDocument: ref)
            }

            batch.commit { error in
                if let error {
                    AppLogger.error(AppLogger.firestore, "[SettingsView] Week start migration commit failed: \(error.localizedDescription)")
                    completion()
                    return
                }

                commitChunk(chunkIndex + 1)
            }
        }

        commitChunk(0)
    }
    
    private func loadSettings() {
        // Get current user ID
        if let userId = Auth.auth().currentUser?.uid {
            currentUserId = userId
        }
        // Load existing settings
        if let firstSettings = storedSettingss.first {
            storedSettings = Color(red: firstSettings.red, green: firstSettings.green, blue: firstSettings.blue, opacity: firstSettings.opacity)
            tempColor = storedSettings
            textColor = Color(red: firstSettings.textColorRed, green: firstSettings.textColorGreen, blue: firstSettings.textColorBlue, opacity: firstSettings.textColorOpacity)
            tempTextColor = textColor
            weekStartDay = firstSettings.week_start_day
            skipReviews = firstSettings.skip_reviews
            
            // Load notification settings
            if let notifTime = firstSettings.notification_time, let time = parseTimeString(notifTime) {
                notificationTime = time
            }
            dailyNotifications = firstSettings.daily_notifications
            weeklyNotifications = firstSettings.weekly_notifications
            
            // Load testing settings
            resetWeeklyPromptsOnDateChange = firstSettings.resetWeeklyPromptsOnDateChange
            testModeEnabled = firstSettings.testModeEnabled

            // Load community settings
            useAppleIntelligence = firstSettings.useAppleIntelligence

            // Load security settings - sync with UserDefaults
            biometricLogin = firstSettings.biometric_login
            UserDefaults.standard.set(biometricLogin, forKey: "biometric_login_enabled")
        } else {
            // If no settings exist, use pink as default
            storedSettings = .pink
            tempColor = .pink
            textColor = .black
            tempTextColor = .black
        }
    }
    
    private func parseTimeString(_ timeString: String) -> Date? {
        settingsTimeFormatter.date(from: timeString)
    }

    private func formatTime(_ date: Date) -> String {
        settingsTimeFormatter.string(from: date)
    }
    
    private func checkAndEnableNotificationsIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    // Enable notification toggles if permission is granted
                    if let firstSettings = storedSettingss.first {
                        firstSettings.daily_notifications = true
                        firstSettings.weekly_notifications = true
                        dailyNotifications = true
                        weeklyNotifications = true
                    }
                }
            }
        }
    }
    
    
    private func verifyBiometric(completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let biometricType = LoginViewViewModel.getBiometricType()
            let reason = "Verify your identity to enable \(biometricType) login."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        completion(true, nil)
                    } else {
                        let message = authenticationError?.localizedDescription ?? "Biometric verification failed."
                        completion(false, message)
                    }
                }
            }
        } else {
            let message = error?.localizedDescription ?? "Biometric authentication not available."
            completion(false, message)
        }
    }
    
    private func clearStoredCredentials() {
        BiometricCredentialStore.shared.clear()
    }
    
    private func clearWeeklyPromptKeys() {
        let prefixes = [
            "weeklyFlowProcessed_",
            "weeklyPlanningSheetShown_",
            "lastWeekReviewPromptShown_",
            "weeklyPromptOpenCount_"
        ]
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if prefixes.contains(where: { key.hasPrefix($0) }) {
                defaults.removeObject(forKey: key)
            }
        }
        // The "already offered in this app open" stamp is in-memory, so the
        // sweep above cannot reach it. Without this, the recap re-shows after a
        // virtual-date change but the choice behind it is silently skipped.
        IdealListView.resetWeeklyPromptPresentedMarker()
    }

    private func enableBiometricLogin() {
        guard let email = Auth.auth().currentUser?.email, !passwordForBiometric.isEmpty else {
            biometricAlertMessage = "Please enter your password."
            showBiometricAlert = true
            biometricLogin = false
            showPasswordPrompt = false
            return
        }
        
        // Verify password by attempting to re-authenticate
        let credential = EmailAuthProvider.credential(withEmail: email, password: passwordForBiometric)
        Auth.auth().currentUser?.reauthenticate(with: credential) { result, error in
            DispatchQueue.main.async {
                if error == nil {
                    // Password is correct, store credentials and enable biometric login
                    BiometricCredentialStore.shared.store(email: email, password: passwordForBiometric)
                    UserDefaults.standard.set(true, forKey: "biometric_login_enabled")
                    biometricLogin = true
                    passwordForBiometric = ""
                    showPasswordPrompt = false
                    
                    // Update MainSettings
                    if let existingSettings = storedSettingss.first {
                        existingSettings.biometric_login = true
                    }
                } else {
                    biometricLogin = false
                    biometricAlertMessage = "Incorrect password. Please try again."
                    showBiometricAlert = true
                    passwordForBiometric = ""
                    showPasswordPrompt = false
                }
            }
        }
    }
}

#Preview {
    SettingsView(accentDefault: .blue, start_day: "Monday", skip_reviews: false)
}
