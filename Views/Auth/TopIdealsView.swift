//
//  TopIdealsView.swift
//  The Ideal Week
//

import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth

private let sharedDb = Firestore.firestore()

// MARK: - Shared header close button (7g / 7h)
// Raised round surface button with the PINK line-close glyph, per the 7g/7h
// handoff header (36px circle, 4/9 raised shadow).

private struct NeuPinkCloseButton: View {
    var action: () -> Void
    var diameter: CGFloat = 36

    var body: some View {
        Button(action: action) {
            Image("Line Close_Pink")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(LCColor.glyph(.pink))
                .scaledToFit()
                .frame(width: diameter * 0.38, height: diameter * 0.38)
        }
        .buttonStyle(NeuCircleButtonStyle(diameter: diameter))
        .accessibilityLabel("Close")
    }
}

struct TopIdealsView: View {
    var allIdeals: [Ideal]
    let accentColor: Color
    let textColor: Color
    let weekStartDay: String

    @State private var selectedCategory: CategoryFilter = .all
    // User's own ideals data
    @State private var reviewScores: [String: [ReviewScore]] = [:]
    // Loading
    @State private var isDataReady: Bool = false
    // Add to week sheet
    @State private var showAddToWeekSheet: Bool = false
    @State private var selectedIdealToAdd: (title: String, category: String, averageScore: Double)?
    // Track which ideals have been saved this session
    @State private var savedIdeals: Set<String> = []

    @Environment(\.dismiss) private var dismiss

    enum CategoryFilter: String, CaseIterable {
        case all = "All"
        case fix = "Fix"
        case fitness = "Fitness"
        case feelings = "Feelings"
        case faculties = "Faculties"
        case family = "Family"
        case finance = "Finance"
        case fun = "Fun"
    }

    // MARK: - Date helpers - Last 2 active weeks range
    // An "active week" is a week in which at least one ideal had its startDate.

    private var lastTwoActiveWeekStarts: [TimeInterval] {
        let starts = Set(allIdeals.filter { !$0.wishlistEnabled }.map { $0.startDate })
        return Array(starts.sorted(by: >).prefix(2))
    }

    private var lastTwoWeeksDateRange: (start: TimeInterval, end: TimeInterval) {
        let activeStarts = lastTwoActiveWeekStarts
        guard let earliest = activeStarts.min(), let latest = activeStarts.max() else {
            return (.greatestFiniteMagnitude, 0)
        }
        let rangeStart = Date(timeIntervalSince1970: earliest).startOfDay.timeIntervalSince1970
        let weekEnd = Date(timeIntervalSince1970: latest).addingTimeInterval(7 * 24 * 60 * 60 - 1)
        return (rangeStart, weekEnd.endOfDay.timeIntervalSince1970)
    }

    // MARK: - Score helpers

    private func averageScore(for idealId: String) -> Double? {
        guard let scores = reviewScores[idealId] else { return nil }
        let (start, end) = lastTwoWeeksDateRange
        let filtered = scores.filter { $0.date >= start && $0.date <= end }
        guard !filtered.isEmpty else { return nil }
        let total = filtered.reduce(0) { $0 + $1.score }
        return Double(total) / Double(filtered.count)
    }

    // MARK: - Current week filtering

    private var currentWeekStartTimestamp: TimeInterval {
        WeekdayUtility.weekStart(weekStartDay: weekStartDay).timeIntervalSince1970
    }

    private var currentWeekIdeals: [Ideal] {
        let weekStart = currentWeekStartTimestamp
        return allIdeals.filter { ideal in
            ideal.startDate == weekStart && !ideal.wishlistEnabled
        }
    }

    private var currentWeekKeys: Set<String> {
        Set(currentWeekIdeals.compactMap { ideal in
            IdealDuplicateGuard.duplicateKey(category: ideal.category, title: ideal.title)
        })
    }

    // MARK: - Top ideals (user's last 2 active weeks)

    private var userTopIdeals: [(title: String, category: String, averageScore: Double)] {
        var filtered = allIdeals
        if selectedCategory != .all {
            filtered = filtered.filter { $0.category == selectedCategory.rawValue }
        }
        let withAverages = filtered.compactMap { ideal -> (String, String, Double)? in
            guard let avg = averageScore(for: ideal.id) else { return nil }
            return (ideal.title, ideal.category, avg)
        }
        return Array(withAverages.sorted { $0.2 > $1.2 }.prefix(25))
    }

