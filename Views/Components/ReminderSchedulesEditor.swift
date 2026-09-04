//
//  ReminderSchedulesEditor.swift
//  The Ideal Week
//
//  Reusable editor for an ideal's multiple reminder groups. Each group is a set of weekdays
//  plus its own time. Shared by IdealEditView (full + planned forms) and ScheduleDetailSheetView
//  so the "Add another reminder" UX is identical everywhere a schedule is edited.
//

import SwiftUI

/// The time a reminder fires, wearing the same sunken chip as the day buttons
/// beside it — both are "pick a value" controls, so they read as one row.
///
/// The system DatePicker brings a grey capsule that cannot be restyled, so the
/// chip is painted OVER it as a pass-through overlay: the picker keeps full
/// opacity and every touch, the chip is only what you see.
///
/// Do not "simplify" this by putting a near-transparent picker on top instead —
/// UIKit refuses to hit-test a view whose alpha is at or below 0.01, so that
/// arrangement renders correctly and then silently eats every tap.
struct NeuTimeChip: View {
    @Binding var time: Date
    /// Spoken label for the control; the visible chip is decorative.
    var accessibilityLabel: String

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        DatePicker(selection: $time, displayedComponents: .hourAndMinute) {
            Text(accessibilityLabel)
        }
        .labelsHidden()
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .overlay {
            Text(Self.formatter.string(from: time))
                .font(.manrope(13, .heavy))
                .foregroundColor(LCColor.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .neuSunken(cornerRadius: LCRadius.chip)
                // The picker underneath owns the touch and the accessibility.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .fixedSize()
    }
}

/// Day chip — selected = accent (pink) raised chip, unselected = sunken well
/// (handoff 7l: "day picker = 7 chips, selected = pink fill, unselected sunken").
private struct DayChipButtonStyle: ButtonStyle {
    var isSelected: Bool
    var accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if isSelected {
                configuration.label
                    .background(NeuPressableBackground(
                        shape: RoundedRectangle(cornerRadius: LCRadius.chip, style: .continuous),
                        fill: accentColor,
                        cssOffset: LCNeumorphism.raisedOffsetSmall,
                        cssBlur: LCNeumorphism.raisedBlurSmall,
                        pressed: configuration.isPressed))
            } else {
                configuration.label
                    .neuSunken(cornerRadius: LCRadius.chip)
            }
        }
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ReminderSchedulesEditor: View {
    @ObservedObject var viewModel: IdealEditViewViewModel
    let accentColor: Color
    /// Selectable days for the current week (typically `getRemainingDaysOfWeek(...)`).
    let days: [DayInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(viewModel.schedules.enumerated()), id: \.element.id) { index, schedule in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(viewModel.schedules.count > 1 ? "Reminder \(index + 1)" : "Select Days (Current Week)")
                            .font(.manrope(14, .heavy))
                            .foregroundColor(LCColor.ink)
                        Spacer()
                        if viewModel.schedules.count > 1 {
                            Button {
                                viewModel.removeSchedule(id: schedule.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(LCColor.deepPink)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(days, id: \.weekday) { dayInfo in
                                let isSelected = schedule.days.contains(dayInfo.weekday)
                                Button {
                                    viewModel.toggleDay(dayInfo.weekday, for: schedule.id)
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(dayInfo.abbreviation)
                                            .font(.manrope(13, .heavy))
                                            .textCase(.uppercase)
                                        Text(dayInfo.dayNumber)
                                            .font(.manrope(11, .medium))
                                    }
                                    .foregroundColor(isSelected ? .white : LCColor.ink)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 9)
                                    .frame(minWidth: 44)
                                }
                                .buttonStyle(DayChipButtonStyle(isSelected: isSelected, accentColor: accentColor))
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6) // room for the raised chip shadows
                    }

                    HStack {
                        Text("Reminder Time")
                            .font(.manrope(14, .medium))
                            .foregroundColor(LCColor.ink)
                        Spacer()
                        NeuTimeChip(time: $viewModel.schedules[index].time,
                                    accessibilityLabel: "Reminder Time")
                    }
                }
            }

            Button {
                viewModel.addSchedule()
            } label: {
                Label("Add another reminder", systemImage: "plus.circle")
                    .font(.manrope(15, .heavy))
                    .foregroundColor(accentColor)
            }
            .buttonStyle(.borderless)
        }
    }
}

#if DEBUG
#Preview {
    PreviewData.configureFirebaseIfNeeded()
    return ReminderSchedulesEditor(
        viewModel: IdealEditViewViewModel(),
        accentColor: LCColor.pink,
        days: PreviewData.days
    )
}
#endif
