//
//  IdealEditView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//

import SwiftUI
import SwiftData

struct IdealEditView: View {
    let item: Ideal
    @StateObject private var viewModel: IdealEditViewViewModel
    @Binding var editItemPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @Query var storedTempSettings: [MainSettings]
    @State private var showRemoveCompletionAlert = false
    @State private var isButtonPressed = false

    var textColor: Color {
        if let firstSettings = storedTempSettings.first {
            return Color(red: firstSettings.textColorRed, green: firstSettings.textColorGreen, blue: firstSettings.textColorBlue, opacity: firstSettings.textColorOpacity)
        } else {
            return Color.black
        }
    }

    var accentColor: Color {
        // Follows the palette chosen in Settings (LCPalette).
        LCColor.pink
    }

    // Get remaining days of current week
    func getRemainingDaysOfWeek(weekStartDay: String) -> [DayInfo] {
        let calendar = Calendar.current
        // Honour the virtual-date override (Settings → manual date) so this
        // picker matches the rest of the app's notion of "now".
        let now = DateProviderService.shared.now()
        let today = calendar.startOfDay(for: now)
        let userCalendar = WeekdayUtility.calendar(firstWeekday: weekStartDay)

        // Get start of current week
        let weekStart = userCalendar.date(from: userCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let weekStartDayStart = calendar.startOfDay(for: weekStart)

        // Calculate end of week (6 days after start, which is the 7th day)
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStartDayStart) else { return [] }
        let weekEndDayStart = calendar.startOfDay(for: weekEnd)

        // Day abbreviations
        let dayAbbreviations = WeekdayUtility.dayAbbreviations

        var days: [DayInfo] = []

        // Iterate from today to end of current week
        var currentDate = today
        while currentDate <= weekEndDayStart {
            let weekday = calendar.component(.weekday, from: currentDate)
            let dayOfMonth = calendar.component(.day, from: currentDate)

            days.append(DayInfo(
                weekday: weekday,
                abbreviation: dayAbbreviations[weekday - 1],
                dayNumber: "\(dayOfMonth)"
            ))

            // Move to next day
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = calendar.startOfDay(for: nextDate)
        }

        return days
    }

    // All week days (Sun–Sat) for read-only schedule display when scheduleLocked
    func getAllWeekDays() -> [DayInfo] {
        let dayAbbreviations = WeekdayUtility.dayAbbreviations
        return (1...7).map { weekday in
            DayInfo(weekday: weekday, abbreviation: dayAbbreviations[weekday - 1], dayNumber: "")
        }
    }

    init(item: Ideal) {
        self.item = item
        _viewModel = StateObject(wrappedValue: IdealEditViewViewModel(ideal: item))
        _editItemPresented = .constant(true)
    }

    init(item: Ideal, editItemPresented: Binding<Bool>, scheduleLocked: Bool = false, plannedItemMode: Bool = false) {
        self.item = item
        _viewModel = StateObject(wrappedValue: IdealEditViewViewModel(ideal: item))
        _editItemPresented = editItemPresented
        self.scheduleLocked = scheduleLocked
        self.plannedItemMode = plannedItemMode
    }

    /// When true (e.g. last week's progress), schedule/reminder section is read-only and shown in gray.
    var scheduleLocked: Bool = false
    /// When true (Next? planned items), only show title, category, how often, and schedule toggle. Schedule defaults off; when toggled on, pre-fill from ideal if it had reminders.
    var plannedItemMode: Bool = false

