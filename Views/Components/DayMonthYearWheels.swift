//
//  DayMonthYearWheels.swift
//  The Ideal Week
//
//  Three wheel pickers — day, month, year — used for the birthday field
//  instead of the system calendar popover (client, 2026-09-02).
//
//  The wheels are deliberately unconstrained while spinning: every day 1...31
//  stays selectable whatever the month, because rows appearing and disappearing
//  under a moving finger reads as a broken control. The selection is resolved
//  on change by `DateWheelLogic` — 31 April becomes 30 April, and anything past
//  the age ceiling snaps back to it.
//

import SwiftUI

struct DayMonthYearWheels: View {
    @Binding var date: Date
    /// Latest allowed date (the "must be at least 16" boundary).
    let maximumDate: Date

    private let calendar = Calendar.current

    @State private var day = 1
    @State private var month = 1
    @State private var year = 2000
    /// Suppresses the write-back while we are seeding the wheels from `date`.
    @State private var isSyncing = false

    private var years: [Int] { DateWheelLogic.selectableYears(notAfter: maximumDate, calendar: calendar) }
    private var lastEligibleYear: Int { calendar.component(.year, from: maximumDate) }

    private func isEligible(_ year: Int) -> Bool {
        DateWheelLogic.isEligible(year: year, notAfter: maximumDate, calendar: calendar)
    }
    private var monthSymbols: [String] { calendar.shortMonthSymbols }

    var body: some View {
        HStack(spacing: 0) {
            wheel(selection: $day) {
                ForEach(1...31, id: \.self) { d in
                    Text("\(d)")
                        .font(.manrope(19, .semibold))
                        .foregroundColor(LCColor.ink)
                        .tag(d)
                }
            }
            wheel(selection: $month) {
                ForEach(1...12, id: \.self) { m in
                    Text(monthSymbols[m - 1])
                        .font(.manrope(19, .semibold))
                        .foregroundColor(LCColor.ink)
                        .tag(m)
                }
            }
            wheel(selection: $year) {
                ForEach(years, id: \.self) { y in
                    // Years that would make the user under the minimum age are
                    // shown greyed rather than hidden, so the wheel visibly
                    // "stops" for a reason. Landing on one snaps back.
                    Text(String(y))
                        .font(.manrope(19, .semibold))
                        .foregroundColor(isEligible(y) ? LCColor.ink : LCColor.textMuted)
                        .tag(y)
                }
            }
        }
        .frame(height: 150)
        .onAppear(perform: syncFromDate)
        .onChange(of: date) { _, _ in syncFromDate() }
        .onChange(of: day) { _, _ in writeBack() }
        .onChange(of: month) { _, _ in writeBack() }
        .onChange(of: year) { _, _ in writeBack() }
    }

    /// One wheel column. `.clipped()` keeps the three from overlapping labels,
    /// and `.compositingGroup()` stops the clip from fighting the wheel's own
    /// 3D rotation.
    private func wheel<Content: View>(selection: Binding<Int>,
                                      @ViewBuilder content: () -> Content) -> some View {
        Picker("", selection: selection, content: content)
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .compositingGroup()
            .clipped()
    }

    private func syncFromDate() {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        isSyncing = true
        day = c.day ?? 1
        month = c.month ?? 1
        year = c.year ?? years.last ?? 2000
        isSyncing = false
    }

    private func writeBack() {
        guard !isSyncing else { return }
        // A greyed year cannot be committed: bounce the wheel back to the last
        // eligible one. Done here rather than by removing the rows so the user
        // sees the boundary instead of an unexplained end-stop.
        if !isEligible(year) {
            let snapped = lastEligibleYear
            year = snapped                       // re-enters writeBack with a valid year
            return
        }
        let resolved = DateWheelLogic.resolve(day: day, month: month, year: year,
                                              notAfter: maximumDate, calendar: calendar)
        if resolved != date { date = resolved }
    }
}

#if DEBUG
#Preview {
    VStack {
        DayMonthYearWheels(
            date: .constant(Calendar.current.date(from: DateComponents(year: 1990, month: 7, day: 3))!),
            maximumDate: DateWheelLogic.minimumAgeCeiling()
        )
    }
    .padding()
    .background(LCColor.surface)
}
#endif
