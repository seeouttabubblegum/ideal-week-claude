//
//  LastWeekReviewView.swift
//  The Ideal Week
//
//  Created on 1/15/25.
//

import SwiftUI
import SwiftData
import Charts
import FirebaseFirestore
import FirebaseAuth

struct LastWeekReviewView: View {
    @StateObject var viewModel = HistoryProgressViewViewModel()
    @StateObject private var forgottenTasksViewModel = ForgottenTasksViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var itemToView: Ideal = Ideal(id: "", title: "")
    @State private var categoryReviewScores: [String: [ReviewScore]] = [:]
    @State private var isChartDataReady = false
    @State private var itemToReview: Ideal?
    @State private var showTopIdealsView = false
    @State private var selectedCategoryForChart: Category? = nil
    @State private var selectedChartCategory: Category? = nil
    @State private var selectedChartIdeal: String? = nil
    @State private var selectedCategory: Category = .fix
    @State private var itemOffsets: [String: CGFloat] = [:]
    /// Stable ViewModel instance for read-only IdealListItemLabelV2 rows (avoids allocation per render).
    @State private var labelViewModel = IdealListViewViewModel()

    let lastWeekIdeals: [Ideal]
    let accentColor: Color
    let textColor: Color
    let weekStartDay: String
    
    @FirestoreQuery var allIdeals: [Ideal]
    @Query var storedTempSettings: [MainSettings]
    
    private let userId: String
    
    init(lastWeekIdeals: [Ideal], accentColor: Color, textColor: Color, weekStartDay: String, userId: String) {
        self.lastWeekIdeals = lastWeekIdeals
        self.accentColor = accentColor
        self.textColor = textColor
        self.weekStartDay = weekStartDay
        self.userId = userId
        self._allIdeals = FirestoreQuery(
            collectionPath: "users/\(userId)/ideals",
            predicates: [
                .order(by: "createdDate")
            ]
        )
        self._viewModel = StateObject(wrappedValue: HistoryProgressViewViewModel())
        self._itemToView = State(wrappedValue: Ideal(id: "", title: ""))
    }
    
    var complementaryColors: (color1: Color, color2: Color) {
        let (color1, color2) = accentColor.complementaryColors()
        return (color1.lighter(by: 0.3), color2.lighter(by: 0.3))
    }
    
    // Calculate the date range of the *last active week* — derived from the items actually shown.
    // `lastWeekIdeals` is pre-filtered by the parent to the last active week, so we anchor on the
    // most recent startDate present there and resolve the containing week range. Review-score
    // filtering then matches the same week the recap displays. Falls back to the immediate
    // previous calendar week when no items are present (preserves prior empty-history behavior).
    private var lastWeekDateRange: (start: TimeInterval, end: TimeInterval) {
        if let maxStartDate = lastWeekIdeals.map({ $0.startDate }).filter({ $0 > 0 }).max() {
            let anchor = Date(timeIntervalSince1970: maxStartDate)
            let start = WeekdayUtility.weekStart(for: anchor, weekStartDay: weekStartDay)
            let customCalendar = WeekdayUtility.calendar(firstWeekday: weekStartDay)
            let end = (customCalendar.date(byAdding: .day, value: 6, to: start) ?? start).endOfDay
            return (start.timeIntervalSince1970, end.timeIntervalSince1970)
        }
        let range = WeekdayUtility.previousWeekRange(weekStartDay: weekStartDay)
        return (range.start.timeIntervalSince1970, range.end.timeIntervalSince1970)
    }
    
    // Filter ideals by category for last week (no date filtering, just category)
    func catItems(_ cat: Category) -> [Ideal] {
        return lastWeekIdeals.filter { $0.category == cat.rawValue }
    }
    
    
    // Overall progress for last week
    private var overallProgressPercentage: Double {
        guard !lastWeekIdeals.isEmpty else { return 0 }
        
        let completedCount = lastWeekIdeals.filter { ideal in
            let targetCount: Int
            if ideal.targetCount == "6+" {
                targetCount = 6
            } else {
                targetCount = Int(ideal.targetCount) ?? 0
            }
            return ideal.doneCount >= targetCount
        }.count
        
        return Double(completedCount) / Double(lastWeekIdeals.count) * 100
    }
    
