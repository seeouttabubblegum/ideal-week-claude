//
//  OnboardingSettingsView.swift
//  The Ideal Week
//
//  Created for onboarding flow
//

import SwiftData
import SwiftUI
import FirebaseAuth

private let onboardingTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

struct OnboardingSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    // The free-form ColorPicker these two fed is gone — colour is chosen from
    // the four LCPalette schemes in Settings now. They are still loaded from and
    // written back to the MainSettings record unchanged, so the stored shape and
    // the save path are untouched.
    @State private var storedSettings: Color = .pink
    @State private var textColor: Color = .black
    @State private var weekStartDay: String = WeekdayUtility.defaultWeekStartDay
    @State private var skipReviews: Bool = false

    // Notification settings
    @State private var notificationTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var dailyNotifications: Bool = false
    @State private var weeklyNotifications: Bool = false


    @Query var storedSettingss: [MainSettings]

    var accentColor: Color {
        // Follows the palette chosen in Settings (LCPalette).
        LCColor.pink
    }

    var onSave: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Screen title — HH Samuel, blue, stacked two lines (7a handoff)
                    Text("Set Up Your\nPreferences")
                        .font(.hhSamuel(34))
                        .textCase(.uppercase)
                        .accentText(.blue)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    Text("Customize your app experience")
                        .font(.manrope(14, .medium))
                        .foregroundColor(LCColor.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)

                    // Preferences group — rows on the surface, feathered breaks
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
                                Text("First Day of Week")
                                    .font(.manrope(16, .heavy))
                                    .foregroundColor(LCColor.ink)
                                Spacer()
                                HStack(spacing: 8) {
                                    Text(weekStartDay)
                                        .font(.manrope(16, .semibold))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .accentText(.pink)
                            }
                            .padding(.horizontal, 18)
                            .neuGroupedRow()
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("First Day of Week")
                        .accessibilityValue(weekStartDay)


                        NeuFeatheredDivider()

                        Toggle(isOn: $skipReviews) {
                            Text("Skip Reviews This Week?")
                                .font(.manrope(16, .heavy))
                                .foregroundColor(LCColor.ink)
                        }
                        .toggleStyle(NeuToggleStyle())
                        .padding(.horizontal, 18)
                        .neuGroupedRow()
                    }
                    .padding(.horizontal, LCMetrics.screenMargin)
                    .padding(.top, 20)

                    // Section header — HH Samuel, deep pink (7a handoff)
                    Text("Notification Settings")
                        .font(.hhSamuel(23))
                        .textCase(.uppercase)
                        .accentText(.pink)
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                        .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 17, weight: .medium))
                                .accentText(.blue)
                            Text("Notification Time")
                                .font(.manrope(16, .heavy))
                                .foregroundColor(LCColor.ink)
                            Spacer()
                            // Pink time value painted OVER the real DatePicker, so
                            // its grey capsule is hidden but every touch still
                            // reaches it. Do not flip this back to a
                            // near-transparent picker on top: UIKit skips
                            // hit-testing at alpha <= 0.01, which looked fine and
                            // silently ate every tap.
                            DatePicker(selection: $notificationTime, displayedComponents: .hourAndMinute) {
                                Text("Notification Time")
                            }
                            .labelsHidden()
                            .overlay {
                                Text(formatTime(notificationTime))
                                    .font(.manrope(16, .semibold))
                                    .accentText(.pink)
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
                            HStack(spacing: 12) {
                                Image(systemName: "bell")
                                    .font(.system(size: 17, weight: .medium))
                                    .accentText(.pink)
                                Text("Daily Notifications")
                                    .font(.manrope(16, .heavy))
                                    .foregroundColor(LCColor.ink)
                            }
                        }
                        .toggleStyle(NeuToggleStyle())
                        .padding(.horizontal, 18)
                        .neuGroupedRow()

                        NeuFeatheredDivider()

                        Toggle(isOn: $weeklyNotifications) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 17, weight: .medium))
                                    .accentText(.blue)
                                Text("Weekly Notifications")
                                    .font(.manrope(16, .heavy))
                                    .foregroundColor(LCColor.ink)
                            }
                        }
                        .toggleStyle(NeuToggleStyle())
                        .padding(.horizontal, 18)
                        .neuGroupedRow()
                    }
                    .padding(.horizontal, LCMetrics.screenMargin)

                    Button {
                        HapticFeedback.impact()
                        saveSettings()
                    } label: {
                        Text("Save & Continue")
                    }
                    .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink,
                                                       fill: LCColor.yellow,
                                                       verticalPadding: 17,
                                                       font: .manrope(18, .heavy)))
                    .padding(.horizontal, LCMetrics.screenMargin)
                    .padding(.top, 26)
                    .padding(.bottom, 30)
                }
            }
            .background(LCColor.surface.ignoresSafeArea())
            .onAppear {
                // Load existing settings if any
                if let firstSettings = storedSettingss.first {
                    storedSettings = Color(red: firstSettings.red, green: firstSettings.green, blue: firstSettings.blue, opacity: firstSettings.opacity)
                    textColor = Color(red: firstSettings.textColorRed, green: firstSettings.textColorGreen, blue: firstSettings.textColorBlue, opacity: firstSettings.textColorOpacity)
                    weekStartDay = firstSettings.week_start_day
                    skipReviews = firstSettings.skip_reviews

                    // Load notification settings
                    if let notifTime = firstSettings.notification_time, let time = parseTimeString(notifTime) {
                        notificationTime = time
                    }
                    dailyNotifications = firstSettings.daily_notifications
                    weeklyNotifications = firstSettings.weekly_notifications
                } else {
                    // If no settings exist, use pink as default
                    storedSettings = .pink
                    textColor = .black
                }
            }
        }
        .tint(LCColor.pink)
    }

    private func saveSettings() {
        let components = storedSettings.getComponents()
        let textColorComponents = textColor.getComponents()

        if let existingSettings = storedSettingss.first {
            // Update existing settings
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
            // following week apart and turn reviews back on.
            if skipReviews && !existingSettings.skip_reviews {
                existingSettings.skip_reviews_last_reset_date = DateProviderService.shared.now().timeIntervalSince1970
            }
            existingSettings.skip_reviews = skipReviews

            // Update notification settings
            existingSettings.notification_time = formatTime(notificationTime)
            existingSettings.daily_notifications = dailyNotifications
            existingSettings.weekly_notifications = weeklyNotifications
            try? modelContext.save()
        } else {
            // Create new settings
            let newstoredSettings = MainSettings(
                red: components.red,
                green: components.green,
                blue: components.blue,
                opacity: components.opacity,
                week_start_day: weekStartDay,
                skip_reviews: skipReviews,
                skip_reviews_last_reset_date: skipReviews ? DateProviderService.shared.now().timeIntervalSince1970 : 0,
                textColorRed: textColorComponents.red,
                textColorGreen: textColorComponents.green,
                textColorBlue: textColorComponents.blue,
                textColorOpacity: textColorComponents.opacity,
                notification_time: formatTime(notificationTime),
                daily_notifications: dailyNotifications,
                weekly_notifications: weeklyNotifications
            )
            modelContext.insert(newstoredSettings)
            try? modelContext.save()
        }

        // Schedule notifications
        NotificationManager.shared.scheduleDailyNotification(time: notificationTime, enabled: dailyNotifications)
        NotificationManager.shared.scheduleWeeklyNotification(enabled: weeklyNotifications, weekStartDay: weekStartDay)
        // Always schedule planning unlocked notification (it's a core feature notification)
        NotificationManager.shared.schedulePlanningUnlockedNotification(enabled: true, weekStartDay: weekStartDay)
        if weeklyNotifications {
            NotificationManager.shared.calculateAndUpdateWeeklyNotification(weekStartDay: weekStartDay)
        }

        // Mark onboarding as complete (PER USER — the old global key made new
        // accounts on a used device skip onboarding) and call onSave callback.
        // The legacy global is also stamped so a downgade/older build never
        // re-onboards this device.
        if let uid = Auth.auth().currentUser?.uid, !uid.isEmpty {
            UserDefaults.standard.set(true, forKey: OnboardingGate.completedSettingsKey(uid: uid))
            UserDefaults.standard.set(true, forKey: OnboardingGate.seenHelpKey(uid: uid))
        }
        UserDefaults.standard.set(true, forKey: OnboardingGate.legacyCompletedSettingsKey)
        onSave?()
    }

    private func parseTimeString(_ timeString: String) -> Date? {
        onboardingTimeFormatter.date(from: timeString)
    }

    private func formatTime(_ date: Date) -> String {
        onboardingTimeFormatter.string(from: date)
    }
}

#Preview {
    OnboardingSettingsView()
        .modelContainer(for: [MainSettings.self], inMemory: true)
}

