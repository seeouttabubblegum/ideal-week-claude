//
//  HistoryProgressView.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 28/8/25.
//

import SwiftData
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import UIKit
import Charts

struct HistoryProgressView: View {
    @StateObject var viewModel = HistoryProgressViewViewModel()
    @State private var showDrawer: Bool = false
    @State private var selectedCategory: Category = Category.allCases.first ?? .fix
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var selectedCategoryForChart: Category? = nil
    @State private var showTopIdealsView = false
    @State private var showCommunityIdealsView = false
    @State private var categoryReviewScores: [String: [ReviewScore]] = [:]
    @State private var selectedChartCategory: Category? = nil // nil = "All", or specific category
    @State private var chartSelectedFilter: TimeFilter = .all
    @State private var selectedChartIdeal: String? = nil // nil = "All", or specific ideal ID
    @State private var isChartDataReady: Bool = false
    @State private var hasInitializedDateRangeFromIdeals: Bool = false
    
    @FirestoreQuery var allIdeals: [Ideal]
    
    @Query var storedTempSettings: [MainSettings]
    
    var accentColor: Color {
        // Follows the palette chosen in Settings (LCPalette).
        LCColor.pink
    }
    
    var textColor: Color {
        if let firstSettings = storedTempSettings.first {
            return Color(red: firstSettings.textColorRed, green: firstSettings.textColorGreen, blue: firstSettings.textColorBlue, opacity: firstSettings.textColorOpacity)
        } else {
            return Color.black
        }
    }
    
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
        self._allIdeals = FirestoreQuery(
            collectionPath: "users/\(userId)/ideals",
            predicates: [
                .order(by: "createdDate")
            ]
        )
        self._viewModel = StateObject(wrappedValue: HistoryProgressViewViewModel())

