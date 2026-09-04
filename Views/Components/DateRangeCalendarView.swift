//
//  DateRangeCalendarView.swift
//  The Ideal Week
//
//  Single continuous-range calendar picker that replaces the separate start/end date pickers
//  for "Your Top Ideals". Tap a start day then an end day to select an inclusive span; the
//  highlighted span drives the shared date filter. Includes an "All time" reset and a
//  "Last week" toggle (previous COMPLETE week, honoring the user's start-of-week setting).
//

import SwiftUI

struct DateRangeCalendarView: View {
    /// nil = all time. Stored normalized: lowerBound = startOfDay, upperBound = endOfDay.
    @Binding var range: ClosedRange<Date>?
    @Binding var lastWeekActive: Bool
    let weekStartDay: String
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth: Date
    /// First tap of a new selection (waiting for the end tap).
    @State private var pendingStart: Date? = nil

    private var cal: Calendar { WeekdayUtility.calendar(firstWeekday: weekStartDay) }

    init(range: Binding<ClosedRange<Date>?>, lastWeekActive: Binding<Bool>, weekStartDay: String, accentColor: Color) {
        self._range = range
        self._lastWeekActive = lastWeekActive
        self.weekStartDay = weekStartDay
        self.accentColor = accentColor
        let anchor = range.wrappedValue?.upperBound ?? DateProviderService.shared.now()
        self._displayedMonth = State(initialValue: anchor)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NeuSheetHeader(title: "Select Date Range") { dismiss() }
                VStack(spacing: 16) {
                    quickControls
                    monthHeader
                    weekdayHeader
                    daysGrid
                    Spacer(minLength: 0)
                    selectionSummary
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LCColor.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
    }

    // MARK: - Quick controls (All time / Last week)
    // Chips: selected = raised pink, unselected = sunken (handoff chip rule).

    private var quickControls: some View {
        HStack(spacing: 14) {
            quickChip(label: "All time", selected: range == nil && !lastWeekActive) {
                range = nil
                pendingStart = nil
                lastWeekActive = false
            }

            quickChip(label: "Last week", selected: lastWeekActive) {
                applyLastWeek(!lastWeekActive)
            }

            Spacer()
        }
    }

    private func quickChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if selected {
                    Text(label)
                        .font(.manrope(15, .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .neuRaised(cornerRadius: LCRadius.chip,
                                   fill: LCColor.pink,
                                   cssOffset: LCNeumorphism.raisedOffsetSmall,
                                   cssBlur: LCNeumorphism.raisedBlurSmall)
                } else {
                    Text(label)
                        .font(.manrope(15, .bold))
                        .foregroundColor(LCColor.ink)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .neuSunken(cornerRadius: LCRadius.chip)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func applyLastWeek(_ on: Bool) {
        if on {
            let week = WeekdayUtility.previousWeekRange(weekStartDay: weekStartDay)
            range = week.start.startOfDay...week.end.endOfDay
            pendingStart = nil
            displayedMonth = week.start
            lastWeekActive = true
        } else {
            range = nil
            lastWeekActive = false
        }
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(LCColor.pink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(NeuCircleButtonStyle(diameter: 36))
            Spacer()
            Text(monthTitle)
                .font(.hhSamuel(20))
                .foregroundColor(LCColor.deepPink)
                .textCase(.uppercase)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(LCColor.pink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(NeuCircleButtonStyle(diameter: 36))
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.manrope(12, .semibold))
                    .foregroundColor(LCColor.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Days grid

    private var daysGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 38)
                }
            }
        }
    }

    // Day chips: selected endpoints = raised pink; span = pink-tinted sunken;
    // unselected = sunken surface well (handoff calendar-chip rule).
    private func dayCell(_ day: Date) -> some View {
        let state = selectionState(for: day)
        return Button {
            tapDay(day)
        } label: {
            Text("\(cal.component(.day, from: day))")
                .font(.manrope(15, state.selected ? .heavy : .medium))
                .foregroundColor(state.endpoint ? .white : (state.selected ? LCColor.pink : LCColor.ink))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    Group {
                        if state.endpoint {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LCColor.pink)
                                .shadow(color: LCColor.shadowDark, radius: 3.5, x: 3, y: 3)
                                .shadow(color: LCColor.shadowLight, radius: 3.5, x: -3, y: -3)
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    (state.selected ? LCColor.pink.opacity(0.18) : LCColor.surface)
                                        .shadow(.inner(color: LCColor.shadowDark, radius: 2.5, x: 2.5, y: 2.5))
                                        .shadow(.inner(color: LCColor.shadowLight, radius: 2.5, x: -2.5, y: -2.5))
                                )
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func tapDay(_ day: Date) {
        lastWeekActive = false // manual edit clears the toggle
        let dayStart = cal.startOfDay(for: day)

        if let start = pendingStart {
            if dayStart >= start {
                range = start...day.endOfDay
                pendingStart = nil
            } else {
                pendingStart = dayStart // tapped before start → restart selection
                range = nil
            }
        } else {
            // Begin a fresh selection.
            pendingStart = dayStart
            range = nil
        }
    }

    // MARK: - Selection state

    private struct CellState { let selected: Bool; let endpoint: Bool }

    private func selectionState(for day: Date) -> CellState {
        let dayStart = cal.startOfDay(for: day)
        if let start = pendingStart, range == nil {
            return CellState(selected: dayStart == start, endpoint: dayStart == start)
        }
        guard let range else { return CellState(selected: false, endpoint: false) }
        let lower = cal.startOfDay(for: range.lowerBound)
        let upper = cal.startOfDay(for: range.upperBound)
        let selected = dayStart >= lower && dayStart <= upper
        let endpoint = dayStart == lower || dayStart == upper
        return CellState(selected: selected, endpoint: endpoint)
    }

    private var selectionSummary: some View {
        Group {
            if let range {
                Text("\(range.lowerBound.formatted(date: .abbreviated, time: .omitted)) – \(range.upperBound.formatted(date: .abbreviated, time: .omitted))")
            } else if pendingStart != nil {
                Text("Tap an end date…")
            } else {
                Text("All time")
            }
        }
        .font(.manrope(15, .semibold))
        .foregroundColor(LCColor.textSecondary)
    }

    // MARK: - Calendar math

    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = d
        }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.calendar = cal
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    /// Weekday symbols rotated to the user's start-of-week.
    private var orderedWeekdaySymbols: [String] {
        let base = WeekdayUtility.dayAbbreviations // index 0 = Sun
        let first = cal.firstWeekday - 1 // 0-based
        return (0..<7).map { base[(first + $0) % 7] }
    }

    /// Cells for the displayed month: leading nils for the offset, then each day.
    private var monthCells: [Date?] {
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)),
              let dayRange = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = cal.component(.weekday, from: monthStart) // 1…7
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayRange.count {
            if let day = cal.date(byAdding: .day, value: offset, to: monthStart) {
                cells.append(day)
            }
        }
        return cells
    }
}

#if DEBUG
#Preview {
    @Previewable @State var range: ClosedRange<Date>? = nil
    @Previewable @State var active = false
    DateRangeCalendarView(
        range: $range,
        lastWeekActive: $active,
        weekStartDay: PreviewData.weekStartDay,
        accentColor: LCColor.pink
    )
}
#endif