    private var shouldDefaultPlannedScheduleOff: Bool {
        plannedItemMode && (item.sourceIdealId != nil || item.plannedFromWishlistAt > 0)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    // MARK: - Neumorphic building blocks (1j design)

    /// Section header — HH Samuel at ~75% of category-title size.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.hhSamuel(23))
            .textCase(.uppercase)
            .accentText(.pink)
            .padding(.leading, LCMetrics.screenMargin)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    /// Grouped row: Manrope 800/16 label + pink value.
    private func valueRow(_ label: String, value: String, valueSize: CGFloat = 17) -> some View {
        HStack {
            Text(label)
                .font(.manrope(16, .heavy))
                .foregroundColor(LCColor.ink)
            Spacer()
            Text(value)
                .font(.manrope(valueSize, .bold))
                .accentText(.pink)
        }
        .neuGroupedRow()
    }

    /// Planned-item edit: title, category, how often, schedule toggle (default off). When toggle on, show days + time; if ideal had reminders they are pre-filled.
    private var plannedItemForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Ideal Information")
                VStack(alignment: .leading, spacing: 0) {
                    VoiceTitleField(
                        text: $viewModel.title,
                        placeholder: "Title",
                        accentColor: LCColor.pink
                    )
                    .padding(.vertical, 14)

                    NeuFeatheredDivider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.manrope(16, .heavy))
                            .foregroundColor(LCColor.ink)
                        CategoryWellPicker(selection: $viewModel.category)
                    }
                    .padding(.vertical, 14)
                }
                .padding(.horizontal, LCMetrics.screenMargin)

                sectionHeader("How Often?")
                Text(viewModel.targetCount)
                    .font(.manrope(18, .bold))
                    .foregroundColor(LCColor.ink)
                    .padding(.horizontal, LCMetrics.screenMargin)

                sectionHeader("Schedule")
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
                        let weekStartDay = storedTempSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
                        ReminderSchedulesEditor(
                            viewModel: viewModel,
                            accentColor: LCColor.pink,
                            days: getRemainingDaysOfWeek(weekStartDay: weekStartDay)
                        )
                        .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, LCMetrics.screenMargin)
            }
            .padding(.bottom, 30)
        }
    }

    private var fullEditForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Ideal Information")
                VStack(alignment: .leading, spacing: 0) {
                    if let cat = Category(rawValue: viewModel.category) {
                        Text(cat.subheading)
                            .font(.idealTitle(20))
                            .foregroundColor(LCColor.ink)
                            .imprinted()
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 16)
                            .padding(.bottom, 12)

                        NeuFeatheredDivider()
                    }
                    VoiceTitleField(
                        text: $viewModel.title,
                        placeholder: "Title",
                        accentColor: LCColor.pink
                    )
                    .padding(.vertical, 14)

                    NeuFeatheredDivider()

                    HStack {
                        Text("Category")
                            .font(.manrope(16, .heavy))
                            .foregroundColor(LCColor.ink)
                        Spacer()
                        Text(viewModel.category)
                            .font(.manrope(16, .semibold))
                            .accentText(.pink)
                    }
                    .neuGroupedRow()
                }
                .padding(.horizontal, LCMetrics.screenMargin)

                sectionHeader("Progress")
                VStack(alignment: .leading, spacing: 0) {
                    valueRow("How Often?", value: viewModel.targetCount, valueSize: 18)
                    NeuFeatheredDivider()
                    valueRow("Total Completed", value: "\(viewModel.doneCount)")
                    NeuFeatheredDivider()
                    Button {
                        HapticFeedback.impact()
                        if viewModel.doneCount <= 0 { showRemoveCompletionAlert = true }
                        else { viewModel.doneCount = max(0, viewModel.doneCount - 1) }
                    } label: {
                        Text("Remove A Completion")
                    }
                    .buttonStyle(NeumorphicButtonStyle(tint: LCColor.pink, font: .manrope(17, .heavy)))
                    .padding(.vertical, 14)
                }
                .padding(.horizontal, LCMetrics.screenMargin)

                sectionHeader("Ideal Reminder")
                VStack(alignment: .leading, spacing: 0) {
                    Toggle(isOn: $viewModel.setReminder) {
                        Text("Schedule a Reminder?")
                            .font(.manrope(16, .heavy))
                            .foregroundColor(LCColor.ink)
                    }
                    .toggleStyle(NeuToggleStyle())
                    .neuGroupedRow()
                    .disabled(scheduleLocked)
                    .onChange(of: viewModel.setReminder) { _, _ in
                        if !scheduleLocked { viewModel.ensureAtLeastOneSchedule() }
                    }
                    if viewModel.setReminder {
                        NeuFeatheredDivider()
                        if scheduleLocked {
                            lockedScheduleView
                                .padding(.vertical, 14)
                        } else {
                            let weekStartDay = storedTempSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
                            ReminderSchedulesEditor(
                                viewModel: viewModel,
                                accentColor: LCColor.pink,
                                days: getRemainingDaysOfWeek(weekStartDay: weekStartDay)
                            )
                            .padding(.vertical, 14)
                        }
                    }
                }
                .padding(.horizontal, LCMetrics.screenMargin)

                sectionHeader("Additional Information")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.manrope(16, .heavy))
                        .foregroundColor(LCColor.ink)
                    TextField("", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...9)
                        .textFieldStyle(NeumorphicTextFieldStyle())
                }
                .padding(.horizontal, LCMetrics.screenMargin)
            }
            .padding(.bottom, 30)
        }
    }

    /// Read-only schedule display for last week's progress (scheduleLocked). Shows every
    /// reminder group's days (grayed) and time.
    private var lockedScheduleView: some View {
        let allDays = getAllWeekDays()
        return VStack(alignment: .leading, spacing: 16) {
            Text("Scheduled Days (last week – not editable)")
                .font(.manrope(14, .semibold))
                .foregroundColor(LCColor.textSecondary)
            ForEach(Array(viewModel.schedules.enumerated()), id: \.element.id) { index, schedule in
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.schedules.count > 1 {
                        Text("Reminder \(index + 1)")
                            .font(.manrope(13, .heavy))
                            .foregroundColor(LCColor.textSecondary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(allDays, id: \.weekday) { dayInfo in
                                let isSelected = schedule.days.contains(dayInfo.weekday)
                                VStack(spacing: 4) {
                                    Text(dayInfo.abbreviation)
                                        .font(.manrope(13, .heavy))
                                        .textCase(.uppercase)
                                }
                                .foregroundColor(isSelected ? LCColor.pink : LCColor.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .neuSunken(cornerRadius: LCRadius.chip)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    Text("Reminder Time: \(schedule.time, formatter: Self.timeFormatter)")
                        .font(.manrope(13, .semibold))
                        .foregroundColor(LCColor.textSecondary)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Neumorphic header (close · EDIT IDEAL · save-check), replaces the nav bar
    private var header: some View {
        ZStack {
            Text("Edit Ideal")
                .font(.hhSamuel(40))
                .textCase(.uppercase)
                .accentText(.pink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 56)
            HStack {
                NeuCloseButton {
                    editItemPresented = false
                }
                Spacer()
                NeuCheckSaveButton(diameter: 40) {
                    let trimmedTitle = viewModel.title.trimmingCharacters(in: .whitespaces)

                    // Validate title
                    guard !trimmedTitle.isEmpty else {
                        viewModel.alertMessage = "Please enter a title for the ideal."
                        viewModel.showAlert = true
                        return
                    }

                    // If no group has any day selected, automatically turn off the reminder toggle
                    if viewModel.setReminder && !viewModel.schedules.contains(where: { !$0.days.isEmpty }) {
                        viewModel.setReminder = false
                    }

                    // All validations passed, proceed with save
                    viewModel.reminderError = nil
                    let weekStartDay = storedTempSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
                    viewModel.save(weekStartDay: weekStartDay) { success in
                        if success {
                            editItemPresented = false
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

            if plannedItemMode {
                plannedItemForm
            } else {
                fullEditForm
            }
        }
        .background(LCColor.surface.ignoresSafeArea())
        .onAppear {
            viewModel.configurePlannedItemPresentation(defaultScheduleOff: shouldDefaultPlannedScheduleOff)
        }
        .alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK") {
                viewModel.showAlert = false
            }
        } message: {
            Text(viewModel.alertMessage)
        }
        .interactiveDismissDisabled(viewModel.showAlert)
        .alert("Cannot Remove Completion", isPresented: $showRemoveCompletionAlert) {
            Button("OK") {
                showRemoveCompletionAlert = false
            }
        } message: {
            Text("Total completed count must be zero or greater.")
        }
    }
}

#Preview {
    IdealEditView(item: .init(
            id: "123",
            category: "Fix",
            title: "Get Milk",
            notes: "",
            scheduleDateTime: Date().timeIntervalSince1970,
            createdDate: Date().timeIntervalSince1970,
            targetCount: "3",
            doneCount: 0,
            active: true
        )
    )
}
