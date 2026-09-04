//
//  PlannedReminderGroupsEditor.swift
//  The Ideal Week
//
//  Reusable multi-group reminder editor for the Planning sheet (planned items, wishlist
//  items, and new-ideal drafts). Mirrors ReminderSchedulesEditor but is driven by plain
//  closures so each caller can route mutations to its own view-model keys.
//
//  Neumorphic restyle: day chips are sunken wells that pop out raised & pink when
//  selected; text is Manrope; accents map to the LC palette.
//

import SwiftUI

struct PlannedReminderGroupsEditor: View {
    let groups: [PlannedReminderGroup]
    let accentColor: Color
    let days: [DayInfo]
    /// Header shown above the first/only group (e.g. "Select Days (Current Week)").
    let dayTitle: String
    let onToggleDay: (_ groupIndex: Int, _ weekday: Int) -> Void
    let onSetTime: (_ groupIndex: Int, _ time: Date) -> Void
    let onAddGroup: () -> Void
    let onRemoveGroup: (_ groupIndex: Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(groups.count > 1 ? "Reminder \(index + 1)" : dayTitle)
                            .font(.manrope(14, .semibold))
                            .foregroundColor(LCColor.textSecondary)
                        Spacer()
                        if groups.count > 1 {
                            Button {
                                onRemoveGroup(index)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(LCColor.pink)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove reminder \(index + 1)")
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(days, id: \.weekday) { dayInfo in
                                let isSelected = group.days.contains(dayInfo.weekday)
                                Button {
                                    HapticFeedback.impact()
                                    onToggleDay(index, dayInfo.weekday)
                                } label: {
                                    dayChip(dayInfo: dayInfo, isSelected: isSelected)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(dayInfo.abbreviation) \(dayInfo.dayNumber)")
                                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8) // room for the raised chip shadows
                    }

                    AutoClosingTimePicker(
                        label: "Reminder Time",
                        selection: Binding(
                            get: { group.time },
                            set: { onSetTime(index, $0) }
                        )
                    )
                }
            }

            Button {
                onAddGroup()
            } label: {
                Label("Add another reminder", systemImage: "plus.circle")
                    .font(.manrope(13, .heavy))
                    .foregroundColor(LCColor.pink)
            }
            .buttonStyle(.borderless)
        }
    }

    /// Day chip — selected = raised pink (pressed-out), unselected = sunken well.
    @ViewBuilder
    private func dayChip(dayInfo: DayInfo, isSelected: Bool) -> some View {
        let content = VStack(spacing: 3) {
            Text(dayInfo.abbreviation)
                .font(.manrope(12, .heavy))
            Text(dayInfo.dayNumber)
                .font(.manrope(10, .medium))
        }
        .foregroundColor(isSelected ? .white : LCColor.textSecondary)
        .frame(minWidth: 40)
        .padding(.vertical, 7)
        .padding(.horizontal, 4)

        if isSelected {
            content.neuRaised(cornerRadius: LCRadius.chip, fill: LCColor.pink,
                              cssOffset: LCNeumorphism.raisedOffsetSmall,
                              cssBlur: LCNeumorphism.raisedBlurSmall)
        } else {
            content.neuSunken(cornerRadius: LCRadius.chip)
        }
    }
}

#if DEBUG
#Preview {
    PlannedReminderGroupsEditor(
        groups: PreviewData.plannedGroups,
        accentColor: LCColor.pink,
        days: PreviewData.days,
        dayTitle: "Select Days (Current Week)",
        onToggleDay: { _, _ in },
        onSetTime: { _, _ in },
        onAddGroup: { },
        onRemoveGroup: { _ in }
    )
    .padding()
    .background(LCColor.surface)
}
#endif