    // Last week completed count
    private var lastWeekCompletedCount: Int {
        let completedCount = lastWeekIdeals.filter { ideal in
            let targetCount: Int
            if ideal.targetCount == "6+" {
                targetCount = 6
            } else {
                targetCount = Int(ideal.targetCount) ?? 0
            }
            return ideal.doneCount >= targetCount
        }.count
        return completedCount
    }
    
    private func lastWeekAverageReviewScore(for category: Category) -> Double? {
        let (start, end) = lastWeekDateRange
        
        // Get all review scores for ideals in this category from last week
        let categoryIdeals = lastWeekIdeals.filter { $0.category == category.rawValue }
        var allScores: [Int] = []
        
        for ideal in categoryIdeals {
            if let scores = categoryReviewScores[ideal.id] {
                // Filter review scores from last week using ReviewScore.date
                let lastWeekScores = scores.filter { score in
                    score.date >= start && score.date <= end
                }
                allScores.append(contentsOf: lastWeekScores.map { $0.score })
            }
        }
        
        guard !allScores.isEmpty else { return nil }
        
        let totalScore = allScores.reduce(0, +)
        return Double(totalScore) / Double(allScores.count)
    }
    
    // Fetch review scores for all ideals
    private func fetchCategoryReviewScores() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        Task {
            let fetched = await ReviewScoreRepository.fetchScoresByIdeal(
                userId: userId,
                idealIds: lastWeekIdeals.map(\.id)
            )
            await MainActor.run {
                categoryReviewScores = fetched
            }
        }
    }
    
    // Chart data - only last week
    private func filteredReviewScoresForChart(for idealId: String) -> [ReviewScore] {
        guard let scores = categoryReviewScores[idealId] else { return [] }
        let (start, end) = lastWeekDateRange
        return scores.filter { score in
            score.date >= start && score.date <= end
        }
    }
    
    // Generate distinct colors for categories
    private func colorForCategory(_ category: Category) -> Color {
        ReviewChartPalette.color(for: category, fallback: accentColor)
    }
    
    // Get ideals with review scores for the selected category (or all categories)
    private var idealsWithReviewScoresForChart: [Ideal] {
        let targetCategories: [Category]
        if let selectedCategory = selectedChartCategory {
            targetCategories = [selectedCategory]
        } else {
            targetCategories = Category.allCases
        }
        
        var idealsWithScores: [Ideal] = []
        for category in targetCategories {
            let categoryIdeals = lastWeekIdeals.filter { $0.category == category.rawValue }
            for ideal in categoryIdeals {
                let scores = filteredReviewScoresForChart(for: ideal.id)
                if !scores.isEmpty {
                    idealsWithScores.append(ideal)
                }
            }
        }
        
        return idealsWithScores.sorted { ($0.createdDate > 0 ? $0.createdDate : 0) < ($1.createdDate > 0 ? $1.createdDate : 0) }
    }
    
    // Chart data structure for period-based averages
    private struct IdealAverageDataPoint: Identifiable {
        let id = UUID()
        let idealId: String
        let idealTitle: String
        let category: Category
        let averageScore: Double // 0-10 scale
        let index: Int
    }
    
    // Chart data structure for time-based data
    private struct TimeBasedDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let score: Double // 0-10 scale
        let idealId: String
        let idealTitle: String
        let index: Int
    }
    
    // Get chart data for "All" category mode or category + "All" ideal mode
    private var periodBasedChartData: [Category: [IdealAverageDataPoint]] {
        var categoryData: [Category: [IdealAverageDataPoint]] = [:]
        
        let allIdealsWithScores = idealsWithReviewScoresForChart
        let idealIndexMap: [String: Int] = Dictionary(uniqueKeysWithValues: allIdealsWithScores.enumerated().map { ($0.element.id, $0.offset) })
        
        let targetCategories: [Category]
        if let selectedCategory = selectedChartCategory {
            targetCategories = [selectedCategory]
        } else {
            targetCategories = Category.allCases
        }
        
        for category in targetCategories {
            let categoryIdeals = allIdealsWithScores.filter { $0.category == category.rawValue }
            var dataPoints: [IdealAverageDataPoint] = []
            
            for ideal in categoryIdeals {
                let scores = filteredReviewScoresForChart(for: ideal.id)
                guard !scores.isEmpty else { continue }
                
                let totalScore = scores.reduce(0) { $0 + $1.score }
                let rawAverage = Double(totalScore) / Double(scores.count)
                let average = ReviewScoreScale.display(fromStored: rawAverage)

                guard let index = idealIndexMap[ideal.id] else { continue }
                
                dataPoints.append(IdealAverageDataPoint(
                    idealId: ideal.id,
                    idealTitle: ideal.title,
                    category: category,
                    averageScore: average,
                    index: index
                ))
            }
            
            categoryData[category] = dataPoints.sorted { $0.index < $1.index }
        }
        
        return categoryData
    }
    
    // Get chart data for single ideal mode (time-based)
    private var timeBasedChartData: [TimeBasedDataPoint] {
        guard selectedChartCategory != nil,
              let selectedIdealId = selectedChartIdeal else {
            return []
        }
        
        let scores = filteredReviewScoresForChart(for: selectedIdealId)
        guard !scores.isEmpty else { return [] }
        
        var dateGroups: [Date: [ReviewScore]] = [:]
        for score in scores {
            let scoreDate = Date(timeIntervalSince1970: score.date)
            let dayStart = Calendar.current.startOfDay(for: scoreDate)
            if dateGroups[dayStart] == nil {
                dateGroups[dayStart] = []
            }
            dateGroups[dayStart]?.append(score)
        }
        
        let sortedDates = Array(dateGroups.keys).sorted()
        let ideal = lastWeekIdeals.first(where: { $0.id == selectedIdealId })
        let idealTitle = ideal?.title ?? ""
        
        return sortedDates.enumerated().compactMap { (index, date) -> TimeBasedDataPoint? in
            guard let dateScores = dateGroups[date] else { return nil }
            let rawAverage = Double(dateScores.reduce(0) { $0 + $1.score }) / Double(dateScores.count)
            let average = ReviewScoreScale.display(fromStored: rawAverage)
            return TimeBasedDataPoint(
                date: date,
                score: average,
                idealId: selectedIdealId,
                idealTitle: idealTitle,
                index: index
            )
        }
    }
    
    
    /// Category tabs as neumorphic chips — selected raised in pink, the rest in
    /// sunken wells (same rule as the reminder day chips). No flat fills, no
    /// hard grey hairlines.
    private var categoryTabBar: some View {
        HStack(spacing: 10) {
            ForEach(Category.allCases, id: \.id) { cat in
                let isSelected = self.selectedCategory == cat
                let label = HStack(spacing: 8) {
                    // LC category icon, v2 set (template-tinted, robust to missing tints)
                    Image(cat.lcCategoryIconV2())
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 17)
                    Text(cat.rawValue)
                        .font(.manrope(16, .heavy))
                }
                .foregroundColor(isSelected ? LCColor.contrastingInk(on: LCColor.pink) : LCColor.textSecondary)
                .frame(width: Self.maxTabWidth, height: 46)

                Button {
                    HapticFeedback.selection()
                    self.selectedCategory = cat
                } label: {
                    Group {
                        if isSelected {
                            label.neuRaised(cornerRadius: LCRadius.chip,
                                            fill: LCColor.pink,
                                            cssOffset: LCNeumorphism.raisedOffsetSmall,
                                            cssBlur: LCNeumorphism.raisedBlurSmall)
                        } else {
                            label.neuSunken(cornerRadius: LCRadius.chip)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: LCRadius.chip, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .padding(.vertical, 8)
    }

    private static let maxTabWidth: CGFloat = {
        let font = UIFont(name: "Manrope-ExtraBold", size: 16) ?? UIFont.systemFont(ofSize: 16)
        var maxWidth: CGFloat = 0
        for category in Category.allCases {
            let size = (category.rawValue as NSString).size(withAttributes: [.font: font])
            maxWidth = max(maxWidth, size.width)
        }
        return maxWidth + 60
    }()
    
    @ViewBuilder
    private var categoryContent: some View {
        let filteredItems = catItems(selectedCategory)
        
        if filteredItems.isEmpty {
            VStack {
                Text("No ideals in this category for last week")
                    .font(.manrope(16, .semibold))
                    .foregroundColor(LCColor.textSecondary)
                    .padding()
            }
            .frame(minHeight: 100)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(filteredItems, id: \.id) { item in
                    ZStack(alignment: .leading) {
                        // Background overlay for swipe actions
                        HStack(spacing: 0) {
                            // Right swipe overlay (Done with heart) - appears on LEFT when swiping right
                            if (self.itemOffsets[item.id] ?? 0) > 0 {
                                HStack(spacing: 8) {
                                    Spacer()
                                    let maxOffset = UIScreen.main.bounds.width / 4.0
                                    let progress = min((self.itemOffsets[item.id] ?? 0) / maxOffset, 1.0)
                                    Image(systemName: progress > 0.5 ? "heart.fill" : "heart")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(progress > 0.5 ? LCColor.pink : LCColor.textMuted)
                                        .animation(.easeInOut(duration: 0.2), value: progress)
                                    Text("Done")
                                        .font(.manrope(18, .heavy))
                                        .foregroundColor(LCColor.ink)
                                        .lineLimit(1)
                                        .fixedSize()
                                    Spacer()
                                }
                                .frame(width: self.itemOffsets[item.id] ?? 0)
                            }
                            
                            Spacer()
                        }
                        
                        // Main item content
                        IdealListItemLabelV2(
                            item: item,
                            background: LCColor.pink,
                            viewModel: labelViewModel,
                            itemToEdit: .constant(item),
                            onTap: {
                                itemToView = item
                                viewModel.showingDetailView = true
                            }
                        )
                        .offset(x: self.itemOffsets[item.id] ?? 0)
                        .overlay {
                            HorizontalSwipeOverlay(
                                onTap: {
                                    HapticFeedback.impact(style: .light)
                                    itemToView = item
                                    viewModel.showingDetailView = true
                                },
                                onChanged: { offset in
                                    self.itemOffsets[item.id] = offset
                                },
                                onSwipeCompleted: {
                                    HapticFeedback.impact()
                                    forgottenTasksViewModel.incrementDoneCount(for: item)

                                    // Expire before reading: the flag is scoped to the week it
                                    // was enabled in, and only the ideal-list swipe used to
                                    // expire it — so completing from here honoured a flag that
                                    // had already run out.
                                    storedTempSettings.first?.expireSkipReviewsIfWeekElapsed(
                                        weekStartDay: weekStartDay,
                                        now: DateProviderService.shared.now())
                                    let shouldShowReview = storedTempSettings.first?.skip_reviews != true
                                    if shouldShowReview {
                                        // Pass the PRE-increment snapshot: IdealReviewView stores
                                        // position as doneCount + 1.
                                        itemToReview = item
                                    }
                                },
                                onEnded: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        self.itemOffsets[item.id] = 0
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, item.id == filteredItems.first?.id ? 10 : 0)
                    .padding(.bottom, item.id == filteredItems.last?.id ? 10 : 10)
                    .accessibilityAction(named: "Mark done") {
                        HapticFeedback.impact()
                        forgottenTasksViewModel.incrementDoneCount(for: item)
                        storedTempSettings.first?.expireSkipReviewsIfWeekElapsed(
                            weekStartDay: weekStartDay,
                            now: DateProviderService.shared.now())
                        let shouldShowReview = storedTempSettings.first?.skip_reviews != true
                        if shouldShowReview {
                            itemToReview = item
                        }
                    }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 20)
            // Force full view recreation on tab switch — resets UIKit gesture recognizers.
            .id(selectedCategory)
        }
    }

    // Use the same source shown in History so summary metrics always stay in sync.
    private var summaryIdeals: [Ideal] {
        lastWeekIdeals
    }

    // Computed properties for last week data
    private var lastWeekTotalCount: Int {
        summaryIdeals.count
    }
    
    private var lastWeekTotalActions: Int {
        summaryIdeals.reduce(0) { $0 + $1.doneCount }
    }
    
    // Helper to get last week ideals filtered by category (excluding wishlist)
    private func lastWeekCategoryIdeals(for category: Category) -> [Ideal] {
        return lastWeekIdeals.filter { 
            $0.category == category.rawValue && !$0.wishlistEnabled 
        }
    }
    
    // Check if all target actions are completed for last week
    private func areAllTargetActionsCompleted() -> Bool {
        let filteredIdeals = lastWeekIdeals.filter { !$0.wishlistEnabled }
        var totalPossibleActions = 0
        var completedActions = 0
        
        for ideal in filteredIdeals {
            let targetCountInt: Int = {
                if ideal.targetCount == "6+" {
                    return 6
                } else {
                    return Int(ideal.targetCount) ?? 0
                }
            }()
            
            totalPossibleActions += targetCountInt
            
            if ideal.doneCount >= targetCountInt {
                completedActions += targetCountInt
            } else {
                completedActions += ideal.doneCount
            }
        }
        
        return totalPossibleActions > 0 && completedActions >= totalPossibleActions
    }
    
    // Calculate category progress for last week
    private func calculateLastWeekCategoryProgress(categoryIdeals: [Ideal], category: Category) -> (progress: Double, completedActions: Int, totalPossibleActions: Int) {
        // Calculate from ideals
        var totalPossibleActions = 0
        var completedActions = 0
        
        for ideal in categoryIdeals {
            let targetCountInt: Int = {
                if ideal.targetCount == "6+" {
                    return 6
                } else {
                    return Int(ideal.targetCount) ?? 0
                }
            }()
            
            totalPossibleActions += targetCountInt
            
            // Count completed actions: if ideal is completed (doneCount >= targetCount), count targetCount
            // Otherwise, count doneCount (partial progress)
            if ideal.doneCount >= targetCountInt {
                completedActions += targetCountInt
            } else {
                completedActions += ideal.doneCount
            }
        }
        
        guard totalPossibleActions > 0 else {
            return (progress: 1.0, completedActions: 0, totalPossibleActions: 0)
        }
        
        let progress = Double(completedActions) / Double(totalPossibleActions)
        
        return (progress: min(progress, 1.0), completedActions: completedActions, totalPossibleActions: totalPossibleActions)
    }
    
    // Ring color for category
    private func categoryRingColor(for category: Category) -> Color {
        // Palette-only ring colors (no green / orange / purple in this system).
        // Cycled so adjacent rings never share a colour. Must stay identical to
        // HistoryProgressView.categoryRingColor — that diagram is the standard.
        switch category {
        case .fix:       return LCColor.pink
        case .fitness:   return LCColor.blue
        case .feelings:  return LCColor.yellow
        case .faculties: return LCColor.pink
        case .family:    return LCColor.blue
        case .finance:   return LCColor.yellow
        case .fun:       return LCColor.pink
        }
    }
    
    // Progress arc view for category (matches Progress page: icon-sized initial arc, then proportional)
    private func categoryProgressArcView(categoryIdeals: [Ideal], category: Category, ringSize: CGFloat, ringColor: Color, strokeStyle: StrokeStyle, center: CGPoint) -> some View {
        let (progress, completedActions, _) = calculateLastWeekCategoryProgress(categoryIdeals: categoryIdeals, category: category)
        let radius = ringSize / 2
        let circumference = 2 * .pi * radius
        let strokeWidth = strokeStyle.lineWidth
        
        let arcLength: CGFloat
        if completedActions == 0 {
            let iconSize = strokeWidth * 0.5
            let iconPadding: CGFloat = 3
            arcLength = iconSize + (iconPadding * 2)
        } else {
            arcLength = circumference * CGFloat(progress)
        }
        
        let arcAngleRadians = arcLength / radius
        let arcAngleDegrees = arcAngleRadians * 180 / .pi
        
        let startAngle = Angle(degrees: -60)
        let endAngle = Angle(degrees: -60 + arcAngleDegrees)
        
        return Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
        }
        .stroke(ringColor, style: strokeStyle)
    }
    
    // Category rings view
    @ViewBuilder
    private func categoryRingsView(categoriesWithArcs: [Category]) -> some View {
        ZStack {
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                ZStack {
                    ForEach(Array(categoriesWithArcs.enumerated()), id: \.element) { index, category in
                        categoryRingView(
                            category: category,
                            ringIndex: index,
                            center: center
                        )
                    }
                }
            }
        }
        // Same canvas rule as the Progress page: hug the rings actually drawn so
        // a sparse week doesn't leave the totals card stranded below.
        .frame(width: ProgressRingsLayout.canvasSize(ringCount: categoriesWithArcs.count),
               height: ProgressRingsLayout.canvasSize(ringCount: categoriesWithArcs.count))
        .padding(.top, 32)
        .padding(.bottom, 22)
    }
    
    // Ring stroke and size (shared with the Progress page)
    private let ringStrokeWidth: CGFloat = ProgressRingsLayout.ringStrokeWidth
    private let innermostRingDiameter: CGFloat = ProgressRingsLayout.innermostRingDiameter
    
    @ViewBuilder
    private func categoryRingView(category: Category, ringIndex: Int, center: CGPoint) -> some View {
        let ringDiameter = innermostRingDiameter + (CGFloat(ringIndex) * ringStrokeWidth * 2)
        let ringColor = categoryRingColor(for: category)
        let categoryIdeals = lastWeekCategoryIdeals(for: category)
        
        let strokeStyle = StrokeStyle(lineWidth: ringStrokeWidth, lineCap: .round)
        let radius = ringDiameter / 2

        ZStack {
            // Full ring background: SUNKEN neumorphic track (recessed well the
            // arc fills) — identical to the Progress page, which is the design
            // standard for this diagram (client, 2026-09-02). Replaces a
            // near-black category-tinted donut with two 1pt black hairlines,
            // which read as a dark-mode widget dropped onto the light card.
            Path { path in
                path.addEllipse(in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }
            .stroke(
                LCColor.surface
                    .shadow(.inner(color: LCColor.shadowDark, radius: 3, x: 3, y: 3))
                    .shadow(.inner(color: LCColor.shadowLight, radius: 3, x: -3, y: -3)),
                style: strokeStyle
            )

            if !categoryIdeals.isEmpty {
                categoryProgressArcView(
                    categoryIdeals: categoryIdeals,
                    category: category,
                    ringSize: ringDiameter,
                    ringColor: ringColor,
                    strokeStyle: strokeStyle,
                    center: center
                )
            }
            
            // Category icon at the start of the arc (top-right, -60°)
            if !categoryIdeals.isEmpty {
                let startAngleRad = -60.0 * .pi / 180.0
                let iconX = center.x + radius * cos(startAngleRad)
                let iconY = center.y + radius * sin(startAngleRad)
                Image(category.lcCategoryIconV2())
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: ringStrokeWidth * 0.72, height: ringStrokeWidth * 0.72)
                    .foregroundColor(LCColor.ink)
                    .padding(3)
                    .position(x: iconX, y: iconY)
            }
        }
        .frame(width: center.x * 2, height: center.y * 2)
    }
    
    // Last week's totals in the same card as the Progress and Profile pages.
    @ViewBuilder
    private var weekProgressGrid: some View {
        StatWellsCard(idealsValue: lastWeekTotalCount,
                      idealsLabel: "TOTAL IDEALS",
                      actionsValue: lastWeekTotalActions,
                      actionsLabel: "TOTAL ACTIONS")
            .padding(.horizontal, LCMetrics.screenMargin)
            .padding(.top, 10)
            .padding(.bottom, 20)
    }
    
    // MARK: - Body Sub-Views
    
    @ViewBuilder
    private var closeButton: some View {
        HStack {
            Spacer()
            // Standard raised neumorphic close (handoff 1g: top-right).
            NeuCloseButton(action: {
                dismiss()
            }, diameter: 36)
            .padding(.trailing, 16)
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var introText: some View {
        Text("Hey, you finished your week. Here's where you landed. You have the ability to check off anything else that you might have missed from the HISTORY section.")
            .font(.manrope(16, .heavy))
            .foregroundColor(LCColor.textMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 20)
    }

    @ViewBuilder
    private var overallProgressSection: some View {
        VStack(spacing: 13) {
            Text("Overall Progress")
                .font(.manrope(27, .heavy))
                .foregroundColor(LCColor.ink)

            overallProgressContent
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(LCColor.surface)
    }
    
    @ViewBuilder
    private var overallProgressContent: some View {
        let allCategories: [Category] = [.fix, .fitness, .feelings, .faculties, .family, .finance, .fun]
        let categoriesWithArcs = allCategories.filter { category in
            let categoryIdeals = lastWeekCategoryIdeals(for: category)
            return !categoryIdeals.isEmpty
        }
        
        if categoriesWithArcs.isEmpty {
            emptyProgressView
        } else {
            categoryRingsView(categoriesWithArcs: categoriesWithArcs)
        }
    }
    
    @ViewBuilder
    private var emptyProgressView: some View {
        if lastWeekTotalCount == 0 {
            VStack(spacing: 12) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 60))
                    .accentText(.pink)
                Text("You haven't added any ideals in your list yet.")
                    .font(.manrope(17, .bold))
                    .foregroundColor(LCColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(width: 350, height: 350)
        } else {
            let allTargetActionsCompleted = areAllTargetActionsCompleted()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .accentText(.blue)
                Text(allTargetActionsCompleted ? "You had superb performance last week! Bravo!" : "You've completed all the pieces last week. Bravo!")
                    .font(.manrope(17, .bold))
                    .foregroundColor(LCColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(width: 350, height: 350)
        }
    }
    
    @ViewBuilder
    private var categoryButtonsSection: some View {
        VStack(spacing: 8) {
            ForEach(Category.allCases) { category in
                categoryButton(for: category)
            }
            
            topIdealsButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private func categoryButton(for category: Category) -> some View {
        Button(action: {
            HapticFeedback.impact()
            selectedCategoryForChart = category
        }) {
            // Neumorphic grouped row (palette only — the old accent-filled
            // pill is off-palette in the handoff).
            HStack {
                Text(category.rawValue)
                    .font(.manrope(16, .heavy))
                    .foregroundColor(LCColor.ink)
                Spacer()
                if let avgScore = lastWeekAverageReviewScore(for: category) {
                    let display = ReviewScoreScale.display(fromStored: avgScore)
                    Text("\(ReviewScoreScale.formattedDisplay(display))/7")
                        .font(.manrope(16, .heavy))
                        .accentText(.pink)
                } else {
                    Text("—")
                        .font(.manrope(16, .heavy))
                        .foregroundColor(LCColor.textMuted)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(LCColor.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(NeuRowButtonStyle())
    }
    
    @ViewBuilder
    private var topIdealsButton: some View {
        Button(action: {
            HapticFeedback.impact()
            showTopIdealsView = true
        }) {
            HStack {
                Text("Top Ideals")
                    .font(.manrope(16, .heavy))
                    .foregroundColor(LCColor.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(LCColor.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .neuRaised(cornerRadius: LCRadius.chip, cssOffset: LCNeumorphism.raisedOffsetSmall, cssBlur: LCNeumorphism.raisedBlurSmall)
        }
    }
    
    @ViewBuilder
    private var historySection: some View {
        VStack(spacing: 0) {
            Text("History")
                .font(.manrope(27, .heavy))
                .foregroundColor(LCColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                categoryTabBar
            }
            .padding(.top, 16)
            
            categoryContent
        }
    }
    
    @ViewBuilder
    private var mainScrollContent: some View {
        VStack(spacing: 0) {
            introText
            overallProgressSection
            weekProgressGrid
            categoryButtonsSection
            historySection
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                closeButton

                ScrollView {
                    mainScrollContent
                }
            }
            .background(LCColor.surface.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                viewModel.fetchUser()
                fetchCategoryReviewScores()
            }
            .onChange(of: categoryReviewScores.count) { oldValue, newValue in
                if newValue > 0 {
                    isChartDataReady = true
                }
            }
            .onChange(of: selectedCategory) { _, _ in
                itemOffsets.removeAll()
            }
            .onChange(of: itemToReview) { _, newValue in
                if newValue == nil {
                    itemOffsets.removeAll()
                }
            }
            .sheet(isPresented: $viewModel.showingDetailView, onDismiss: { viewModel.showingDetailView = false }) {
                IdealEditView(item: itemToView, editItemPresented: $viewModel.showingDetailView, scheduleLocked: true)
            }
            .sheet(item: $itemToReview, onDismiss: { itemToReview = nil }) { item in
                IdealReviewView(item: item)
            }
            .sheet(isPresented: $showTopIdealsView) {
                TopIdealsView(
                    allIdeals: lastWeekIdeals,
                    accentColor: accentColor,
                    textColor: textColor,
                    weekStartDay: weekStartDay
                )
            }
            .sheet(item: $selectedCategoryForChart) { category in
                CategoryReviewChartView(
                    category: category,
                    allIdeals: lastWeekIdeals,
                    accentColor: accentColor,
                    textColor: textColor,
                    weekStartDay: weekStartDay,
                    dateRange: lastWeekDateRange
                )
                .id("\(category.rawValue)-\(lastWeekIdeals.count)")
            }
            .accentColor(accentColor)
        }
    }
}

#if DEBUG
#Preview {
    PreviewData.configureFirebaseIfNeeded()
    return LastWeekReviewView(
        lastWeekIdeals: PreviewData.lastWeekIdeals,
        accentColor: LCColor.pink,
        textColor: LCColor.ink,
        weekStartDay: PreviewData.weekStartDay,
        userId: PreviewData.userId
    )
}
#endif
