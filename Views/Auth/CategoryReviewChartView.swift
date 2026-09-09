//
//  CategoryReviewChartView.swift
//  The Ideal Week
//
//  Created for displaying category review score charts
//

import SwiftUI
import Charts
import FirebaseFirestore

private let sharedDb = Firestore.firestore()
import FirebaseAuth

@available(iOS 17.6, *)
struct CategoryReviewChartView: View {
    let category: Category
    var allIdeals: [Ideal]
    let accentColor: Color
    let textColor: Color
    let weekStartDay: String
    var dateRange: (start: TimeInterval, end: TimeInterval)? = nil // Optional date range for filtering (if provided, shows only that range and hides filters)
    
    // Shared spacing constant for both chart modes
    private static let dataPointSpacing: CGFloat = 60.0 // 60px spacing between dates (40% reduction from 100px)
    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    private static let weekAxisFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()
    
    @State private var selectedFilter: TimeFilter = .all
    @State private var isDataReady: Bool = false
    @State private var reviewScores: [String: [ReviewScore]] = [:] // idealId -> [ReviewScore]
    @FirestoreQuery var fetchedIdeals: [Ideal]
    @Environment(\.dismiss) private var dismiss
    
    // Use fetchedIdeals if available, otherwise fall back to allIdeals parameter
    private var effectiveIdeals: [Ideal] {
        let ideals = fetchedIdeals.isEmpty ? allIdeals : fetchedIdeals
        return ideals
    }
    
    init(category: Category, allIdeals: [Ideal], accentColor: Color, textColor: Color, weekStartDay: String, dateRange: (start: TimeInterval, end: TimeInterval)? = nil) {
        self.category = category
        self.allIdeals = allIdeals
        self.accentColor = accentColor
        self.textColor = textColor
        self.weekStartDay = weekStartDay
        self.dateRange = dateRange
        
        // Initialize FirestoreQuery to fetch ALL ideals (active and inactive)
        if let userId = Auth.auth().currentUser?.uid {
            self._fetchedIdeals = FirestoreQuery(
                collectionPath: "users/\(userId)/ideals",
                predicates: [
                    .order(by: "createdDate")
                ]
            )
        } else {
            self._fetchedIdeals = FirestoreQuery(
                collectionPath: "",
                predicates: []
            )
        }
    }
    
    enum TimeFilter: String, CaseIterable {
        case all = "All"
        case oneMonth = "1 Month"
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case oneYear = "1 Year"
    }
    
    // Get ideals for this category, sorted from latest to oldest (by createdDate)
    // If dateRange is provided, filter ideals by startDate within that range
    private var categoryIdeals: [Ideal] {
        guard !effectiveIdeals.isEmpty else { return [] }
        var filtered = effectiveIdeals.filter { $0.category == category.rawValue }
        
        // If dateRange is provided, filter by startDate
        if let dateRange = dateRange {
            filtered = filtered.filter { ideal in
                ideal.startDate >= dateRange.start && ideal.startDate <= dateRange.end
            }
        }
        
        return filtered.sorted { ($0.createdDate > 0 ? $0.createdDate : 0) > ($1.createdDate > 0 ? $1.createdDate : 0) }
    }
    
    // Helper to get week start day as integer
    private var weekStartDayInt: Int {
        switch weekStartDay {
        case "Sunday": return 1
        case "Monday": return 2
        case "Tuesday": return 3
        case "Wednesday": return 4
        case "Thursday": return 5
        case "Friday": return 6
        case "Saturday": return 7
        default: return 2 // Default to Monday
        }
    }
    