    private var displayItems: [(title: String, category: String, averageScore: Double)] {
        let weekKeys = currentWeekKeys
        // Filter out ideals that already exist in current week (by title + category)
        return userTopIdeals.filter { item in
            guard let key = IdealDuplicateGuard.duplicateKey(category: item.category, title: item.title) else {
                return true
            }
            return !weekKeys.contains(key)
        }
    }

    // MARK: - Data fetching

    private func loadData() {
        isDataReady = false
        fetchUserReviewScores()
    }

    private func fetchUserReviewScores() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isDataReady = true
            return
        }
        guard !allIdeals.isEmpty else {
            isDataReady = true
            return
        }
        let db = sharedDb
        Task { @MainActor in
            await withTaskGroup(of: (String, [ReviewScore]).self) { group in
                for ideal in allIdeals {
                    group.addTask {
                        return await Self.fetchScoresForIdeal(idealId: ideal.id, userId: userId, db: db)
                    }
                }
                for await (idealId, scores) in group {
                    reviewScores[idealId] = scores
                }
                isDataReady = true
            }
        }
    }

    private static func fetchScoresForIdeal(idealId: String, userId: String, db: Firestore) async -> (String, [ReviewScore]) {
        return await withCheckedContinuation { continuation in
            db.collection("users")
                .document(userId)
                .collection("ideals")
                .document(idealId)
                .collection("reviewScores")
                .order(by: "date")
                .getDocuments { snapshot, _ in
                    let scores = snapshot?.documents.compactMap { try? $0.data(as: ReviewScore.self) } ?? []
                    continuation.resume(returning: (idealId, scores))
                }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header — close (pink X, raised circle) + HH Samuel title
                header

                // Category filter (sunken bar)
                filterBar

                // Content
                if !isDataReady {
                    loadingView
                } else if displayItems.isEmpty {
                    emptyView
                } else {
                    listView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(LCColor.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if reviewScores.isEmpty {
                    loadData()
                } else {
                    isDataReady = true
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        ZStack {
            Text("TOP IDEALS")
                .font(.hhSamuel(32))
                .accentText(.pink)
                .accessibilityAddTraits(.isHeader)
            HStack {
                NeuPinkCloseButton { dismiss() }
                Spacer()
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .padding(.top, 10)
        .frame(minHeight: LCMetrics.rowHeight)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Text("Category")
                .font(.manrope(15, .heavy))
                .foregroundColor(LCColor.ink)

            Menu {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(CategoryFilter.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedCategory.rawValue)
                        .font(.manrope(15, .semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .accentText(.pink)
            }
            .accessibilityLabel("Category filter")
            .accessibilityValue(selectedCategory.rawValue)

            Spacer()

            Label {
                Text("Your Top")
                    .font(.manrope(12, .heavy))
            } icon: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13))
            }
            .accentText(.pink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .neuSunken(cornerRadius: 16)
        .padding(.horizontal, LCMetrics.screenMargin)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(LCColor.pink)
            Text("Loading top ideals...")
                .font(.manrope(15, .semibold))
                .foregroundColor(LCColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 50))
                .foregroundColor(LCColor.textMuted)
            Text("No ideals with review scores found for the last 2 active weeks")
                .font(.manrope(16, .semibold))
                .foregroundColor(LCColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayItems.indices, id: \.self) { index in
                    if index > 0 {
                        NeuFeatheredDivider()
                    }
                    idealRow(for: displayItems[index])
                }
            }
            .padding(.top, 6)
        }
        .sheet(isPresented: $showAddToWeekSheet) {
            if let ideal = selectedIdealToAdd {
                AddToCurrentWeekSheet(
                    idealTitle: ideal.title,
                    defaultCategory: ideal.category,
                    accentColor: accentColor,
                    weekStartDay: weekStartDay,
                    onDismiss: {
                        showAddToWeekSheet = false
                        selectedIdealToAdd = nil
                    },
                    onSave: { title in
                        // Mark this ideal as saved
                        let key = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        savedIdeals.insert(key)
                    }
                )
            }
        }
    }

    private func idealRow(for item: (title: String, category: String, averageScore: Double)) -> some View {
        HStack(spacing: 14) {
            // Category icon (line glyph, title-sized, blue accent)
            if let category = Category.allCases.first(where: { $0.rawValue == item.category }) {
                Image(category.lcCategoryIconV2())
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .accentText(.blue)
                    .frame(width: 26, height: 26)
            }

            // Title — Newsreader italic, imprinted into the surface
            Text(item.title)
                .font(.idealTitle(20))
                .foregroundColor(LCColor.ink)
                .imprinted()
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Average score (1-7 scale)
            let scoreDisplay = ReviewScoreScale.display(fromStored: item.averageScore)
            Text("\(ReviewScoreScale.formattedDisplay(scoreDisplay))/7")
                .font(.manrope(16, .heavy))
                .foregroundColor(LCColor.ink)

            // Heart add button (raised circle; pink-filled once saved)
            let titleKey = item.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let isSaved = savedIdeals.contains(titleKey)

            Button {
                guard !isSaved else { return }
                selectedIdealToAdd = item
                showAddToWeekSheet = true
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    // Saved: the heart sits ON the primary fill, so it takes the
                    // foreground that fill can carry. Unsaved: it sits on the
                    // surface like any other boxed glyph.
                    .foregroundColor(isSaved ? LCColor.contrastingInk(on: LCColor.pink)
                                             : LCColor.glyph(.pink))
            }
            .buttonStyle(NeuCircleButtonStyle(fill: isSaved ? LCColor.pink : LCColor.surface, diameter: 34))
            .disabled(isSaved)
            .accessibilityLabel(isSaved ? "\(item.title) added to this week" : "Add \(item.title) to this week")
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 22)
        .frame(minHeight: LCMetrics.rowHeight)
    }
}

// MARK: - Add to Current Week Sheet

struct AddToCurrentWeekSheet: View {
    let idealTitle: String
    let defaultCategory: String
    let accentColor: Color
    let weekStartDay: String
    let onDismiss: () -> Void
    let onSave: (String) -> Void

    @State private var title: String
    @State private var selectedCategory: String
    @State private var selectedTargetCount: Int = 1
    @State private var sliderValue: Double = 1.0
    @State private var isSaving: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    init(idealTitle: String, defaultCategory: String, accentColor: Color, weekStartDay: String, onDismiss: @escaping () -> Void, onSave: @escaping (String) -> Void = { _ in }) {
        self.idealTitle = idealTitle
        self.defaultCategory = defaultCategory
        self.accentColor = accentColor
        self.weekStartDay = weekStartDay
        self.onDismiss = onDismiss
        self.onSave = onSave

        _title = State(initialValue: idealTitle)
        _selectedCategory = State(initialValue: defaultCategory)
    }

    private func targetCountToSliderValue(_ targetCount: Int) -> Double {
        Double(max(1, min(6, targetCount)))
    }

    private func sliderValueToTargetCount(_ value: Double) -> Int {
        max(1, min(6, Int(value.rounded())))
    }

    private func saveIdeal() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard !isSaving else { return }

        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for duplicates in current week
        IdealDuplicateGuard.fetchCurrentWeekKeys(userId: userId, weekStartDay: weekStartDay) { [self] result in
            switch result {
            case .failure(let error):
                isSaving = false
                errorMessage = "Could not validate duplicates: \(error.localizedDescription)"
                showErrorAlert = true

            case .success(let existingKeys):
                // Check if this title + category combination already exists
                if let key = IdealDuplicateGuard.duplicateKey(category: selectedCategory, title: trimmedTitle),
                   existingKeys.contains(key) {
                    isSaving = false
                    errorMessage = "An ideal titled \"\(trimmedTitle)\" already exists in \(selectedCategory) for this week. Please change the title or category to add this ideal."
                    showErrorAlert = true
                    return
                }

                // No duplicate, proceed with save
                performSave(userId: userId, trimmedTitle: trimmedTitle)
            }
        }
    }

    private func performSave(userId: String, trimmedTitle: String) {
        let db = sharedDb
        let newId = UUID().uuidString
        let now = Date().timeIntervalSince1970
        let weekStart = WeekdayUtility.weekStart(weekStartDay: weekStartDay).timeIntervalSince1970

        let targetCountString: String
        if selectedTargetCount >= 6 {
            targetCountString = "6+"
        } else {
            targetCountString = String(selectedTargetCount)
        }

        let ideal: [String: Any] = [
            "id": newId,
            "title": trimmedTitle,
            "category": selectedCategory,
            "wishlistEnabled": false,
            "startDate": weekStart,
            "createdDate": now,
            "active": true,
            "platform": "iOS",
            "doneCount": 0,
            "targetCount": targetCountString,
            "notes": "",
            "scheduledDays": [] as [Int],
            "reminderTime": 0,
            "reminderSchedules": [[String: Any]](),
            "reminderIds": [] as [String],
            "plannedFromWishlistAt": 0
        ]

        db.collection("users").document(userId).collection("ideals").document(newId).setData(ideal) { error in
            isSaving = false
            if let error = error {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            } else {
                onSave(trimmedTitle)
                HapticFeedback.impact(style: .light)
                onDismiss()
            }
        }
    }

    private var isSaveDisabled: Bool {
        isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header — close (cancel), HH Samuel title, yellow check save
                sheetHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("TITLE")
                        VoiceTitleField(
                            text: $title,
                            placeholder: "Title",
                            accentColor: LCColor.pink
                        )
                        .padding(.horizontal, LCMetrics.screenMargin)

                        sectionHeader("CATEGORY")
                        categoryRow

                        sectionHeader("HOW OFTEN?")
                        howOftenSlider
                            .padding(.horizontal, LCMetrics.screenMargin + 2)
                    }
                    .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(LCColor.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Sheet subviews

    private var sheetHeader: some View {
        ZStack {
            Text("NEW IDEAL")
                .font(.hhSamuel(36))
                .accentText(.pink)
                .accessibilityAddTraits(.isHeader)
            HStack {
                NeuPinkCloseButton { onDismiss() }
                    .accessibilityLabel("Cancel")
                Spacer()
                NeuCheckSaveButton(diameter: 36) {
                    saveIdeal()
                }
                .disabled(isSaveDisabled)
                .opacity(isSaveDisabled ? 0.45 : 1)
            }
        }
        .padding(.horizontal, LCMetrics.screenMargin)
        .padding(.top, 10)
        .frame(minHeight: LCMetrics.rowHeight)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.hhSamuel(23))
            .accentText(.pink)
            .kerning(0.3)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private var categoryRow: some View {
        HStack {
            Text("Category")
                .font(.manrope(16, .heavy))
                .foregroundColor(LCColor.ink)

            Spacer()

            Menu {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(Category.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedCategory)
                        .font(.manrope(16, .semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                }
                .accentText(.pink)
            }
            .accessibilityLabel("Category")
            .accessibilityValue(selectedCategory)
        }
        .padding(.horizontal, 18)
        .neuGroupedRow()
        .padding(.horizontal, LCMetrics.screenMargin)
    }

    // Sunken track + pink fill + raised knob (handoff 7h "How Often" slider).
    private var howOftenSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let fraction = CGFloat((sliderValue - 1.0) / 5.0)
                ZStack(alignment: .leading) {
                    // Sunken track well
                    NeumorphicTrack(height: 12)
                        .frame(maxWidth: .infinity)

                    // Pink progress fill up to the knob
                    Capsule()
                        .fill(LCColor.pink)
                        .frame(width: max(0, geometry.size.width * fraction), height: 12)

                    // Raised knob with pink core
                    Circle()
                        .fill(LCColor.pink)
                        .frame(width: 12, height: 12)
                        .frame(width: 34, height: 34)
                        .neuRaised(Circle(), cssOffset: 4, cssBlur: 9)
                        .offset(x: max(0, min(geometry.size.width - 34, geometry.size.width * fraction - 17)))
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let percentage = max(0, min(1, Double(value.location.x / geometry.size.width)))
                            let newValue = 1.0 + (percentage * 5.0)
                            let snappedValue = round(newValue)
                            if Int(snappedValue) != Int(sliderValue) {
                                HapticFeedback.impact(style: .light)
                            }
                            withAnimation(.interactiveSpring()) {
                                sliderValue = snappedValue
                                selectedTargetCount = sliderValueToTargetCount(snappedValue)
                            }
                        }
                )
            }
            .frame(height: 44)
            .padding(.vertical, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("How often")
            .accessibilityValue(selectedTargetCount >= 6 ? "6 or more times" : "\(selectedTargetCount) times")

            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { value in
                    Button(action: {
                        HapticFeedback.impact(style: .medium)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            sliderValue = Double(value)
                            selectedTargetCount = value
                        }
                    }) {
                        Text("\(value)")
                            .font(.manrope(14, Int(sliderValue) == value ? .heavy : .regular))
                            .foregroundColor(Int(sliderValue) == value ? LCColor.pink : LCColor.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    HapticFeedback.impact(style: .medium)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        sliderValue = 6.0
                        selectedTargetCount = 6
                    }
                }) {
                    Text("6+")
                        .font(.manrope(14, sliderValue == 6.0 ? .heavy : .regular))
                        .foregroundColor(sliderValue == 6.0 ? LCColor.pink : LCColor.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#if DEBUG
#Preview {
    PreviewData.configureFirebaseIfNeeded()
    return TopIdealsView(
        allIdeals: PreviewData.lastWeekIdeals,
        accentColor: LCColor.pink,
        textColor: LCColor.ink,
        weekStartDay: PreviewData.weekStartDay
    )
}
#endif
