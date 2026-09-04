//
//  TopIdealsHistorySection.swift
//  The Ideal Week
//
//  Self-contained "Your Top Ideals" history browser: a date-range filter, a
//  per-category tab bar, and the list of historical ideals for the selected
//  category. Extracted from HistoryProgressView so it can live at the bottom of
//  the Profile page. Owns its own Firestore query, settings query, and detail
//  sheet so the host view needs only to supply the user id.
//

import SwiftUI

struct TopIdealsHistorySection: View {
    /// Provided by the host (ProfileView already owns a live @FirestoreQuery on
    /// the same collection — reusing it avoids a second snapshot listener).
    let allIdeals: [Ideal]
    let accentColor: Color
    let weekStartDay: String

    @State private var selectedCategory: Category = Category.allCases.first ?? .fix
    /// Shared date filter driving BOTH the radar overlays and the card list/badges.
    /// nil = all time (the default).
    @State private var dateRange: ClosedRange<Date>? = nil
    @State private var lastWeekActive = false
    @State private var showDatePicker = false
    @State private var itemToView: Ideal = Ideal(id: "", title: "")
    @State private var showingDetailView = false

    private func target(_ item: Ideal) -> Int {
        item.targetCount == "6+" ? 6 : (Int(item.targetCount) ?? 0)
    }

    private func isFullyCompleted(_ item: Ideal) -> Bool {
        let t = target(item)
        return t > 0 && item.doneCount >= t
    }

    /// Shared range predicate used by BOTH the radar and the card list. nil range = all time.
    private func inRange(_ item: Ideal) -> Bool {
        guard item.startDate > 0 else { return false }
        guard let range = dateRange else { return true }
        let lower = range.lowerBound.startOfDay.timeIntervalSince1970
        let upper = range.upperBound.endOfDay.timeIntervalSince1970
        return item.startDate >= lower && item.startDate <= upper
    }

    private func catItems(_ cat: Category) -> [Ideal] {
        let filtered = allIdeals.filter { $0.category == cat.rawValue && inRange($0) }
        // Fully-completed ideals first, then the rest by action count (doneCount) desc.
        return filtered.sorted { a, b in
            let aDone = isFullyCompleted(a)
            let bDone = isFullyCompleted(b)
            if aDone != bDone { return aDone && !bDone }
            return a.doneCount > b.doneCount
        }
    }

    /// All 7 category axes, computed over the date-filtered ideals (independent of the
    /// selected category tab — the radar is driven by the date filter only).
    private var radarAxes: [RadarAxis] {
        CategoryRadarMetrics.axisData(ideals: allIdeals.filter(inRange), categories: Category.allCases)
    }

    private var dateFilterLabel: String {
        if lastWeekActive { return "Last week" }
        guard let range = dateRange else { return "All time" }
        return "\(range.lowerBound.formatted(date: .abbreviated, time: .omitted)) - \(range.upperBound.formatted(date: .abbreviated, time: .omitted))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Your Top Ideals")
                .font(.hhSamuel(26))
                .foregroundColor(LCColor.deepPink)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 8)

            // Legend sits under the title, not under the chart (client, 2026-08-28).
            CategoryRadarChart(axes: radarAxes).legend
                .padding(.bottom, 10)

            CategoryRadarChart(axes: radarAxes, showsLegend: false)
                .frame(maxWidth: 360)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            dateRangeFilter

            categoryTabBar
                .padding(.top, 16)

            // Selected category's name — under the tabs, right above its data.
            Text(selectedCategory.rawValue)
                .font(.hhSamuel(20))
                .textCase(.uppercase)
                .foregroundColor(LCColor.deepPink)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .animation(nil, value: selectedCategory)

            categoryContent
        }
        .background(LCColor.surface)
        .sheet(isPresented: $showingDetailView, onDismiss: { showingDetailView = false }) {
            IdealHistoryDetailView(item: itemToView, detailViewPresented: $showingDetailView)
        }
    }

    private var dateRangeFilter: some View {
        Button(action: { showDatePicker = true }) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(LCColor.pink)
                Text(dateFilterLabel)
                    .font(.manrope(15, .bold))
                    .foregroundColor(LCColor.ink)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(LCColor.textSecondary)
                    .font(.system(size: 13, weight: .bold))
            }
            .padding(.horizontal, 18)
            .frame(minHeight: LCMetrics.rowHeight)
            .neuSunken(cornerRadius: LCRadius.field)
            .contentShape(Rectangle())
            .padding(.horizontal, LCMetrics.screenMargin)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDatePicker) {
            DateRangeCalendarView(
                range: $dateRange,
                lastWeekActive: $lastWeekActive,
                weekStartDay: weekStartDay,
                accentColor: accentColor
            )
        }
    }

    private var categoryTabBar: some View {
        // Category filter chips — selected = raised pink, unselected = sunken.
        // Each chip takes an equal share of the row (maxWidth: .infinity) so all
        // seven fit the screen width on every device (client, 2026-09-02).
        // Fixed 16pt side padding + 14pt gaps previously summed to ~462pt on a
        // 402pt screen, which is why this used to need a horizontal scroll.
        HStack(spacing: 6) {
            ForEach(Category.allCases, id: \.id) { cat in
                let isSelected = selectedCategory == cat
                Button {
                    HapticFeedback.selection()
                    withAnimation { selectedCategory = cat }
                } label: {
                    // Icon-only chip (client, 2026-08-28) — the selected
                    // category's name renders once, under the tab bar. LC v2
                    // icon set as before, template-tinted.
                    Image(cat.lcCategoryIconV2())
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    .foregroundColor(isSelected ? LCColor.contrastingInk(on: LCColor.pink) : LCColor.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: LCRadius.chip, style: .continuous)
                                    .fill(LCColor.pinkFill)
                                    .shadow(color: LCColor.shadowDark, radius: 3.5, x: 3, y: 3)
                                    .shadow(color: LCColor.shadowLight, radius: 3.5, x: -3, y: -3)
                            } else {
                                RoundedRectangle(cornerRadius: LCRadius.chip, style: .continuous)
                                    .fill(
                                        LCColor.surface
                                            .shadow(.inner(color: LCColor.shadowDark, radius: 3, x: 3, y: 3))
                                            .shadow(.inner(color: LCColor.shadowLight, radius: 3, x: -3, y: -3))
                                    )
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cat.rawValue)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var categoryContent: some View {
        let filteredItems = catItems(selectedCategory)
        if filteredItems.isEmpty {
            VStack {
                Text("No ideals in this category for the selected date range")
                    .font(.manrope(16, .semibold))
                    .foregroundColor(LCColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .frame(minHeight: 100)
        } else {
            LazyVStack(spacing: 18) {
                ForEach(filteredItems, id: \.id) { item in
                    IdealHistoryItemLabel(
                        item: item,
                        background: accentColor,
                        onTap: {
                            itemToView = item
                            showingDetailView = true
                        }
                    )
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
}

#if DEBUG
#Preview {
    TopIdealsHistorySection(
        allIdeals: PreviewData.lastWeekIdeals,
        accentColor: LCColor.pink,
        weekStartDay: PreviewData.weekStartDay
    )
}
#endif