    // Get start of week for a given date
    private func startOfWeek(for date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartDayInt
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    // Get end of week for a given date
    private func endOfWeek(for date: Date) -> Date {
        let start = startOfWeek(for: date)
        return Calendar.current.date(byAdding: .day, value: 6, to: start) ?? date
    }
    
    /// Which empty state, if any, this screen should show. See
    /// `CategoryChartEmptyState` — the old inline condition suppressed the
    /// message for a category with no ideals and left the screen blank.
    private var emptyState: CategoryChartEmptyState {
        CategoryChartEmptyState.resolve(isDataReady: isDataReady,
                                        weeklyAverageCount: weeklyCategoryAverages.count,
                                        categoryIdealCount: categoryIdeals.count)
    }

    // Calculate weekly category averages
    private var weeklyCategoryAverages: [WeeklyCategoryData] {
        // Get all review scores for all ideals in this category
        var allScores: [ReviewScore] = []
        for ideal in categoryIdeals {
            allScores.append(contentsOf: filteredReviewScores(for: ideal.id))
        }
        
        guard !allScores.isEmpty else { return [] }
        
        // Group scores by week
        var weekGroups: [Date: [ReviewScore]] = [:]
        for score in allScores {
            let scoreDate = Date(timeIntervalSince1970: score.date)
            let weekStart = startOfWeek(for: scoreDate)
            if weekGroups[weekStart] == nil {
                weekGroups[weekStart] = []
            }
            weekGroups[weekStart]?.append(score)
        }
        
        // Calculate average for each week
        let sortedWeeks = weekGroups.keys.sorted()
        return sortedWeeks.enumerated().map { index, weekStart in
            let weekEnd = endOfWeek(for: weekStart)
            let scores = weekGroups[weekStart] ?? []
            let totalScore = scores.reduce(0) { $0 + $1.score }
            let rawAverage = Double(totalScore) / Double(scores.count)
            let average = ReviewScoreScale.display(fromStored: rawAverage)

            return WeeklyCategoryData(
                weekStart: weekStart,
                weekEnd: weekEnd,
                averageScore: average,
                index: index
            )
        }
    }
    
    
    // Fetch review scores for all ideals in category
    private func fetchReviewScores() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isDataReady = true
            return
        }
        let db = sharedDb
        
        let ideals = categoryIdeals
        if ideals.isEmpty {
            isDataReady = true
            return
        }
        