        // Initialize dates to a default range (will be set to previous week in onAppear)
        // For now, set to placeholder dates - will be recalculated in onAppear with proper week start day
        let calendar = Calendar.current
        let now = Date()
        // Default to last 7 days as fallback, will be recalculated in onAppear with proper week boundaries
        let defaultStart = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now
        self._startDate = State(initialValue: defaultStart)
        self._endDate = State(initialValue: now.endOfDay)
    }
    
    private func calculateLastWeekRange() -> (start: Date, end: Date) {
        // Get week start day from settings
        let weekStartDay = storedTempSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
        // Use the last *active* week (skips empty weeks). Falls back to the immediate previous
        // calendar week when the user has no historical ideals at all.
        let startDates = allIdeals.filter { !$0.wishlistEnabled }.map { $0.startDate }
        if let activeRange = WeekdayUtility.lastActiveWeekRange(
            fromStartDates: startDates,
            weekStartDay: weekStartDay
        ) {
            return activeRange
        }
        return WeekdayUtility.previousWeekRange(weekStartDay: weekStartDay)
    }
    
    // NOTE: the per-category history browser (tab bar + item list + date filter)
    // moved to the Profile page as `TopIdealsHistorySection`. This view keeps only
    // the Weekly Progress rings, week grid, category review buttons, and charts.
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top navigation
                TopNav(pageTitle: "My Progress", isIdealList: false, showDrawer: $showDrawer, showingNewItemView: .constant(false), idealsUserId: userId, usesBlueDrawerGlyph: true)
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Overall Progress section
                        VStack(spacing: 13) {  // 50% of 26 (space between title and ring area)
                            // Filter out categories with no ideals and categories with 0 arcs, show rings or completion message
                            // Order: fix (innermost/smallest) to fun (outermost/largest)
                            let allCategories: [Category] = [.fix, .fitness, .feelings, .faculties, .family, .finance, .fun]
                            let categoriesWithArcs = allCategories.filter { category in
                                // Use current week ideals filtered by category
                                let categoryIdeals = currentWeekIdeals.filter { 
                                    $0.category == category.rawValue
                                }
                                // Filter out categories with no ideals
                                // Keep all categories with ideals, even if 100% completed
                                return !categoryIdeals.isEmpty
                            }
                            
                            if categoriesWithArcs.isEmpty {
                                // Check if total ideals = 0 for current week
                                let totalIdeals = currentWeekIdeals
                                if totalIdeals.isEmpty {
                                    // No ideals added yet
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
                                    // All categories completed - show message
                                    VStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 60))
                                            .accentText(.blue)
                                        Text("You've completed all the pieces this week. Bravo!")
                                            .font(.manrope(17, .bold))
                                            .foregroundColor(LCColor.ink)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                }
                                .frame(width: 350, height: 350)
                                }
                            } else {
                                // Show rings for categories with arcs
                                categoryRingsView(categoriesWithArcs: categoriesWithArcs)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)   // 50% of 24 (space above ring area)
                        .padding(.bottom, 14)  // 50% of 27 (space below ring area)

                        // Week Progress Grid
                        weekProgressGrid

                        // These scores are THIS WEEK's, but tapping a row opens the
                        // all-time chart — so a category last reviewed weeks ago reads
                        // "—" here and a real average there. Name the period so the two
                        // stop looking like a contradiction.
                        Text("This Week's Review Scores")
                            .font(.hhSamuel(23))
                            .textCase(.uppercase)
                            .accentText(.pink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, LCMetrics.screenMargin)
                            .padding(.bottom, 6)

                        // Category rows (grouped neumorphic card, feathered dividers)
                        VStack(spacing: 0) {
                            // Category buttons with review scores
                            ForEach(Array(Category.allCases.enumerated()), id: \.element.id) { index, category in
                                Button(action: {
                                    HapticFeedback.impact()
                                    selectedCategoryForChart = category
                                }) {
                                    HStack {
                                        Text(category.rawValue)
                                            .font(.manrope(16, .heavy))
                                            .foregroundColor(LCColor.ink)
                                        Spacer()
                                        if let avgScore = currentWeekAverageReviewScore(for: category) {
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
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(LCColor.textSecondary)
                                            .padding(.leading, 4)
                                    }
                                    .padding(.horizontal, 18)
                                    .neuGroupedRow()
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if index < Category.allCases.count - 1 {
                                    NeuFeatheredDivider()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .neuRaised(cornerRadius: LCRadius.card)
                        .padding(.horizontal, LCMetrics.screenMargin)
                        .padding(.bottom, 16)

                        // Top Ideals / Community rows (second grouped card)
                        VStack(spacing: 0) {
                            // Top Ideals button
                            Button(action: {
                                HapticFeedback.impact()
                                showTopIdealsView = true
                            }) {
                                HStack {
                                    Text("Your Top Ideals")
                                        .font(.manrope(16, .heavy))
                                        .foregroundColor(LCColor.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(LCColor.textSecondary)
                                }
                                .padding(.horizontal, 18)
                                .neuGroupedRow()
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            // Community browser is switched off (AppStoreConfig).
                            // "Your Top Ideals" above is unaffected.
                            if AppStoreConfig.isCommunityIdealsEnabled {
                            NeuFeatheredDivider()

                            // Community Ideals button
                            Button(action: {
                                HapticFeedback.impact()
                                showCommunityIdealsView = true
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .accentText(.blue)
                                    Text("Top Ideals from the Community")
                                        .font(.manrope(16, .heavy))
                                        .foregroundColor(LCColor.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(LCColor.textSecondary)
                                }
                                .padding(.horizontal, 18)
                                .neuGroupedRow()
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        .neuRaised(cornerRadius: LCRadius.card)
                        .padding(.horizontal, LCMetrics.screenMargin)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(LCColor.surface.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                viewModel.fetchUser()
                // Always initialize to last week with proper week start day from settings
                let lastWeek = calculateLastWeekRange()
                startDate = lastWeek.start
                endDate = lastWeek.end
                fetchCategoryReviewScores()
            }
            .onChange(of: allIdeals.count) { oldValue, newValue in
                // Refetch review scores when ideals change
                if newValue > 0 {
                    fetchCategoryReviewScores()
                    isChartDataReady = true
                }
                // Initialize the date pickers to the last *active* week once Firestore loads.
                // Only runs once so we don't override the user's manual date selection.
                if !hasInitializedDateRangeFromIdeals && newValue > 0 {
                    let lastWeek = calculateLastWeekRange()
                    startDate = lastWeek.start
                    endDate = lastWeek.end
                    hasInitializedDateRangeFromIdeals = true
                }
            }
            .onChange(of: categoryReviewScores.count) { oldValue, newValue in
                if newValue > 0 {
                    isChartDataReady = true
                }
            }
            .onChange(of: selectedChartCategory) { oldValue, newValue in
                // Chart will update automatically via computed properties
            }
            .onChange(of: chartSelectedFilter) { oldValue, newValue in
                // Chart will update automatically via computed properties
            }
            .sheet(item: $selectedCategoryForChart) { category in
                CategoryReviewChartView(
                    category: category,
                    allIdeals: allIdeals,
                    accentColor: accentColor,
                    textColor: textColor,
                    weekStartDay: storedTempSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
                )
                .id("\(category.rawValue)-\(allIdeals.count)")
            }
            .sheet(isPresented: $showTopIdealsView) {
                TopIdealsView(
                    allIdeals: allIdeals,
                    accentColor: accentColor,
                    textColor: textColor,
                    weekStartDay: storedTempSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
                )
            }
            .sheet(isPresented: $showCommunityIdealsView) {
                CommunityIdealsView(
                    allIdeals: allIdeals,
                    accentColor: accentColor,
                    textColor: textColor,
                    useAppleIntelligence: storedTempSettings.first?.useAppleIntelligence ?? false
                )
            }
            .padding(.leading, MenuDrawer.contentInset)   // iPad sidebar inset (0 on iPhone)
            .overlay(
                MenuDrawer(showDrawer: $showDrawer, activeView: "history")
            )
            .accentColor(accentColor)
        }
    }
    
    // MARK: - Progress Views
    
    // Constant stroke width for all rings
    private let ringStrokeWidth: CGFloat = ProgressRingsLayout.ringStrokeWidth
    
    // Center blank space diameter (area that doesn't represent any category)
    private let centerBlankSpaceDiameter: CGFloat = 25
    
    // Innermost ring diameter (first ring in sequence gets this size)
    private let innermostRingDiameter: CGFloat = ProgressRingsLayout.innermostRingDiameter
    
    @ViewBuilder
    private func categoryRingsView(categoriesWithArcs: [Category]) -> some View {
        // Use a single GeometryReader for all rings to ensure consistent coordinate space
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Draw rings from innermost (index 0 = fix) to outermost (last index = fun)
                ForEach(Array(categoriesWithArcs.enumerated()), id: \.element) { index, category in
                    categoryRingView(
                        category: category,
                        ringIndex: index, // index 0 = innermost, last index = outermost
                        center: center
                    )
                }
            }
        }
        // Canvas hugs the rings actually drawn instead of a fixed 350pt square, so
        // a two-category week doesn't leave the totals card stranded far below.
        .frame(width: ProgressRingsLayout.canvasSize(ringCount: categoriesWithArcs.count),
               height: ProgressRingsLayout.canvasSize(ringCount: categoriesWithArcs.count))
        // Replaces the dead canvas the fixed square used to contribute, so a full
        // seven-ring week keeps the spacing it has today.
        .padding(.top, 32)
        .padding(.bottom, 22)
    }
    
    @ViewBuilder
    private func categoryRingView(category: Category, ringIndex: Int, center: CGPoint) -> some View {
        // Calculate ring diameter: innermost ring is 70px, each subsequent ring adds 2 * stroke width (10px)
        // This places rings one after another (outer edge of one touches inner edge of next)
        let ringDiameter = innermostRingDiameter + (CGFloat(ringIndex) * ringStrokeWidth * 2)
        let ringColor = categoryRingColor(for: category)
        // Use current week ideals filtered by category (already filtered for startDate and wishlist)
        let categoryIdeals = currentWeekIdeals.filter { 
            $0.category == category.rawValue
        }
        
        // Stroke style with constant 10px width for all rings, rounded ends
        let strokeStyle = StrokeStyle(lineWidth: ringStrokeWidth, lineCap: .round)
        let radius = ringDiameter / 2

        ZStack {
            // Full ring background: SUNKEN neumorphic track (recessed well the arc fills)
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

            // Draw single progress arc for the category
            if !categoryIdeals.isEmpty {
                categoryProgressArcView(
                    categoryIdeals: categoryIdeals,
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
                // Same glyph set as the ideal-list category bands (LC v2 line
                // icons), template-rendered so the ink tint applies.
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
    
    private func calculateCategoryProgress(categoryIdeals: [Ideal]) -> (progress: Double, completedActions: Int, totalPossibleActions: Int) {
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
        
        // If no targets, consider it completed
        guard totalPossibleActions > 0 else {
            return (progress: 1.0, completedActions: 0, totalPossibleActions: 0)
        }
        
        let progress = Double(completedActions) / Double(totalPossibleActions)
        
        return (progress: min(progress, 1.0), completedActions: completedActions, totalPossibleActions: totalPossibleActions)
    }
    
    private func categoryProgressArcView(categoryIdeals: [Ideal], ringSize: CGFloat, ringColor: Color, strokeStyle: StrokeStyle, center: CGPoint) -> some View {
        let (progress, completedActions, _) = calculateCategoryProgress(categoryIdeals: categoryIdeals)
        let radius = ringSize / 2
        let circumference = 2 * .pi * radius
        let strokeWidth = strokeStyle.lineWidth
        
        // Calculate arc length: when nothing completed, use category icon space + same padding as around icon (3pt each side)
        let arcLength: CGFloat
        if completedActions == 0 {
            let iconSize = strokeWidth * 0.5  // matches category icon font size
            let iconPadding: CGFloat = 3      // matches .padding(3) on the icon
            arcLength = iconSize + (iconPadding * 2)
        } else {
            arcLength = circumference * CGFloat(progress)
        }
        
        // Convert arc length to angle (in radians, then to degrees)
        let arcAngleRadians = arcLength / radius
        let arcAngleDegrees = arcAngleRadians * 180 / .pi
        
        // Start from top-right (-60 degrees, 30 degrees to the right of top) and draw clockwise
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
    
    @ViewBuilder
    /// This week's totals in the same card as the Profile page's lifetime stats.
    private var weekProgressGrid: some View {
        StatWellsCard(idealsValue: currentWeekTotalCount,
                      idealsLabel: "TOTAL IDEALS",
                      actionsValue: totalActionsCount,
                      actionsLabel: "TOTAL ACTIONS")
            .padding(.horizontal, LCMetrics.screenMargin)
            .padding(.top, 10)
            .padding(.bottom, 20)
    }

    // MARK: - Progress Computed Properties

    private func categoryRingColor(for category: Category) -> Color {
        // Palette-only ring colors (no green / orange / purple in this system).
        // Cycled so adjacent rings never share a colour.
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
    
    
    
    
    private var overallProgressPercentage: Double {
        let filteredIdeals = currentWeekIdeals
        guard !filteredIdeals.isEmpty else { return 0 }
        
        let completedCount = filteredIdeals.filter { ideal in
            let targetCount: Int
            if ideal.targetCount == "6+" {
                targetCount = 6
            } else {
                targetCount = Int(ideal.targetCount) ?? 0
            }
            return ideal.doneCount >= targetCount
        }.count
        
        return Double(completedCount) / Double(filteredIdeals.count) * 100
    }
    
    private var currentWeekCompletedCount: Int {
        currentWeekIdeals.filter { ideal in
            let targetCount: Int
            if ideal.targetCount == "6+" {
                targetCount = 6
            } else {
                targetCount = Int(ideal.targetCount) ?? 0
            }
            return ideal.doneCount >= targetCount
        }.count
    }
    
    private var currentWeekTotalCount: Int {
        currentWeekIdeals.count
    }
    
    private var totalActionsCount: Int {
        currentWeekIdeals.reduce(0) { $0 + $1.doneCount }
    }
    
    private var currentWeekDateRange: (start: TimeInterval, end: TimeInterval) {
        let weekStartDay = storedTempSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
        let range = WeekdayUtility.currentWeekRange(weekStartDay: weekStartDay)
        return (range.start.timeIntervalSince1970, range.end.timeIntervalSince1970)
    }
    
    private var lastWeekDateRange: (start: TimeInterval, end: TimeInterval) {
        let weekStartDay = storedTempSettings.first?.week_start_day ?? WeekdayUtility.defaultWeekStartDay
        // Match the picker behavior: anchor on the last *active* week, falling back to the
        // immediate previous calendar week when there's no history.
        let startDates = allIdeals.filter { !$0.wishlistEnabled }.map { $0.startDate }
        let range = WeekdayUtility.lastActiveWeekRange(
            fromStartDates: startDates,
            weekStartDay: weekStartDay
        ) ?? WeekdayUtility.previousWeekRange(weekStartDay: weekStartDay)
        return (range.start.timeIntervalSince1970, range.end.timeIntervalSince1970)
    }
    
    // Filtered ideals for current week: startDate in current week and not wishlist enabled
    private var currentWeekIdeals: [Ideal] {
        let (start, end) = currentWeekDateRange
        return allIdeals.filter { ideal in
            // Must have startDate > 0 (not wishlist)
            guard ideal.startDate > 0 else { return false }
            // Start date must fall inside current week
            guard ideal.startDate >= start && ideal.startDate <= end else { return false }
            // Not wishlist enabled
            guard !ideal.wishlistEnabled else { return false }
            return true
        }
    }
    
    private var lastWeekCompletedCount: Int {
        let (start, end) = lastWeekDateRange
        
        // Filter ideals by startDate (week they were "for") - history is determined by startDate only
        let lastWeekIdeals = allIdeals.filter { ideal in
            guard ideal.startDate > 0 else { return false }
            return ideal.startDate >= start && ideal.startDate <= end
        }
        
        // Count completed ideals (doneCount >= targetCount)
        return lastWeekIdeals.filter { ideal in
            let targetCount: Int
            if ideal.targetCount == "6+" {
                targetCount = 6
            } else {
                targetCount = Int(ideal.targetCount) ?? 0
            }
            return ideal.doneCount >= targetCount
        }.count
    }
    
    private var lastWeekTotalCount: Int {
        let (start, end) = lastWeekDateRange
        
        // Filter ideals by startDate (week they were "for")
        return allIdeals.filter { ideal in
            guard ideal.startDate > 0 else { return false }
            return ideal.startDate >= start && ideal.startDate <= end
        }.count
    }
    
    /// This week's average for a category.
    ///
    /// Every ideal in the category is considered, not only those that STARTED
    /// this week. The old version narrowed to `currentWeekIdeals` on top of
    /// filtering the scores by date, so reviewing an ideal carried over from an
    /// earlier week left the row showing a dash — the ideal was dropped before
    /// its score was ever looked at. Ideals persist across weeks, so that was
    /// the common case, not an edge one.
    private func currentWeekAverageReviewScore(for category: Category) -> Double? {
        let (start, end) = currentWeekDateRange
        return CategoryReviewAverage.average(
            idealIds: allIdeals.filter { $0.category == category.rawValue }.map(\.id),
            scoresByIdeal: categoryReviewScores,
            from: start, to: end)
    }
    
    /// Last week's average. Unused today, but kept alongside its sibling and
    /// sharing the same calculation so the two cannot drift apart again — that
    /// drift is what produced the bug above.
    private func lastWeekAverageReviewScore(for category: Category) -> Double? {
        let (start, end) = lastWeekDateRange
        return CategoryReviewAverage.average(
            idealIds: allIdeals.filter { $0.category == category.rawValue }.map(\.id),
            scoresByIdeal: categoryReviewScores,
            from: start, to: end)
    }
    
    // Fetch review scores for all ideals
    private func fetchCategoryReviewScores() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        Task {
            let fetched = await ReviewScoreRepository.fetchScoresByIdeal(
                userId: userId,
                idealIds: allIdeals.map(\.id)
            )
            await MainActor.run {
                categoryReviewScores = fetched
            }
        }
    }
    
    // MARK: - Chart Related
    
    enum TimeFilter: String, CaseIterable {
        case all = "All"
        case oneMonth = "1 Month"
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case oneYear = "1 Year"
    }
    
    private var chartDateRangeStart: Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch chartSelectedFilter {
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
    
    private func filteredReviewScoresForChart(for idealId: String) -> [ReviewScore] {
        guard let scores = categoryReviewScores[idealId] else { return [] }
        
        guard let startDate = chartDateRangeStart else {
            return scores // "All" filter - return all scores
        }
        
        let endDate = Date()
        let startTimestamp = startDate.startOfDay.timeIntervalSince1970
        let endTimestamp = endDate.endOfDay.timeIntervalSince1970
        
        return scores.filter { score in
            score.date >= startTimestamp && score.date <= endTimestamp
        }
    }
    
    // Palette-only colors for categories (same mapping as the rings)
    private func colorForCategory(_ category: Category) -> Color {
        categoryRingColor(for: category)
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
            let categoryIdeals = allIdeals.filter { $0.category == category.rawValue }
            for ideal in categoryIdeals {
                let scores = filteredReviewScoresForChart(for: ideal.id)
                if !scores.isEmpty {
                    idealsWithScores.append(ideal)
                }
            }
        }
        
        // Sort by createdDate for consistent ordering
        return idealsWithScores.sorted { ($0.createdDate > 0 ? $0.createdDate : 0) < ($1.createdDate > 0 ? $1.createdDate : 0) }
    }
    
    // Chart data structure for period-based averages (All category mode)
    private struct IdealAverageDataPoint: Identifiable {
        let id = UUID()
        let idealId: String
        let idealTitle: String
        let category: Category
        let averageScore: Double // 0-10 scale
        let index: Int // Index for x-axis positioning
    }
    
    // Chart data structure for time-based data (single ideal mode)
    private struct TimeBasedDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let score: Double // 0-10 scale
        let idealId: String
        let idealTitle: String
        let index: Int
    }
    
    // Get chart data for "All" category mode or category + "All" ideal mode
    // Each point represents an ideal's average score over the selected period
    private var periodBasedChartData: [Category: [IdealAverageDataPoint]] {
        var categoryData: [Category: [IdealAverageDataPoint]] = [:]
        
        // Get all ideals with review scores, sorted consistently
        let allIdealsWithScores = idealsWithReviewScoresForChart
        let idealIndexMap: [String: Int] = Dictionary(uniqueKeysWithValues: allIdealsWithScores.enumerated().map { ($0.element.id, $0.offset) })
        
        // Determine which categories to process
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
                
                // Calculate average score for this ideal over the selected period
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
        
        // Group by date and calculate average per date
        var dateGroups: [Date: [ReviewScore]] = [:]
        for score in scores {
            let scoreDate = Date(timeIntervalSince1970: score.date)
            let dayStart = Calendar.current.startOfDay(for: scoreDate)
            if dateGroups[dayStart] == nil {
                dateGroups[dayStart] = []
            }
            dateGroups[dayStart]?.append(score)
        }
        
        // Create data points sorted by date
        let sortedDates = Array(dateGroups.keys).sorted()
        let ideal = allIdeals.first(where: { $0.id == selectedIdealId })
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
    
}

#Preview {
    HistoryProgressView(userId: "zmWbZgN5sAZqbWXOTJCZ37qeLUJ3")
}