        Task { @MainActor in
            await withTaskGroup(of: (String, [ReviewScore]).self) { group in
                for ideal in ideals {
                    group.addTask {
                        return await Self.fetchReviewScoresForIdeal(idealId: ideal.id, userId: userId, db: db)
                    }
                }
                
                for await (idealId, scores) in group {
                    reviewScores[idealId] = scores
                }
                
                isDataReady = true
            }
        }
    }
    
    private static func fetchReviewScoresForIdeal(idealId: String, userId: String, db: Firestore) async -> (String, [ReviewScore]) {
        return await withCheckedContinuation { continuation in
            db.collection("users")
                .document(userId)
                .collection("ideals")
                .document(idealId)
                .collection("reviewScores")
                .order(by: "date")
                .getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        let scores = documents.compactMap { doc -> ReviewScore? in
                            try? doc.data(as: ReviewScore.self)
                        }
                        continuation.resume(returning: (idealId, scores))
                    } else {
                        continuation.resume(returning: (idealId, []))
                    }
                }
        }
    }
    
    // Filter review scores by date range
    private func filteredReviewScores(for idealId: String) -> [ReviewScore] {
        guard let scores = reviewScores[idealId] else { return [] }
        
        // If dateRange is provided, use it directly (ignore selectedFilter)
        if let dateRange = dateRange {
            return scores.filter { score in
                score.date >= dateRange.start && score.date <= dateRange.end
            }
        }
        
        // Otherwise, use selectedFilter
        let now = Date()
        
        guard let startDate = dateRangeStart else {
            return scores // "All" filter - return all scores
        }
        
        let endDate = now
        let startTimestamp = startDate.startOfDay.timeIntervalSince1970
        let endTimestamp = endDate.endOfDay.timeIntervalSince1970
        
        return scores.filter { score in
            score.date >= startTimestamp && score.date <= endTimestamp
        }
    }
    
    private var dateRangeStart: Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedFilter {
        case .all:
            return nil
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        }
    }
    
    // Weekly category average data structure
    private struct WeeklyCategoryData: Identifiable {
        let id = UUID()
        let weekStart: Date
        let weekEnd: Date
        let averageScore: Double // 0-10 scale
        let index: Int // Index for x-axis positioning (0, 1, 2, ...)
    }
    
    // Chart data structure: (x: Date, y: Double score 0-10, idealId: String, idealTitle: String)
    private struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let score: Double // 0-10 scale
        let idealId: String
        let idealTitle: String
        let index: Int // Index for x-axis positioning (0, 1, 2, ...)
    }
    
    // Flattened chart mark structure for compiler simplification
    private struct FlatChartMark: Identifiable {
        let id = UUID()
        let date: Date
        let score: Double
        let idealId: String
        let color: Color
        let index: Int // Index for x-axis positioning (0, 1, 2, ...)
    }
    
    
    
    // Ideal data for list display
    private struct IdealListData: Identifiable {
        let id: String
        let ideal: Ideal
        let averageScore: Double
        let lastCompletedDate: Date?
    }
    
    // Get ideals sorted by average score (highest first)
    private var sortedIdealsByScore: [IdealListData] {
        return categoryIdeals.compactMap { ideal -> IdealListData? in
            let scores = filteredReviewScores(for: ideal.id)
            guard !scores.isEmpty else { return nil }
            
            // Calculate average score (1-7 display scale)
            let total = scores.reduce(0) { $0 + $1.score }
            let rawAverage = Double(total) / Double(scores.count)
            let average = ReviewScoreScale.display(fromStored: rawAverage)
            
            // Get last completion date from ideal's lastCompletedDate field
            let lastCompletedDate: Date?
            if let lastCompletedTimestamp = ideal.lastCompletedDate, lastCompletedTimestamp > 0 {
                lastCompletedDate = Date(timeIntervalSince1970: lastCompletedTimestamp)
            } else {
                lastCompletedDate = nil
            }
            
            return IdealListData(
                id: ideal.id,
                ideal: ideal,
                averageScore: average,
                lastCompletedDate: lastCompletedDate
            )
        }.sorted { $0.averageScore > $1.averageScore }
    }
    
    // Format date in human readable format
    private func formatDate(_ date: Date) -> String {
        Self.mediumDateFormatter.string(from: date)
    }
    
    // Weekly category chart view
    private var weeklyCategoryChart: some View {
        let weeklyData = weeklyCategoryAverages
        guard !weeklyData.isEmpty else {
            return AnyView(
                Chart { }
                    .frame(height: 300)
                    .padding()
            )
        }
        
        let maxIndex = weeklyData.count > 0 ? weeklyData.count - 1 : 0
        let xAxisDomain: ClosedRange<Int> = 0...maxIndex
        let indexValues = Array(0...maxIndex)
        
        let dataPointSpacing = Self.dataPointSpacing
        let additionalSpace: CGFloat = 100.0
        let minWidth = CGFloat(weeklyData.count) * dataPointSpacing + additionalSpace
        
        let dateFormatter = Self.weekAxisFormatter

        return AnyView(
            ScrollView(.horizontal, showsIndicators: true) {
                Chart {
                    ForEach(weeklyData) { weekData in
                        LineMark(
                            x: .value("Week", weekData.index),
                            y: .value("Score", weekData.averageScore)
                        )
                        .foregroundStyle(LCColor.pink)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Week", weekData.index),
                            y: .value("Score", weekData.averageScore)
                        )
                        .foregroundStyle(LCColor.pink)
                        .symbolSize(60)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: indexValues) { value in
                        AxisGridLine()
                            .foregroundStyle(LCColor.dividerGrey.opacity(0.3))
                        if let indexValue = value.as(Int.self),
                           let weekData = weeklyData.first(where: { $0.index == indexValue }) {
                            AxisValueLabel {
                                VStack(spacing: 2) {
                                    Text("\(dateFormatter.string(from: weekData.weekStart)) - \(dateFormatter.string(from: weekData.weekEnd))")
                                        .font(.manrope(9, .medium))
                                    Text(String(format: "%.1f", weekData.averageScore))
                                        .font(.manrope(9, .medium))
                                }
                                .foregroundStyle(LCColor.ink)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .stride(by: 1)) { value in
                        AxisGridLine()
                            .foregroundStyle(LCColor.dividerGrey.opacity(0.3))
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .foregroundStyle(LCColor.ink)
                            }
                        }
                    }
                }
                .chartYScale(domain: 1...7)
                .chartXScale(domain: xAxisDomain)
                .frame(width: minWidth, height: 300)
                .padding(.trailing, 20)
                .padding(.vertical)
            }
            .padding(.horizontal)
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NeuSheetHeader(title: "\(category.rawValue) Review Scores", titleSize: 26) { dismiss() }
                ScrollView {
                VStack(spacing: 16) {
                    // Chart or single-value average
                    ZStack {
                        if emptyState != .none {
                            // Nothing to plot. The empty state below carries the
                            // screen, so don't reserve 300pt for a blank chart.
                            EmptyView()
                        } else if isDataReady && weeklyCategoryAverages.count == 1, let singleWeek = weeklyCategoryAverages.first {
                            // Single value: show "Average Score:" instead of chart
                            VStack(spacing: 12) {
                                Text("Average Score:")
                                    .font(.manrope(17, .bold))
                                    .foregroundColor(LCColor.textSecondary)
                                Text(String(format: "%.2f", singleWeek.averageScore))
                                    .font(.manrope(30, .heavy))
                                    .accentText(.pink)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                        } else {
                            weeklyCategoryChart
                        }

                        // Loading overlay
                        if !isDataReady {
                            ZStack {
                                LCColor.surface
                                    .opacity(0.6)
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .tint(LCColor.pink)
                                    Text("Loading chart data...")
                                        .font(.manrope(16, .semibold))
                                        .foregroundColor(LCColor.ink)
                                }
                            }
                            .frame(height: 300)
                            .cornerRadius(LCRadius.card)
                        }
                    }

                    // Two empty states, not one. The old condition also required
                    // `!categoryIdeals.isEmpty`, so a category the user had never
                    // added an ideal to showed NOTHING: an empty chart above and a
                    // suppressed message here — a blank screen.
                    if emptyState != .none {
                        VStack(spacing: 12) {
                            if emptyState == .noIdeals {
                                Image(category.lcCategoryIconV2())
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(LCColor.textMuted)
                                // `categoryIdeals` is already narrowed by `dateRange`
                                // when one was passed, so "yet" would be a lie there:
                                // the user may well have ideals in this category, just
                                // not in the week being shown.
                                Text(dateRange == nil
                                     ? "No \(category.rawValue) ideals yet"
                                     : "No \(category.rawValue) ideals in this period")
                                    .font(.manrope(16, .semibold))
                                    .foregroundColor(LCColor.textSecondary)
                                if dateRange == nil {
                                    Text("Add one from My Ideals and its review scores will show up here.")
                                        .font(.manrope(13, .medium))
                                        .foregroundColor(LCColor.textMuted)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } else {
                                Image(systemName: "chart.line.downtrend.xyaxis")
                                    .font(.system(size: 40))
                                    .foregroundColor(LCColor.textMuted)
                                Text("No review scores found for this period")
                                    .font(.manrope(16, .semibold))
                                    .foregroundColor(LCColor.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, LCMetrics.screenMargin)
                        .padding(.vertical, 40)
                    }

                    // Ideal list sorted by average score — grouped neumorphic card
                    if isDataReady && !sortedIdealsByScore.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            // Column headers
                            HStack {
                                Text("Ideal")
                                    .font(.manrope(13, .heavy))
                                    .foregroundColor(LCColor.textSecondary)
                                Spacer()
                                Text("Last Completion")
                                    .font(.manrope(13, .heavy))
                                    .foregroundColor(LCColor.textSecondary)
                                Spacer()
                                Text("Score")
                                    .font(.manrope(13, .heavy))
                                    .foregroundColor(LCColor.textSecondary)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)

                            NeuFeatheredDivider()

                            // Ideal rows
                            ForEach(Array(sortedIdealsByScore.enumerated()), id: \.element.id) { index, idealData in
                                HStack {
                                    Text(idealData.ideal.title)
                                        .font(.idealTitle(18))
                                        .foregroundColor(LCColor.ink)
                                        .imprinted()
                                    Spacer()
                                    if let lastCompleted = idealData.lastCompletedDate {
                                        Text(formatDate(lastCompleted))
                                            .font(.manrope(13, .medium))
                                            .foregroundColor(LCColor.textSecondary)
                                    } else {
                                        Text("—")
                                            .font(.manrope(13, .medium))
                                            .foregroundColor(LCColor.textMuted)
                                    }
                                    Spacer()
                                    Text(String(format: "%.2f", idealData.averageScore))
                                        .font(.manrope(16, .heavy))
                                        .accentText(.pink)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 15)
                                if index < sortedIdealsByScore.count - 1 {
                                    NeuFeatheredDivider()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .neuRaised(cornerRadius: LCRadius.card)
                        .padding(.horizontal, LCMetrics.screenMargin)
                        .padding(.top, 16)
                    }

                    Spacer()
                }
            }
            .background(LCColor.surface.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                // Only show date filter buttons if dateRange is not provided
                if dateRange == nil {
                    VStack(spacing: 0) {
                        // Date filter chips — selected = raised pink, unselected = sunken
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(TimeFilter.allCases, id: \.self) { filter in
                                    let isSelected = selectedFilter == filter
                                    Button(action: {
                                        HapticFeedback.impact()
                                        selectedFilter = filter
                                    }) {
                                        Group {
                                            if isSelected {
                                                Text(filter.rawValue)
                                                    .font(.manrope(14, .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 9)
                                                    .neuRaised(cornerRadius: LCRadius.chip,
                                                               fill: LCColor.pink,
                                                               cssOffset: LCNeumorphism.raisedOffsetSmall,
                                                               cssBlur: LCNeumorphism.raisedBlurSmall)
                                            } else {
                                                Text(filter.rawValue)
                                                    .font(.manrope(14, .bold))
                                                    .foregroundColor(LCColor.ink)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 9)
                                                    .neuSunken(cornerRadius: LCRadius.chip)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .background(LCColor.surface)
                    }
                }
            }
            }
            .background(LCColor.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if reviewScores.isEmpty {
                    isDataReady = false
                    fetchReviewScores()
                } else {
                    isDataReady = true
                }
            }
            .onChange(of: selectedFilter) { oldValue, newValue in
                // Recalculate when filter changes
            }
            .onChange(of: reviewScores.count) { oldValue, newValue in
                // Data updated
            }
        }
    }
}

// Wrapping legend view for ideal names with colored dots
private struct WrappingLegendView: View {
    let ideals: [(ideal: Ideal, color: Color)]
    let spacing: CGFloat = 30.0
    
    var body: some View {
        FlowLayout(alignment: .leading, horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(ideals, id: \.ideal.id) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)
                    Text(item.ideal.title)
                        .font(.manrope(12, .bold))
                        .foregroundColor(LCColor.ink)
                        .lineLimit(1)
                }
            }
        }
    }
}

#if DEBUG
@available(iOS 17.6, *)
#Preview {
    PreviewData.configureFirebaseIfNeeded()
    return CategoryReviewChartView(
        category: .fitness,
        allIdeals: PreviewData.lastWeekIdeals,
        accentColor: LCColor.pink,
        textColor: LCColor.ink,
        weekStartDay: PreviewData.weekStartDay
    )
}
#endif

